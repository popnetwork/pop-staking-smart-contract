const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require('@openzeppelin/test-helpers');
const Web3 = require('web3');
const { utils } = Web3;

const {
  isCallTrace,
} = require("hardhat/internal/hardhat-network/stack-traces/message-trace");

const PROMO = 0;

describe("PopStaking contract", function () {
  before(async function () {
    this.PopStaking = await ethers.getContractFactory("PopStaking");
    [
      this.owner, 
      this.alice,
      this.bob,
      this.carol,
      this.dev,
      this.minter,
      ...addrs
    ] = await ethers.getSigners();
    this.ERC20Mock = await ethers.getContractFactory("ERC20Mock", this.minter)
  })

  beforeEach(async function () {
    this.pop = await this.ERC20Mock.deploy("Popnetwork", "POP", utils.toWei('10000000000000000'))
    this.currentTime = (await time.latest()) * 1.0
    this.pool = await this.PopStaking.deploy(this.pop.address, this.dev.address, this.currentTime, 1000000000)
    this.startBlock = parseInt(await this.pool.startBlock())
    this.startTime = parseInt(await this.pool.startTime())
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await this.pool.owner()).to.equal(this.owner.address)
    });

    it("Should set correct state variables", async function () {
        expect(await this.pool.devaddr()).to.equal(this.dev.address)
        expect(await this.startTime).to.equal(this.currentTime)
        expect(await this.pool.getPopPerBlock()).to.equal(1000000000)
    });

  });

  context("Staking", function () {
    beforeEach(async function () {
      await this.pop.transfer(this.pool.address, utils.toWei("1000000"))
      expect(await this.pop.balanceOf(this.pool.address)).to.equal(utils.toWei("1000000"))
      await this.pop.transfer(this.alice.address, utils.toWei("1000000"))
      expect(await this.pop.balanceOf(this.alice.address)).to.equal(utils.toWei("1000000"))
      await this.pop.transfer(this.bob.address, utils.toWei("1000000"))
      expect(await this.pop.balanceOf(this.bob.address)).to.equal(utils.toWei("1000000"))
    })

    it("should give out POPs only after staking time - 1", async function () {
      await this.pop.connect(this.alice).approve(this.pool.address, utils.toWei('1000000'))
      expect(this.pool.connect(this.alice).deposit(utils.toWei('40000')))
        .to.be.revertedWith("deposit: not good")
      expect(await this.pool.connect(this.alice).deposit(utils.toWei('50000')))
      expect(await this.pop.balanceOf(this.alice.address)).to.equal(utils.toWei("950000"))
      expect(await this.pool.claimablePop(this.alice.address)).to.equal(0)
      await this.pool.connect(this.alice).withdraw(utils.toWei('50000'))
      expect(await this.pop.balanceOf(this.alice.address)).to.equal(utils.toWei("1000000"))
    })

    it("should give out POPs only after staking time - 2", async function () {
      await this.pop.connect(this.alice).approve(this.pool.address, utils.toWei('1000000'))
      await this.pool.connect(this.alice).deposit(utils.toWei('50000'))
      expect(await this.pop.balanceOf(this.alice.address)).to.equal(utils.toWei("950000"))
      await time.increase(10000)
      await this.pool.connect(this.dev).updatePendingInfo([this.alice.address], [10])
      expect(await this.pool.claimablePop(this.alice.address)).to.equal(50*1e13) // 1e3 * 1e9 * 1e1 = 1e13
      await this.pool.connect(this.alice).withdraw(utils.toWei('50000'))
      expect(await this.pop.balanceOf(this.alice.address)).to.equal('1000000000500000000000000') // 1000000 POP + 1e13
    })
  })
});



