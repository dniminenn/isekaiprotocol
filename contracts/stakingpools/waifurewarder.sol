// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract WaifuRewarder is ERC1155Holder, ReentrancyGuard {
    IERC1155 public waifuSeasonal;
    IERC20 public rewardToken;
    uint256 public totalReward;
    uint256 public rewardDuration;
    uint256 public startTime;
    uint256 public endTime;
    uint256[] public rewardWeights;

    mapping(address => mapping(uint256 => uint256)) private _lastClaim;
    mapping(address => mapping(uint256 => uint256)) private _userRewards;
    mapping(address => mapping(uint256 => uint256)) private _stakedBalances;
    mapping(uint256 => uint256) public totalStakedTokens; // added to track the total number of staked tokens for each tokenId

    event Staked(address indexed user, uint256 indexed tokenId, uint256 amount);
    event Unstaked(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amount
    );
    event RewardClaimed(
        address indexed user,
        uint256 indexed tokenId,
        uint256 reward
    );

    constructor(
        IERC1155 _waifuSeasonal,
        IERC20 _rewardToken,
        uint256 _totalReward,
        uint256 _rewardDuration,
        uint256[] memory _rewardWeights
    ) {
        // address of seasonal Waifu season
        waifuSeasonal = _waifuSeasonal;
        // address of $ISEKAI
        rewardToken = _rewardToken;
        // total number of tokens at beginning of season
        totalReward = _totalReward;
        // define this in days
        // rewardDuration = 69 days
        rewardDuration = _rewardDuration;
        startTime = block.timestamp;
        endTime = startTime + _rewardDuration;
        /* this is an array with 24 entries, however many season waifus we have
           and their corresponding weights
           [1, 1, 1, 1, 1, 1, 5, 5, 5, 5, 5, 20, 20, 20, 20, 100, 100, 100, 1500, 1500]
           this way rewardWeights[tokenId] will match to it's weight 
        */
        rewardWeights = _rewardWeights;
    }

    // need to rework these to aray uint256[][] array
    function stake(uint256 tokenId, uint256 amount) external nonReentrant {
        require(block.timestamp < endTime, "Staking period has ended");
        require(
            waifuSeasonal.balanceOf(msg.sender, tokenId) >= amount,
            "Insufficient balance to stake"
        );
        require(amount > 0, "Amount should be greater than 0");
        claimReward(tokenId);
        waifuSeasonal.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );
        totalStakedTokens[tokenId] += amount; // update the totalStakedTokens mapping
        _stakedBalances[msg.sender][tokenId] += amount; // map [user][tokenid] to amount
        // update rewards after transfering
        _updateRewards(msg.sender, tokenId);
        emit Staked(msg.sender, tokenId, amount);
    }

    // need to rework these to aray uint256[][] array
    function unstake(uint256 tokenId, uint256 amount) external nonReentrant {
        require(
            waifuSeasonal.balanceOf(address(this), tokenId) >= amount,
            "Not enough tokens staked"
        );
        require(amount > 0, "Amount should be greater than 0");
        claimReward(tokenId);
        // update rewards before transfering
        _updateRewards(msg.sender, tokenId);
        waifuSeasonal.safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amount,
            ""
        );
        _stakedBalances[msg.sender][tokenId] -= amount;
        totalStakedTokens[tokenId] -= amount;
        emit Unstaked(msg.sender, tokenId, amount);
    }

    // need to rework these to aray uint256[][] array
    function claimReward(uint256 tokenId) public nonReentrant {
        _updateRewards(msg.sender, tokenId);
        uint256 reward = _userRewards[msg.sender][tokenId];
        require(reward > 0, "No rewards available");
        _userRewards[msg.sender][tokenId] = 0;
        rewardToken.transfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, tokenId, reward);
    }

    // need to rework these to aray uint256[][] array
    function _updateRewards(address user, uint256 tokenId) private {
        uint256 accumulatedRewardPerToken = _getAccumulatedRewardPerToken(
            tokenId
        );
        uint256 userStakedBalance = _stakedBalances[user][tokenId];
        uint256 newReward = (accumulatedRewardPerToken -
            _lastClaim[user][tokenId]) *
            userStakedBalance *
            rewardWeights[tokenId];
        _userRewards[user][tokenId] += newReward;
        _lastClaim[user][tokenId] = accumulatedRewardPerToken;
    }

    // need to rework these to aray uint256[][] array
    function viewClaimableReward(address user, uint256 tokenId)
        external
        view
        returns (uint256)
    {
        uint256 accumulatedRewardPerToken = _getAccumulatedRewardPerToken(
            tokenId
        );
        uint256 userStakedBalance = _stakedBalances[user][tokenId];
        uint256 newReward = (accumulatedRewardPerToken -
            _lastClaim[user][tokenId]) *
            userStakedBalance *
            rewardWeights[tokenId];
        uint256 claimableReward = _userRewards[user][tokenId] + newReward;
        return claimableReward;
    }

    // this seems to make sense
    function _getAccumulatedRewardPerToken(uint256 tokenId)
        private
        view
        returns (uint256)
    {
        uint256 timeElapsed = block.timestamp > endTime
            ? endTime - startTime
            : block.timestamp - startTime;
        uint256 weightedTotalStaked = 0;
        for (uint256 i = 0; i < rewardWeights.length; i++) {
            weightedTotalStaked += totalStakedTokens[i] * rewardWeights[i];
        }
        uint256 accumulatedRewardPerToken = (totalReward *
            timeElapsed *
            rewardWeights[tokenId]) / (rewardDuration * weightedTotalStaked);
        return accumulatedRewardPerToken;
    }
}
