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
    address[] public stakers;

    mapping(address => mapping(uint256 => uint256)) public stakedTokens;
    mapping(address => uint256) public pendingRewards;

    event TokensStaked(address indexed user, uint256 tokenId, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 tokenId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(IERC1155 _nftToken, IERC20 _rewardToken, uint256[] memory _rewardRates) {
        nftToken = _nftToken;
        rewardToken = _rewardToken;
        rewardRates = _rewardRates;
    }

    modifier onlyRewardToken() {
        require(msg.sender == address(rewardToken), "Caller is not the reward token");
        _;
    }

    function totalStakedTokens() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < rewardRates.length; i++) {
            total += rewardRates[i] * nftToken.totalSupply(i);
        }
        return total;
    }

        function stakeTokens(uint256 tokenId, uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake zero tokens");
        require(tokenId < rewardRates.length, "Invalid token ID");

        nftToken.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        stakedTokens[msg.sender][tokenId] += amount;
        stakers.push(msg.sender);

        emit TokensStaked(msg.sender, tokenId, amount);
    }

    function unstakeTokens(uint256 tokenId, uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake zero tokens");
        require(tokenId < rewardRates.length, "Invalid token ID");
        require(stakedTokens[msg.sender][tokenId] >= amount, "Not enough staked tokens");

        nftToken.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");

        stakedTokens[msg.sender][tokenId] -= amount;

        emit TokensUnstaked(msg.sender, tokenId, amount);
    }

    function distributeReward(uint256 rewardAmount) external onlyRewardToken {
        uint256 totalTokens = totalStakedTokens();
        require(totalTokens > 0, "No staked tokens");

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 userTotalStakedTokens = 0;

            for (uint256 tokenId = 0; tokenId < rewardRates.length; tokenId++) {
                userTotalStakedTokens += stakedTokens[staker][tokenId] * rewardRates[tokenId];
            }

            if (userTotalStakedTokens > 0) {
                uint256 reward = (rewardAmount * userTotalStakedTokens) / totalTokens;
                pendingRewards[staker] += reward;
            }
        }
    }

    function claimReward() external nonReentrant {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, "No pending rewards");

        pendingRewards[msg.sender] = 0;

        rewardToken.transfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }
}
