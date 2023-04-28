// SPDX-License-Identifier: UNLICENSED
// @author Isekai Dev
pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "contracts/tokens/ICrystalsToken.sol";

/**
 * @title LPRewarder
 * @dev This contract allows users to stake LP tokens and receive rewards in Crystals tokens.
 * Rewards are distributed proportionally to the amount of LP tokens staked by each user.
 */
contract LPRewarder is Ownable, ReentrancyGuard, Pausable {
    IERC20 public lpToken;
    ICrystalsToken public crystals;

    mapping(address => bool) private _authorizedAddresses;

    struct UserInfo {
        uint256 staked;
        uint256 lastActionBlock;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public userInfo;
    uint256 public totalStaked;
    uint256 public rewardPerBlock;
    uint256 public rewardAccumulationRate;
    uint256 public lastUpdateBlock;

    /**
     * @dev Initializes the contract with the given LP token and Crystals token addresses, and
     * the initial reward per block.
     * @param _crystals Address of the Crystals token contract.
     * @param _rewardPerBlock Initial reward per block in wei units
     */
    constructor(
        address _crystals,
        uint256 _rewardPerBlock
    ) {
        lpToken = IERC20(0x47130c5227e478C393288295fC4d975580bD9CDf); // this is the sushi LP
        crystals = ICrystalsToken(_crystals);
        rewardPerBlock = _rewardPerBlock;
        lastUpdateBlock = block.number;
        _pause();
    }

    /** Authorized addresses to pause
     */
    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || _authorizedAddresses[msg.sender],
            "Caller is not authorized"
        );
        _;
    }

    function addAuthorizedAddress(address newAddress) public onlyOwner {
        require(_authorizedAddresses[newAddress] == false, "Oops");
        _authorizedAddresses[newAddress] = true;
    }

    function removeAuthorizedAddress(address addressToRemove) public onlyOwner {
        require(_authorizedAddresses[addressToRemove] == true, "Oops");
        _authorizedAddresses[addressToRemove] = false;
    }

    /** Emergency pause, can only be reset by multisig
     */
    function pause() public onlyAuthorized {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Allows a user to stake LP tokens in the contract.
     * @param amount Amount of LP tokens to stake.
     */
    function stake(uint256 amount) external whenNotPaused nonReentrant {
        updateRewardAccumulationRate();
        UserInfo storage user = userInfo[msg.sender];

        lpToken.transferFrom(msg.sender, address(this), amount);

        if (user.staked > 0) {
            uint256 pendingReward = getPendingReward(msg.sender);
            if (pendingReward > 0) {
                crystals.mint(msg.sender, pendingReward);
            }
        }

        user.staked += amount;
        totalStaked += amount;
        user.lastActionBlock = block.number;
        user.rewardDebt = user.staked * rewardAccumulationRate;
    }

    /**
     * @dev Allows a user to withdraw their staked LP tokens and claim any pending rewards.
     * @param amount Amount of LP tokens to withdraw.
     */
    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        updateRewardAccumulationRate();
        UserInfo storage user = userInfo[msg.sender];
        require(user.staked >= amount, "Not enough staked tokens");

        lpToken.transfer(msg.sender, amount);

        uint256 pendingReward = getPendingReward(msg.sender);
        if (pendingReward > 0) {
            crystals.mint(msg.sender, pendingReward);
        }

        user.staked -= amount;
        totalStaked -= amount;
        user.lastActionBlock = block.number;
        user.rewardDebt = user.staked * rewardAccumulationRate;
    }

    /**
     * @dev Allows the user to claim their pending rewards.
     * The amount of rewards to claim is calculated based on the user's staked balance and the current reward accumulation rate.
     * Mints new $crystal
     */
    function claimReward() external whenNotPaused nonReentrant {
        updateRewardAccumulationRate();
        UserInfo storage user = userInfo[msg.sender];
        uint256 pendingReward = getPendingReward(msg.sender);
        require(pendingReward > 0, "No pending reward");

        crystals.mint(msg.sender, pendingReward);
        user.rewardDebt += pendingReward;
        user.lastActionBlock = block.number;
    }

    /**
     * @dev Update the reward accumulation rate based on the number of blocks
     *      that have passed since the last update and the total amount of staked
     *      LP tokens.
     *
     *      The new reward accumulation rate is calculated as follows:
     *          1. Calculate the number of blocks since the last update
     *          2. Calculate the new rewards based on the reward per block
     *             and the number of blocks since the last update
     *          3. Add the new rewards to the existing rewards
     *          4. Divide the total rewards by the total staked amount to get
     *             the new reward accumulation rate
     *
     *      If no blocks have passed since the last update or if there are no
     *      staked LP tokens, the function will exit early.
     */
    function updateRewardAccumulationRate() internal {
        uint256 blocksSinceLastUpdate = block.number - lastUpdateBlock;
        if (blocksSinceLastUpdate == 0) {
            return;
        }

        uint256 newRewards = blocksSinceLastUpdate * rewardPerBlock;

        // Check if totalStaked is greater than 0 to avoid divide by zero error
        if (totalStaked > 0) {
            rewardAccumulationRate += newRewards / totalStaked;
        }

        lastUpdateBlock = block.number;
    }

    /**
     * @dev Calculates the pending reward for a given user.
     * @param userAddress The address of the user to check for pending rewards.
     * @return The amount of crystals pending for the user.
     */
    function getPendingReward(address userAddress)
        internal
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[userAddress];
        uint256 accumulatedRewards = user.staked * rewardAccumulationRate;
        uint256 pendingReward = accumulatedRewards - user.rewardDebt;
        return pendingReward;
    }

    function getUpdatedPendingReward(address userAddress)
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[userAddress];
        uint256 currentRewardAccumulationRate = rewardAccumulationRate;
        uint256 blocksSinceLastUpdate = block.number - lastUpdateBlock;

        if (blocksSinceLastUpdate > 0 && totalStaked > 0) {
            uint256 newRewards = blocksSinceLastUpdate * rewardPerBlock;
            currentRewardAccumulationRate += newRewards / totalStaked;
        }

        uint256 accumulatedRewards = user.staked *
            currentRewardAccumulationRate;
        uint256 pendingReward = accumulatedRewards - user.rewardDebt;

        return pendingReward;
    }

    /**
     * @dev Returns the staked balance of the specified user.
     * @param userAddress The address of the user to retrieve the balance of.
     * @return The amount of LP tokens staked by the user.
     */
    function getStakedAmountForUser(address userAddress)
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[userAddress];
        return user.staked;
    }

    /**
     * @dev Sets the new reward per block. Only the owner can call this function.
     * @param _newRewardPerBlock The new reward per block.
     */
    function setRewardPerBlock(uint256 _newRewardPerBlock) external onlyOwner {
        updateRewardAccumulationRate();
        lastUpdateBlock = block.number;
        rewardPerBlock = _newRewardPerBlock;
    }

    function setCrystalsAddress(address _crystals) external onlyOwner {
        crystals = ICrystalsToken(_crystals);
    }
}
