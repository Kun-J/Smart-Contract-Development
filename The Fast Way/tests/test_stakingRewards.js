const { expect } = require("chai");
const { utils, ethers } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const StakingRewards = require("<path-to-contract-build-file>");

describe("StakingRewards Contract", function () {
    let contract, stakingToken, rewardsToken, provider;
    let staker1, staker2, admin;

    before(async function () {
        provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
        staker1 = ethers.Wallet.createRandom();
        staker2 = ethers.Wallet.createRandom();
        admin = ethers.Wallet.createRandom();

        // Deploy staking and rewards tokens
        stakingToken = await ethers.Contract.deploy(..., staker1.address);
        rewardsToken = await ethers.Contract.deploy(..., staker1.address);

        // Deploy StakingRewards contract
        contract = await ethers.Contract.deploy(
            StakingRewards.abi,
            StakingRewards.bytecode,
            admin.address,
            stakingToken.address,
            rewardsToken.address
        );
    });

    it("Should be able to stake tokens", async function () {
        await stakingToken.connect(staker1).approve(contract.address, 100);
        await contract.connect(staker1).stake(100);
        const totalStaked = await contract.totalStakedTokens();
        expect(totalStaked.toString()).to.equal("100");
    });

    it("Should be able to earn rewards", async function () {
        await rewardsToken.connect(admin).transfer(staker1.address, 100);
        const rewards = await contract.connect(staker1).earned();
        expect(rewards.toString()).to.equal("100");
    });

    it("Should be able to harvest rewards", async function () {
        await contract.connect(staker1).harvest();
        const balance = await rewardsToken.balanceOf(staker1.address);
        expect(balance.toString()).to.equal("100");
    });

    it("Should be able to withdraw stake", async function () {
        await contract.connect(staker1).withdraw(100);
        const totalStaked = await contract.totalStakedTokens();
        expect(totalStaked.toString()).to.equal("0");
    });

    it("should not allow staking when paused", async function () {
        // pause the contract
        await stakingRewards.pause();

        // attempt to stake tokens
        await utils.expectRevert(stakingRewards.stake(), "Pausable: paused");
    });

    it("should not allow staking while mutex is active", async function () {
        // set the mutex flag to true
        await stakingRewards.setMutex(true);

        // attempt to stake tokens
        await utils.expectRevert(stakingRewards.stake(), "SafeERC20: Mutex lock");
    });

    it("should not allow staking for non-whitelisted addresses", async function () {
        // attempt to stake tokens
        await utils.expectRevert(stakingRewards.stake(), "StakingRewards: only whitelisted");
    });

    it("should only allow admin to perform actions restricted by the onlyAdmin modifier", async function () {
        // set a different address as the msg.sender
        const user = (await ethers.provider.listAccounts())[1];
        stakingRewards = stakingRewards.connect(user);

        // attempt to call an action restricted by the onlyAdmin modifier
        await utils.expectRevert(stakingRewards.updateConfig(), "StakingRewards: only admin");
    });
});
