//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./IERC20.sol";

contract StakingRewards {
    IERC20 public immutable stakedToken;
    IERC20 public immutable rewardToken;

    uint256 public updatedAt;
    uint256 public rewardRate;
    uint256 public duration;
    uint256 public finishAt;
    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;
    address public admin;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    constructor(address _staked, address _reward) {
        stakedToken = IERC20(_staked);
        rewardToken = IERC20(_reward);
        admin = msg.sender;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "You are not the admin");
        _;
    }

    modifier updateReward(address _user) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();
        if (_user != address(0)) {
            rewards[_user] = earned(_user);
            userRewardPerTokenPaid[_user] = rewardPerTokenStored;
        }
        _;
    }

    function setRewardsDuration(uint256 _duration) external onlyAdmin {
        require(block.timestamp > finishAt, "rewards duration not finished");
        duration = _duration;
    }

    function setRewardRate(uint256 _amount) external onlyAdmin updateReward(address(0)) {
        if (block.timestamp > finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint256 rewardsRemaining = rewardRate * (finishAt - block.timestamp);
            rewardRate = (rewardsRemaining + _amount) / duration;
        }
        require(rewardRate > 0, "reward rate should be greater than 0");
        require(rewardRate * duration <= rewardToken.balanceOf(address(this)), "Not enough rewards");
        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function stake(uint256 _stakedAmount) external updateReward(msg.sender) {
        require(_stakedAmount > 0, "Staking amount should be greater than zero");
        stakedToken.transferFrom(msg.sender, address(this), _stakedAmount); //User needs to approve this contract
        balanceOf[msg.sender] += _stakedAmount;
        totalSupply += _stakedAmount;
    }

    function withdraw(uint256 _amount) external updateReward(msg.sender) {
        require(balanceOf[msg.sender] > _amount, "Amount greater than your balance");
        stakedToken.transfer(msg.sender, _amount);
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
    }

    function getRewards() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
        }
    }

    function rewardPerToken() public view returns (uint256) {
        if(totalSupply == 0) {
            return rewardPerTokenStored;
        } else {
            return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18)/ totalSupply;
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(block.timestamp, finishAt);
    }

    function earned(address _user) public view returns (uint256) {
        return (balanceOf[_user] * (rewardPerToken() - userRewardPerTokenPaid[_user])) / 1e18 + rewards[_user];
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x <= y ? x : y);
    }
}
