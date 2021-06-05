/* 

website: thepopnetwork.org

██████╗  ████═╗ ██████╗
██║ ██║ ██║ ██║ ██║ ██║ 
██████║ ██║ ██║ ██████║ 
██╔═══╝ ██║ ██║ ██╔═══╝ 
██║      ████║  ██║     
╚═╝       ╚══╝  ╚═╝    

*/

pragma solidity ^0.6.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PopStaking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many tokens the user has provided.
        uint256 rewardMultiplier; // Reward Block Count.
        uint256 lastRewardBlock;  // Last block number that tokens distribution occurs.
    }

    // The POP TOKEN!
    IERC20 public pop;
    // Dev address.
    address public devaddr;
    // POP tokens created per block.
    uint256 public popPerBlock;
    uint256 public popPerBlockCycleOne;
    uint256 public popPerBlockCycleTwo;
    uint256 public popPerBlockCycleThree;
    uint256 public popPerBlockCycleFour;

    mapping (address => UserInfo) public userInfo;
    
    // The block number when POP mining starts.
    uint256 public startBlock;
    uint256 public startTime;
    uint256 public claimableBlock;
    uint256 public constant stakeUnit = 50000*1e18;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(
        IERC20 _pop,
        address _devaddr,
        uint256 _startTime,
        uint256 _popPerBlock
    ) public {
        pop = _pop;
        devaddr = _devaddr;
        popPerBlock = 0;
        popPerBlockCycleOne = _popPerBlock;
        popPerBlockCycleTwo = _popPerBlock.div(2);
        popPerBlockCycleThree = _popPerBlock.div(4);
        popPerBlockCycleFour = _popPerBlock.div(8);
        startTime = _startTime;
        if ( startTime <= now && now < startTime + 90 days && popPerBlock != popPerBlockCycleOne) {
            popPerBlock = popPerBlockCycleOne;
        } else if ( startTime + 90 days <= now && now < startTime + 180 days && popPerBlock != popPerBlockCycleTwo) {
            popPerBlock = popPerBlockCycleTwo;
        } else if ( startTime + 180 days <= now && now < startTime + 270 days && popPerBlock != popPerBlockCycleThree) {
            popPerBlock = popPerBlockCycleThree;
        } else if ( startTime + 270 days <= now && now < startTime + 365 days && popPerBlock != popPerBlockCycleFour) {
            popPerBlock = popPerBlockCycleFour;
        }
        startBlock = block.number; 
        claimableBlock = block.number;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= _from) {
            return 0;
        } else {
            return _to.sub(_from);
        }
    }

    // View function to see pending POPs on frontend.
    function claimablePop(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        return user.amount.mul(popPerBlock).mul(user.rewardMultiplier).div(1e18);
    }

    // Deposit tokens to PopStaking for POP allocation.
    function deposit(uint256 _amount) public {
        uint256 amount = _amount.sub(_amount % stakeUnit);
        require(amount >= 50000, "deposit: not good");
        UserInfo storage user = userInfo[msg.sender];
        if (user.amount > 0) {
            uint256 claimable = user.amount.mul(popPerBlock).mul(user.rewardMultiplier).div(1e18);
            safePopTransfer(msg.sender, claimable);
        }
        pop.transferFrom(address(msg.sender), address(this), amount);
        user.amount = user.amount.add(amount);
        user.lastRewardBlock = block.number;
        user.rewardMultiplier = 0;
        emit Deposit(msg.sender, amount);
    }

    // Withdraw tokens from PopStaking.
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        uint256 claimable = user.amount.mul(popPerBlock).mul(user.rewardMultiplier).div(1e18);
        safePopTransfer(msg.sender, claimable);
        user.amount = user.amount.sub(_amount);
        user.lastRewardBlock = block.number;
        user.rewardMultiplier = 0;
        pop.transfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        UserInfo storage user = userInfo[msg.sender];
        pop.transfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, user.amount);
        user.amount = 0;
        user.lastRewardBlock = block.number;
        user.rewardMultiplier = 0;
    }

    // Safe pop transfer function, just in case if rounding error causes pool to not have enough POPs.
    function safePopTransfer(address _to, uint256 _amount) internal {
        uint256 popBal = pop.balanceOf(address(this));
        if (_amount > popBal) {
            pop.transfer(_to, popBal);
        } else {
            pop.transfer(_to, _amount);
        }
    }

    // Token transfer function.
    function tokenTransfer(address _to, IERC20 _token, uint256 _amount) public onlyOwner {
        uint256 tokenBal = _token.balanceOf(address(this));
        if (_amount > tokenBal) {
            _token.transfer(_to, tokenBal);
        } else {
            _token.transfer(_to, _amount);
        }
    }

    // Update pending info
    function updatePendingInfo(address[] memory _addresses, uint16[] memory _multiplier) public {
        require(msg.sender == devaddr, "dev: wut?");
        require(_addresses.length == _multiplier.length, "pendingInfo: length?");
        require(startTime + 365 days >= now, "pendingInfo: rewards over");
        if ( startTime <= now && now < startTime + 90 days && popPerBlock != popPerBlockCycleOne) {
            popPerBlock = popPerBlockCycleOne;
        } else if ( startTime + 90 days <= now && now < startTime + 180 days && popPerBlock != popPerBlockCycleTwo) {
            popPerBlock = popPerBlockCycleTwo;
        } else if ( startTime + 180 days <= now && now < startTime + 270 days && popPerBlock != popPerBlockCycleThree) {
            popPerBlock = popPerBlockCycleThree;
        } else if ( startTime + 270 days <= now && now < startTime + 365 days && popPerBlock != popPerBlockCycleFour) {
            popPerBlock = popPerBlockCycleFour;
        } 
        for (uint i = 0; i < _addresses.length; i++) {
            UserInfo storage user = userInfo[_addresses[i]];
            user.rewardMultiplier = user.rewardMultiplier.add(_multiplier[i]);
        }
        claimableBlock = block.number;
    }
    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}