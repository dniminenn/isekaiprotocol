// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract WaifuRewarder is Ownable, ReentrancyGuard {
    IERC1155 public nftToken;
    IERC20 public rewardToken;

    uint256[] public rewardRates;
    uint256 public totalDistributedRewards;
    uint256 public totalcount;
    address[] public stakers;

    mapping(address => mapping(uint256 => uint256)) public stakedTokens;
    mapping(address => uint256) public pendingRewards;
    mapping(address => mapping(uint256 => uint256)) public claimedRewards;
    mapping(uint256 => uint256) public stakedTokensTotal;
    mapping(address => mapping(uint256 => uint256)) public lastRewardUpdate;

    event TokensStaked(address indexed user, uint256 tokenId, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 tokenId, uint256 amount);
    event RewardClaimed(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amount
    );

    constructor(
        IERC1155 _nftToken,
        IERC20 _rewardToken,
        uint256[] memory _rewardRates
    ) {
        nftToken = _nftToken;
        rewardToken = _rewardToken;
        rewardRates = _rewardRates;
    }

    modifier onlyRewardToken() {
        require(
            msg.sender == address(rewardToken),
            "Caller is not the reward token"
        );
        _;
    }

    function totalStakedTokens() public view returns (uint256) {
        return totalcount;
    }

    function stakeTokens(uint256 tokenId, uint256 amount)
        external
        nonReentrant
    {
        require(amount > 0, "Cannot stake zero tokens");
        require(tokenId < rewardRates.length, "Invalid token ID");
        claimReward(tokenId);
        nftToken.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );
        stakedTokens[msg.sender][tokenId] += amount;
        stakers.push(msg.sender);
        stakedTokensTotal[tokenId] += amount;
        totalcount += amount;

        emit TokensStaked(msg.sender, tokenId, amount);
    }

    function unstakeTokens(uint256 tokenId, uint256 amount)
        external
        nonReentrant
    {
        require(amount > 0, "Cannot unstake zero tokens");
        require(tokenId < rewardRates.length, "Invalid token ID");
        require(
            stakedTokens[msg.sender][tokenId] >= amount,
            "Not enough staked tokens"
        );
        claimReward(tokenId);
        nftToken.safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amount,
            ""
        );

        stakedTokens[msg.sender][tokenId] -= amount;
        stakedTokensTotal[tokenId] -= amount;
        totalcount -= amount;

        emit TokensUnstaked(msg.sender, tokenId, amount);
    }

    function distributeReward(uint256 rewardAmount) external onlyRewardToken {
        totalDistributedRewards += rewardAmount;
    }

    function claimReward(uint256 tokenId) public nonReentrant {
        require(
            stakedTokens[msg.sender][tokenId] > 0,
            "Not staking this token"
        );

        uint256 stakedTokenAmount = stakedTokens[msg.sender][tokenId];
        uint256 rewardRate = rewardRates[tokenId];
        uint256 totalTokens = totalStakedTokens();
        uint256 totalReward = rewardToken.balanceOf(address(this));

        uint256 lastUpdate = lastRewardUpdate[msg.sender][tokenId];
        uint256 timeElapsed = block.timestamp - lastUpdate;
        uint256 accumulatedReward = (totalReward *
            timeElapsed *
            stakedTokenAmount *
            rewardRate) / (totalTokens * 1 days);

        uint256 pendingReward = accumulatedReward -
            claimedRewards[msg.sender][tokenId];

        require(pendingReward > 0, "No pending reward");

        claimedRewards[msg.sender][tokenId] = accumulatedReward;
        lastRewardUpdate[msg.sender][tokenId] = block.timestamp;
        rewardToken.transfer(msg.sender, pendingReward);

        emit RewardClaimed(msg.sender, tokenId, pendingReward);
    }
}
