// SPDX-License-Identifier: Unlicensed
// @author Isekai Dev

pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title WaifuRewarder
 * @dev A smart contract for staking ERC1155 tokens and earning ERC20 rewards.
 */
contract WaifuRewarder is Ownable, ReentrancyGuard, ERC1155Holder {
    IERC20 public isekai;
    IERC1155 public isekaiIOU;

    // The reward amount per block
    // This is the total amount of reward divided by
    // how many blocks we intend a season to run for
    uint256 private constant REWARD_PER_BLOCK = 100;

    // The season this contract is deployed for
    // Mapped to the isekaiIOU token ID
    uint256 private constant SEASON = 1;

    // The user info for each staker
    struct UserInfo {
        uint256 staked;
        uint256 lastActionBlock;
        uint256 rewardDebt;
    }
    mapping(address => UserInfo) public userInfo;

    // The total amount of staked tokens
    uint256 public totalStaked;
    // The reward accumulation rate
    uint256 public rewardAccumulationRate;

    // The block number of the last update
    uint256 public lastUpdateBlock;

    /**
     * @dev Constructor function
     * @param _isekai The address of the ERC20 reward token
     * @param _isekaiIOU The address of the ERC1155 nft token
     */
    constructor(address _isekai, address _isekaiIOU) {
        isekai = IERC20(_isekai);
        isekaiIOU = IERC1155(_isekaiIOU);
        lastUpdateBlock = block.number;
    }

    /**
     * @dev Stake ERC1155 tokens
     * @param amount The amount of ERC1155 tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        updateRewardAccumulationRate();
        require(isekaiIOU.balanceOf(msg.sender, SEASON) > 0);
        UserInfo storage user = userInfo[msg.sender];
        isekaiIOU.safeTransferFrom(
            msg.sender,
            address(this),
            SEASON,
            amount,
            ""
        );

        if (user.staked > 0) {
            user.rewardDebt += getPendingReward(msg.sender);
        }

        user.staked += amount;
        totalStaked += amount;
        user.lastActionBlock = block.number;
        user.rewardDebt += amount * rewardAccumulationRate;
    }

    /**
     * @dev Withdraw ERC1155 tokens
     * @param amount The amount of ERC1155 tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        updateRewardAccumulationRate();
        UserInfo storage user = userInfo[msg.sender];
        require(user.staked >= amount, "Not enough staked tokens");
        isekaiIOU.safeTransferFrom(
            address(this),
            msg.sender,
            SEASON,
            amount,
            ""
        );

        user.rewardDebt += getPendingReward(msg.sender);

        user.staked -= amount;
        totalStaked -= amount;
        user.lastActionBlock = block.number;
        user.rewardDebt -= amount * rewardAccumulationRate;
    }

    /**
     * @dev Claim the accumulated ERC20 rewards for a user
     */
    function claimReward() external nonReentrant {
        updateRewardAccumulationRate();
        UserInfo storage user = userInfo[msg.sender];
        uint256 pendingReward = getPendingReward(msg.sender);
        require(pendingReward > 0, "No pending reward");

        isekai.transfer(msg.sender, pendingReward);
        user.rewardDebt += pendingReward;
        user.lastActionBlock = block.number;
    }

    /**
     * @dev Update the reward accumulation rate based on the elapsed time and the amount of staked tokens
     */
    function updateRewardAccumulationRate() internal {
        uint256 blocksSinceLastUpdate = block.number - lastUpdateBlock;
        if (blocksSinceLastUpdate == 0 || totalStaked == 0) {
            return;
        }

        uint256 newRewards = blocksSinceLastUpdate * REWARD_PER_BLOCK;
        rewardAccumulationRate += newRewards / totalStaked;
        lastUpdateBlock = block.number;
    }

    /**
     * @dev Get the pending accumulated rewards for a user
     * @param userAddress The address of the user to check
     * @return The amount of pending rewards for the user
     */
    function getPendingReward(address userAddress)
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[userAddress];
        uint256 pendingReward = 0;

        if (totalStaked > 0) {
            uint256 blocksSinceLastUpdate = block.number - user.lastActionBlock;
            uint256 newRewards = blocksSinceLastUpdate * REWARD_PER_BLOCK;
            uint256 newAccumulationRate = rewardAccumulationRate +
                newRewards /
                totalStaked;
            uint256 accumulatedRewards = user.staked * newAccumulationRate;
            pendingReward = accumulatedRewards - user.rewardDebt;
        }

        return pendingReward;
    }

    /**
     * @dev Get amount of tokens staked by user
     * @param userAddress The address of the user
     * @return uint256 representing the amount of tokens staked
     */
    function getStakedAmountForUser(address userAddress)
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[userAddress];
        return user.staked;
    }
}
