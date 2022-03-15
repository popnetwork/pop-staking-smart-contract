// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract PopStaking is Initializable, OwnableUpgradeable {
    using SafeMath for uint256;

    /// @notice Info of each user.
    struct UserInfo {
        uint256 amount;     // How many tokens the user has provided.
        uint256 rewardMultiplier; // Reward Block Count.
        uint256 lastRewardBlock;  // Last block number that tokens distribution occurs.
    }

    /// @notice The POP TOKEN!
    IERC20 public pop;
    /// @notice Dev address.
    address public devaddr;
    /// @notice POP tokens created per block.
    uint256 [] public popPerBlockAllCycles;
    uint8 public cycleLen;

    mapping (address => UserInfo) public userInfo;
    
    /// @notice The block number when POP mining starts.
    uint256 public startBlock;
    uint256 public startTime;
    uint256 public claimableBlock;
    uint256 public constant STAKE_UNIT = 50000*1e18;
    uint256 public totalStakedAmount;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 rewardAmount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    function initialize(
        IERC20 _pop,
        address _devaddr,
        uint256 _startTime,
        uint256 _popPerBlock
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        pop = _pop;
        require(_devaddr != address(0), "zero address");
        require(_popPerBlock > 0, "zero value");
        devaddr = _devaddr;
        while (cycleLen < 4) {
            popPerBlockAllCycles.push(_popPerBlock);
            _popPerBlock /= 2;
            cycleLen ++;
        }
        startTime = _startTime;
        startBlock = block.number; 
        claimableBlock = block.number;
    }

    function getPopPerBlock() public view returns (uint256) {
        if(block.timestamp < startTime) return 0;
        
        uint256 cycle = (block.timestamp - startTime) / 90 days;
        if(cycle > cycleLen) cycle = cycleLen - 1;
        return popPerBlockAllCycles[cycle];
    }


    /// @notice Return reward multiplier over the given _from to _to block.
    /// @param _from from block number
    /// @param _to to block number
    function getMultiplier(uint256 _from, uint256 _to) external pure returns (uint256) {
        if (_to <= _from) {
            return 0;
        } else {
            return _to.sub(_from);
        }
    }

    /// @notice View function to see pending POPs on frontend.
    /// @param _user user address to see pending POPs
    function claimablePop(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        return user.amount.mul(popPerBlockAllCycles[0]).mul(user.rewardMultiplier).div(1e18*16);
    }

    /// @notice Deposit tokens to PopStaking for POP allocation.
    /// @param _amount amount to be deposited
    function deposit(uint256 _amount) external {
        uint256 amount = _amount.sub(_amount % STAKE_UNIT);
        require(amount > 0, "deposit: zero value");
        UserInfo storage user = userInfo[msg.sender];
        if (user.amount > 0) {
            uint256 claimable = user.amount.mul(popPerBlockAllCycles[0]).mul(user.rewardMultiplier).div(1e18*16);
            if (claimable > 0)
                safePopTransfer(msg.sender, claimable);
        }
        bool success = pop.transferFrom(address(msg.sender), address(this), amount);
        require(success == true, "deposit: transferFrom failed");
        user.amount = user.amount.add(amount);
        user.lastRewardBlock = block.number;
        user.rewardMultiplier = 0;
        totalStakedAmount = totalStakedAmount.add(amount);
        emit Deposit(msg.sender, amount);
    }

    /// @notice Claim reward tokens
    function claim() external {
        UserInfo storage user = userInfo[msg.sender];
        uint256 claimable = user.amount.mul(popPerBlockAllCycles[0]).mul(user.rewardMultiplier).div(1e18*16);
        if (claimable > 0)
            safePopTransfer(msg.sender, claimable);
        user.lastRewardBlock = block.number;
        user.rewardMultiplier = 0;
        emit Claim(msg.sender, claimable);
    }

    /// @notice Withdraw tokens from PopStaking.
    /// @param _amount amount to be withdrawed
    function withdraw(uint256 _amount) external {
        UserInfo storage user = userInfo[msg.sender];
        require(_amount > 0 && user.amount > 0 && user.amount >= _amount, "withdraw: not good");
        uint256 claimable = user.amount.mul(popPerBlockAllCycles[0]).mul(user.rewardMultiplier).div(1e18*16);
        if (claimable > 0)
            safePopTransfer(msg.sender, claimable);
        user.amount = user.amount.sub(_amount);
        user.lastRewardBlock = block.number;
        user.rewardMultiplier = 0;
        totalStakedAmount = totalStakedAmount.sub(_amount);
        bool success = pop.transfer(address(msg.sender), _amount);
        require(success == true, "withdraw: transfer failed");
        emit Withdraw(msg.sender, _amount);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() external {
        UserInfo storage user = userInfo[msg.sender];
        uint amount = user.amount;
        require(amount > 0, "emergencyWithdraw: no tokens");
        user.amount = 0;
        user.lastRewardBlock = block.number;
        user.rewardMultiplier = 0;
        totalStakedAmount = totalStakedAmount.sub(amount);
        bool success = pop.transfer(address(msg.sender), amount);
        require(success == true, "emergencyWithdraw: transfer failed");
        emit EmergencyWithdraw(msg.sender, amount);
        
    }

    /// @notice Safe pop transfer function, just in case if rounding error causes pool to not have enough POPs.
    /// @param _to address to be get POP token
    /// @param _amount POP token amount to be sent
    function safePopTransfer(address _to, uint256 _amount) internal {
        uint256 popBal = pop.balanceOf(address(this));
        require(popBal.sub(totalStakedAmount) > _amount, "transfer: not enough reward tokens");
        bool success = pop.transfer(_to, _amount);
        require(success == true, "withdraw: transfer failed");
    }

    /// @notice Update pending info
    /// @param _addresses array of addresses to be updated
    /// @param _multiplier array of multiplier (block numbers) to be updated
    function updatePendingInfo(address[] memory _addresses, uint16[] memory _multiplier) external {
        require(msg.sender == devaddr, "dev: wut?");
        require(_addresses.length == _multiplier.length, "pendingInfo: length?");
        uint divider = popPerBlockAllCycles[0].div(getPopPerBlock());
        for (uint i = 0; i < _addresses.length; i++) {
            UserInfo storage user = userInfo[_addresses[i]];
            user.rewardMultiplier = user.rewardMultiplier.add(_multiplier[i]*16/divider);
        }

        claimableBlock = block.number;
    }
    /// @notice Update dev address by the previous dev.
    /// @param _devaddr Dev address to be updated.
    function dev(address _devaddr) external {
        require(_devaddr != address(0), "dev: zero address");
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    /// @notice Update popPerBlock.
    /// @param _popPerBlock popPerBlock to be updated.
    function updatePopPerBlock(uint _popPerBlock) onlyOwner external {
        require(_popPerBlock > 0, "updatePopPerBlock: zero value");
        cycleLen = 0;
        while (cycleLen < 4) {
            popPerBlockAllCycles[cycleLen] = _popPerBlock;
            _popPerBlock /= 2;
            cycleLen ++;
        }
    }
}