// SPDX-License-Identifier: unlicense
// THIS CODE IS DANGEROUS
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract WaifuRewarder is ERC1155Holder, ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    IERC20 public rewardToken;
    IERC1155 public nftToken;
    uint256 public totalStaked;
    mapping(address => mapping(uint256 => uint256)) public stakedBalances;
    mapping(uint256 => address[]) public stakers;
    mapping(uint256 => uint256) public stakedTokensTotal;
    mapping(uint256 => uint256) public rewardRates;
    mapping(address => mapping(uint256 => uint256)) public lastClaimed;

    event Staked(address indexed user, uint256 tokenId, uint256 amount);
    event Unstaked(address indexed user, uint256 tokenId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 tokenId, uint256 rewardAmount);

    constructor(IERC20 _rewardToken, IERC1155 _nftToken) {
        rewardToken = _rewardToken;
        nftToken = _nftToken;
    }

    function setRewardRate(uint256 tokenId, uint256 rate) external onlyOwner {
        rewardRates[tokenId] = rate;
    }

    function stake(uint256 tokenId, uint256 amount) external nonReentrant {
        require(rewardRates[tokenId] > 0, "Reward rate not set for this token ID");
        nftToken.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        if (stakedBalances[msg.sender][tokenId] == 0) {
            // Add user to the list of stakers for this token ID
            stakers[tokenId].push(msg.sender);
        }

        stakedBalances[msg.sender][tokenId] = stakedBalances[msg.sender][tokenId].add(amount);
        stakedTokensTotal[tokenId] = stakedTokensTotal[tokenId].add(amount);
        totalStaked = totalStaked.add(amount);
        emit Staked(msg.sender, tokenId, amount);
    }

    function unstake(uint256 tokenId, uint256 amount) external nonReentrant {
        require(rewardRates[tokenId] > 0, "Reward rate not set for this token ID");
        require(stakedBalances[msg.sender][tokenId] >= amount, "Not enough staked tokens");

        // Claim any pending rewards before unstaking
        claimReward(tokenId);

        nftToken.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");

        stakedBalances[msg.sender][tokenId] = stakedBalances[msg.sender][tokenId].sub(amount);
        stakedTokensTotal[tokenId] = stakedTokensTotal[tokenId].sub(amount);
        totalStaked = totalStaked.sub(amount);
        emit Unstaked(msg.sender, tokenId, amount);
    }

    function claimReward(uint256 tokenId) public nonReentrant {
        require(rewardRates[tokenId] > 0, "Reward rate not set for this token ID");
        uint256 stakedAmount = stakedBalances[msg.sender][tokenId];
        require(stakedAmount > 0, "No staked tokens");

        uint256 lastClaimedTimestamp = lastClaimed[msg.sender][tokenId];
        uint256 elapsedTime = block.timestamp.sub(lastClaimedTimestamp);

        uint256 pendingReward = stakedAmount.mul(rewardRates[tokenId]).mul(elapsedTime).div(86400); // 86400 seconds in a day

        require(pendingReward > 0, "No rewards available");
        require(rewardToken.balanceOf(address(this)) >= pendingReward, "Not enough reward tokens");

        rewardToken.transfer(msg.sender, pendingReward);
        lastClaimed[msg.sender][tokenId] = block.timestamp;

        emit RewardClaimed(msg.sender, tokenId, pendingReward);
    }
}