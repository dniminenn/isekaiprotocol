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
    address[] public stakers;

    mapping(address => mapping(uint256 => uint256)) public stakedTokens;
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public claimedRewards;
    mapping(uint256 => uint256) public stakedTokensTotal;
    

    event TokensStaked(address indexed user, uint256 tokenId, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 tokenId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed tokenId, uint256 amount);

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
        uint256 total = 0;
        for (uint256 i = 0; i < rewardRates.length; i++) {
            total += stakedTokensTotal[i];
        }
        return total;
    }

    function stakeTokens(uint256 tokenId, uint256 amount)
        external
        nonReentrant
    {
        require(amount > 0, "Cannot stake zero tokens");
        require(tokenId < rewardRates.length, "Invalid token ID");

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

        nftToken.safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amount,
            ""
        );

        stakedTokens[msg.sender][tokenId] -= amount;
        stakedTokensTotal[tokenId] -= amount;

        emit TokensUnstaked(msg.sender, tokenId, amount);
    }

    function distributeReward(uint256 rewardAmount) external onlyRewardToken {
        totalDistributedRewards += rewardAmount;
    }

    function claimReward(uint256 tokenId) external nonReentrant {
        require(
            nftToken.balanceOf(msg.sender, tokenId) > 0,
            "Not staking this token"
        );

        uint256 userTotalStakedTokens = stakedTokens[msg.sender][tokenId] *
            rewardRates[tokenId];
        uint256 userRewardShare = (userTotalStakedTokens *
            totalDistributedRewards) / totalStakedTokens();
        uint256 reward = userRewardShare - claimedRewards[msg.sender];

        require(reward > 0, "No rewards available");

        claimedRewards[msg.sender] += reward;
        pendingRewards[msg.sender] = 0;

        rewardToken.transfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, tokenId, reward);
    }
}
