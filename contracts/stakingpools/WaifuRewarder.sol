// SPDX-License-Identifier: UNLICENSED
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
 * This will be deployed twice per season
 * - Unique: always take season 999 in constructor
 * - Seasonal: deploy with season number in constructor
 * Contract will ceased distributing at the calculated endBlock
 */
contract WaifuRewarder is Ownable, ReentrancyGuard, ERC1155Holder {
    IERC20 public isekai;
    IERC1155 public isekaiIOU;

    // The reward amount per block, the "emissions rate"
    // defined and constructor and FIXED for the duration
    // of the season
    uint256 public rewardPerBlock;

    // The season this contract is deployed for
    // Mapped to the isekaiIOU token ID
    uint256 public season;

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

    // The total reward divided by the reward per block
    uint256 public endBlock;

    /**
     * @dev Constructor function for the IsekaiIOUStaking contract.
     * @param _isekai The address of the Isekai ERC20 token contract.
     * @param _isekaiIOU The address of the IsekaiIOU ERC1155 token contract.
     * The function initializes the `isekai` and `isekaiIOU` variables with the provided contract addresses.
     * The `lastUpdateBlock` variable is set to the current block number.
     * The `endBlock` variable is calculated based on the `initialRewardAmount` and `rewardPerBlock` variables,
     * and represents the block number at which the staking rewards will end.
     * Finally, the contract calls the `transferFrom` function of the Isekai contract to transfer the `initialRewardAmount`
     * from the `msg.sender` to the address of the IsekaiIOUStaking contract.
     */
    constructor(
        address _isekai,
        address _isekaiIOU,
        uint256 _season,
        uint256 initialTokenBalance,
        uint256 _rewardPerBlock
    ) {
        season = _season;
        isekai = IERC20(_isekai);
        isekaiIOU = IERC1155(_isekaiIOU);
        lastUpdateBlock = block.number;
        rewardPerBlock = _rewardPerBlock;

        uint256 blocksToRun = initialTokenBalance / _rewardPerBlock;
        // subtract one block for buffer
        endBlock = (lastUpdateBlock + blocksToRun) - 1;

        // Transfer initial token balance directly from the deployer to the contract
        // isekai.transfer(address(this), initialTokenBalance);
        // it looks like we must approve then send in the tokens
    }

    /**
     * @dev Stake ERC1155 tokens
     * @param amount The amount of ERC1155 tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        updateRewardAccumulationRate();
        UserInfo storage user = userInfo[msg.sender];
        isekaiIOU.safeTransferFrom(
            msg.sender,
            address(this),
            season,
            amount,
            ""
        );

        if (user.staked > 0) {
            uint256 pendingReward = getPendingReward(msg.sender);
            if (pendingReward > 0) {
                isekai.transfer(msg.sender, pendingReward);
            }
        }

        user.staked += amount;
        totalStaked += amount;
        user.lastActionBlock = block.number;
        user.rewardDebt = user.staked * rewardAccumulationRate;
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
            season,
            amount,
            ""
        );

        uint256 pendingReward = getPendingReward(msg.sender);
        if (pendingReward > 0) {
            isekai.transfer(msg.sender, pendingReward);
        }

        user.staked -= amount;
        totalStaked -= amount;
        user.lastActionBlock = block.number;
        user.rewardDebt = user.staked * rewardAccumulationRate;
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
        // Stop generating new rewards after the end block
        if (block.number >= endBlock) {
            blocksSinceLastUpdate = endBlock - lastUpdateBlock;
        }

        uint256 newRewards = blocksSinceLastUpdate * rewardPerBlock;
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
            uint256 blocksSinceLastUpdate;
            if (block.number <= endBlock) {
                blocksSinceLastUpdate = block.number - user.lastActionBlock;
            } else {
                blocksSinceLastUpdate = endBlock - user.lastActionBlock;
            }
            uint256 newRewards = blocksSinceLastUpdate * rewardPerBlock;
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
