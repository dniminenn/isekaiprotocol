// SPDX-License-Identifier: unlicensed
// @author Isekai Dev

pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/**
 * @title WaifuWrapper
 * @dev A smart contract that allows users to wrap ERC1155 tokens from different
 * "seasons" (collections of tokens) into a single ERC1155 token. The contract
 * calculates the total value of the wrapped tokens using a multiplier based on
 * their rarity level. The contract can also wrap ERC721 tokens from a collection
 * defined at deploy time through the construction.
 * TODO: Assign two rarities to custom ERC721 - multipliers 1500 and 3000
 */
contract WaifuWrapper is
    ERC1155,
    ERC721Holder,
    Ownable,
    ReentrancyGuard
{
    // Array of IERC1155 tokens representing the different seasons of tokens
    IERC1155[] public seasonWaifus;

    IERC721 public uniqueWaifu;

    // Multipliers for each rarity level
    uint256[] public multipliers = [1, 5, 20, 100, 1500];

    // Wrapped Waifu that corresponds to unique NFT
    uint256 public constant UNIQUE = 999;

    /**
     * @dev Constructor function that adds an initial season to the
     * "seasonWaifus" array.
     * @param _initialSeasonWaifu Address of the initial season token.
     */
    constructor(address _initialSeasonWaifu, address _uniqueWaifu)
        ERC1155("https://example.com/api/item/{id}.json")
    {
        seasonWaifus.push(IERC1155(_initialSeasonWaifu));
        uniqueWaifu = IERC721(_uniqueWaifu);
    }

    /**
     * @dev Function that allows the contract owner to add additional seasons
     * to the "seasonWaifus" array.
     * @param _seasonWaifu Address of the additional season token.
     */
    function addSeason(address _seasonWaifu) external onlyOwner {
        seasonWaifus.push(IERC1155(_seasonWaifu));
    }

    /**
     * @dev Function that allows users to deposit a unique NFT into the unique
     * season by wrapping it into an ERC1155 token with a fixed value of 1500.
     * @param tokenId ID of the unique NFT to deposit.
     */
    function depositUnique(uint256 tokenId) external {
        uniqueWaifu.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256 totalWrapped = 1500; // 1500x multiplier for unique tokens
        _mint(msg.sender, UNIQUE, totalWrapped, "");
    }

    /**
     * @dev Function that allows users to deposit tokens from a specific season
     * into a wrapped ERC1155 token.
     * @param season Index of the season in the "seasonWaifus" array.
     * @param tokenIds Array of token IDs to deposit.
     * @param amounts Array of amounts to deposit for each token ID.
     */
    function deposit(
        uint256 season,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external nonReentrant {
        require(
            tokenIds.length == amounts.length,
            "TokenIds and amounts length mismatch"
        );

        require(season < seasonWaifus.length, "Season not found");

        IERC1155 seasonWaifu = seasonWaifus[season];

        uint256 totalWrapped = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];

            seasonWaifu.safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                amount,
                ""
            );

            uint256 multiplier = getMultiplier(tokenId);
            totalWrapped += (amount * multiplier);
        }

        _mint(msg.sender, season, totalWrapped, "");
    }

    /**
     * @dev Function that allows users to withdraw a wrapped unique NFT
     * from the contract and receive the underlying unique NFT.
     * @param tokenId ID of the unique NFT to withdraw.
     */
    function withdrawUnique(uint256 tokenId) external {
        uint256 totalWrapped = 1500; // 1500x multiplier for unique tokens
        _burn(msg.sender, UNIQUE, totalWrapped);

        uniqueWaifu.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    /**
     * @dev Function that allows users to withdraw tokens from a wrapped ERC1155
     * token and receive the underlying tokens from a specific season.
     * @param season Index of the season in the "seasonWaifus" array.
     * @param tokenIds Array of token IDs to withdraw.
     * @param amounts Array of amounts to withdraw for each token ID.
     */
    function withdraw(
        uint256 season,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external nonReentrant {
        require(
            tokenIds.length == amounts.length,
            "TokenIds and amounts length mismatch"
        );

        require(season < seasonWaifus.length, "Season not found");

        IERC1155 seasonWaifu = seasonWaifus[season];

        uint256 totalWrapped = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];

            uint256 multiplier = getMultiplier(tokenId);
            totalWrapped += (amount * multiplier);
        }

        _burn(msg.sender, season, totalWrapped);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];

            seasonWaifu.safeTransferFrom(
                address(this),
                msg.sender,
                tokenId,
                amount,
                ""
            );
        }
    }

    /**
     * @dev Function that returns the corresponding multiplier for a token ID
     * based on its rarity level.
     * @param tokenId ID of the token.
     * @return uint256 Corresponding multiplier for the token.
     * @dev Reverts if the token ID is invalid.
     */
    function getMultiplier(uint256 tokenId) public view returns (uint256) {
        if (tokenId >= 0 && tokenId <= 5) {
            return multipliers[0];
        } else if (tokenId >= 6 && tokenId <= 10) {
            return multipliers[1];
        } else if (tokenId >= 11 && tokenId <= 15) {
            return multipliers[2];
        } else if (tokenId >= 16 && tokenId <= 19) {
            return multipliers[3];
        } else if (tokenId == 20 || tokenId == 21) {
            return multipliers[4];
        } else {
            revert("Invalid tokenId");
        }
    }
}
