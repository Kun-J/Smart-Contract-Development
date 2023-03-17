// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title A Staking contract with auto-compunding rewards
 * @author Kunal Jha (kun-j)
 * This contract allows users to to stake their funds and earn rewards.
 */

contract StakingRewards {
    using SafeERC20 for IERC20;

    //holds the address of the ERC20 token that the users will be staking.
    IERC20 public immutable stakingToken;
    //holds the address of the ERC20 token that will be used as rewards.
    IERC20 public immutable rewardsToken;
    
    //address of the contract administrator.
    address public admin;
    
    //holds the number of seconds a user's stake will be locked up
    //before they can claim the rewards.
    uint256 public lockupTime;
    uint256 public rewardRate;
    //reward per token staked.
    uint256 public rewardPerTokenStored;
    //total number of tokens staked by all users.
    uint256 public totalStaked;
    //holds the total number of rewards staked by all users.
    uint256 public totalRewardsStaked;
    uint256 public extraRewardRate;
    //holds the cooldown period before users can withdraw staked amount in seconds.
    uint256 public cooldownPeriod;
    //holds the timestamp when the rewards were last updated.
    uint256 public updatedAt;
    
    //implements mutex and prevents multiple transactions from executing simultaneously.
    bool public mutex = false;
    //to pause the contract temporarily.
    bool public pause = false;


    /*  holds the information of each user's stake, 
    such as the staked amount, rewards staked, 
    cooldown end time, finish time, last harvest time, 
    total rewards, and whitelist status.
    */
    struct UserInfo {
        uint256 stakedAmount;
        uint256 rewardsStaked;
        uint256 cooldownEnd;
        uint256 finishAt;
        uint256 lastHarvestTime;
        uint256 totalRewards;
        bool whitelist;
    }

    struct UserWithdrawal {
        uint256 stakeWithdraw;
        uint256 rewardsWithdraw;
    }
    
    //holds the information of each user's stake.
    mapping(address => UserInfo) public stakes;
    //to check if address is staker or not
    mapping(address => bool) public stakers;
    //holds the reward per token paid to each user.
    mapping(address => uint256) public userRewardPerTokenPaid;
    //holds the details of the amount to be withdrawn by each user.
    mapping(address => UserWithdrawal) public withdrawDetails;
    //rewards earned by each user.
    mapping(address => uint256) public rewards;

    constructor(address _stakingToken, address _rewardsToken) public {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        admin = msg.sender;
    }
    //modifiers

    modifier notPaused() {
        require(!pause);
        _;
    }

    modifier notMutex() {
        require(!mutex);
        _;
    }

    modifier onlyWhitelisted() { 
        require(stakes[msg.sender].whitelist);
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier updateReward() {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if(msg.sender != address(0)) {
            rewards[msg.sender] = earned(msg.sender);
            userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        }

        _;
    }

    //Events

    event NewStake(address user, uint256 stakeAmount);
    event Withdrawal(address user, uint256 stakedAmount, uint256 rewardsAmount);
    event HarvestComplete(address user);
    event StakeRemoved(address user);
    event ContractResumed();
    event ContractPaused();
    event Blacklisted(address user);
    event Whitelisted(address user);
    event RewardsClaimed(address user, uint256 rewards);
    event Restake(address user, uint256 stakedAmount, uint256 lockedRewards);
    event ConfigUpdate(
        uint256 lockupTime,
        uint256 rewardRate,
        uint256 rewardPerTokenStored,
        uint256 extraRewardRate,
        uint256 cooldownPeriod
    );


    //Getter functions
    function totalStakedTokens() external view returns (uint256) {
        return totalStaked;
    }

    function userBalance(address _user) external view returns (uint256, uint256) {
        require(msg.sender == _user, "You are not the owner");
        return (stakes[_user].stakedAmount, stakes[_user].rewardsStaked);
    }

    function earned(address user) public view returns (uint256) {
        return stakes[user].stakedAmount * (rewardPerToken() - userRewardPerTokenPaid[user]) / 1e18 + rewards[user];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(stakes[msg.sender].finishAt, block.timestamp);
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }


    function getExtraRewards(address user) public view returns (uint256) {
        return stakes[user].rewardsStaked * rewardRate * (block.timestamp - stakes[user].lastHarvestTime) * 1e18 / totalRewardsStaked;
    }

    //State change functions
    
     function stake(uint256 _amount) external payable notPaused updateReward {
        require(_amount > 0, "Amount should be more than 0");
        require(msg.sender != address(0));
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Token Transfer Failed");
        stakers[msg.sender] = true;
        stakes[msg.sender].whitelist = true;
        stakes[msg.sender].stakedAmount += _amount;
        stakes[msg.sender].finishAt = lockupTime + block.timestamp;
        totalStaked += _amount;
        emit NewStake(msg.sender, _amount);
    }

    function withdraw(uint256 _stakedAmount, uint256 _rewardsAmount) external notPaused notMutex onlyWhitelisted {
        require(stakers[msg.sender]);
        require(block.timestamp > stakes[msg.sender].cooldownEnd);
        require(withdrawDetails[msg.sender].stakeWithdraw >= _stakedAmount);
        require(withdrawDetails[msg.sender].rewardsWithdraw >= _rewardsAmount);
        mutex = true;
        require(stakingToken.transferFrom(address(this), msg.sender, _stakedAmount), "Token Transfer Failed");
        withdrawDetails[msg.sender].stakeWithdraw -= _stakedAmount;
        require(rewardsToken.transferFrom(address(this), msg.sender, _rewardsAmount), "Reward Transfer Failed");
        withdrawDetails[msg.sender].rewardsWithdraw -= _rewardsAmount;
        emit Withdrawal(msg.sender, _stakedAmount, _rewardsAmount);
        mutex = false;
    }

    function harvest() external notPaused notMutex onlyWhitelisted {
        require(stakers[msg.sender]);
        mutex = true;
        _claimRewards();
        uint _rewardsStaked = _claimRewards();
        stakes[msg.sender].rewardsStaked += _rewardsStaked;
        stakes[msg.sender].finishAt = lockupTime + block.timestamp;
        stakes[msg.sender].lastHarvestTime = block.timestamp;
        totalRewardsStaked += _rewardsStaked;
        emit HarvestComplete(msg.sender);
        emit Restaked(msg.sender, stakes[msg.sender].stakedAmount, _rewardsStaked);
        mutex = false;
    }

    function unstake(uint256 _stakedAmount, uint256 _rewardsStaked) external notPaused notMutex onlyWhitelisted {
        require(stakers[msg.sender]);
        require(stakes[msg.sender].whitelist == true);
        mutex = true;
        _claimRewards();
        totalStaked -= _stakedAmount;
        stakes[msg.sender].stakedAmount -= _stakedAmount;
        totalRewardsStaked -= _rewardsStaked;
        stakes[msg.sender].totalRewards -= _rewardsStaked;
        stakes[msg.sender].rewardsStaked -= _rewardsStaked;
        stakes[msg.sender].cooldownEnd += cooldownPeriod + block.timestamp;
        withdrawDetails[msg.sender].stakeWithdraw += _stakedAmount;
        withdrawDetails[msg.sender].rewardsWithdraw += _rewardsStaked;
        emit StakeRemoved(msg.sender);
        mutex = false;
    }

    function _claimRewards() internal updateReward returns (uint256) {
        require(block.timestamp > stakes[msg.sender].finishAt, "Cannot claim rewards before lockup period ends");
        uint256 reward = rewards[msg.sender] + getExtraRewards(msg.sender);
        stakes[msg.sender].totalRewards += reward;
        rewards[msg.sender] = 0;
        emit RewardsClaimed(msg.sender, reward);
        return reward;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +(rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalStaked;
    }

    //Restricted Functions

    function setConfig( 
        uint256 _lockupTime,
        uint256 _rewardRate,
        uint256 _rewardPerTokenStored,
        uint256 _extraRewardRate,
        uint256 _cooldownPeriod
    ) external onlyAdmin {
        lockupTime = _lockupTime;
        rewardRate = _rewardRate;
        rewardPerTokenStored = _rewardPerTokenStored;
        extraRewardRate = _extraRewardRate;
        cooldownPeriod = _cooldownPeriod;
        emit ConfigUpdate(lockupTime, rewardRate, rewardPerTokenStored, extraRewardRate, cooldownPeriod);
    }

    function blacklistStaker(address user) public onlyAdmin {
        require(stakers[user]);
        stakes[user].whitelist = false;
        emit Blacklisted(user);
    }

    function whitelistStaker(address user) public onlyAdmin {
        require(stakers[user]);
        stakes[user].whitelist = true;
        emit Whitelisted(user);
    }

    function pauseSwitch() public onlyAdmin {
        if (!pause) {
            pause = true;
            emit ContractPaused();
        } else {
            pause = false;
            emit ContractResumed();
        }
    }

}
