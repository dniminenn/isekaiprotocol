// SPDX-License-Identifier: UNLICENSED
// @author Isekai Dev
// THIS THING IS FUCKING INSANE! :)

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
contract WaifuWrapper is ERC1155, ERC721Holder, Ownable, ReentrancyGuard {
    // Array of IERC1155 tokens representing the different seasons of tokens
    IERC1155[] private seasonWaifus;

    IERC721 private uniqueWaifu;

    // Multipliers for each rarity level
    uint256[] private multipliers = [1, 5, 20, 100, 1500];

    // Wrapped Waifu that corresponds to unique NFT
    uint256 private constant UNIQUE = 999;

    // Mapping userWrappedNFTs[address][season][tokenid] stores amounts, ERC1155
    mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
        private userWrappedNFTs;

    // Mapping to store unique token IDs staked by each user
    mapping(address => uint256[]) private userUniqueStaked;

    // Mapping to store the owner of unique NFTs
    mapping(uint256 => address) private uniqueWaifuOwners;

    // Mapping to store the wrapped ERC1155 token IDs and their respective owners
    mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
        private wrappedERC1155Tokens;

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
    function wrapUnique(uint256 tokenId) external nonReentrant {
        uniqueWaifu.safeTransferFrom(msg.sender, address(this), tokenId);

        uniqueWaifuOwners[tokenId] = msg.sender;
        uint256 totalWrapped = 1500; // 1500x multiplier for unique tokens
        _mint(msg.sender, UNIQUE, totalWrapped, "");
        userUniqueStaked[msg.sender].push(tokenId);
    }

    /**
     * @dev Function that allows users to deposit tokens from a specific season
     * into a wrapped ERC1155 token.
     * @param season Index of the season in the "seasonWaifus" array.
     * @param tokenIds Array of token IDs to deposit.
     * @param amounts Array of amounts to deposit for each token ID.
     */
    function wrapSeasonal(
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
            userWrappedNFTs[msg.sender][season][tokenId] += amount;
            wrappedERC1155Tokens[msg.sender][season][tokenId] += amount;
        }

        _mint(msg.sender, season, totalWrapped, "");
    }

    /**
     * @dev Function that allows users to withdraw a wrapped unique NFT
     * from the contract and receive the underlying unique NFT.
     * @param tokenId ID of the unique NFT to withdraw.
     */
    function unwrapUnique(uint256 tokenId) external nonReentrant {
        require(
            uniqueWaifuOwners[tokenId] == msg.sender,
            "Not the owner of the unique NFT"
        );

        uint256 totalUnwrapped = 1500; // 1500x multiplier for unique tokens
        _burn(msg.sender, UNIQUE, totalUnwrapped);

        uniqueWaifu.safeTransferFrom(address(this), msg.sender, tokenId);

        uint256[] storage uniqueTokenIds = userUniqueStaked[msg.sender];
        for (uint256 i = 0; i < uniqueTokenIds.length; i++) {
            if (uniqueTokenIds[i] == tokenId) {
                uniqueTokenIds[i] = uniqueTokenIds[uniqueTokenIds.length - 1];
                uniqueTokenIds.pop();
                break;
            }
        }
        delete uniqueWaifuOwners[tokenId];
    }

    /**
     * @dev Function that allows users to withdraw tokens from a wrapped ERC1155
     * token and receive the underlying tokens from a specific season.
     * @param season Index of the season in the "seasonWaifus" array.
     * @param tokenIds Array of token IDs to withdraw.
     * @param amounts Array of amounts to withdraw for each token ID.
     */
    function unwrapSeasonal(
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

        uint256 totalUnwrapped = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];

            require(
                wrappedERC1155Tokens[msg.sender][season][tokenId] >= amount,
                "Not the owner or insufficient wrapped ERC1155 tokens"
            );
            wrappedERC1155Tokens[msg.sender][season][tokenId] -= amount;

            uint256 multiplier = getMultiplier(tokenId);

            seasonWaifu.safeTransferFrom(
                address(this),
                msg.sender,
                tokenId,
                amount,
                ""
            );
            totalUnwrapped += (amount * multiplier);
            userWrappedNFTs[msg.sender][season][tokenId] -= amount;
        }

        _burn(msg.sender, season, totalUnwrapped);
    }

    /**
     * @dev Function that returns the corresponding multiplier for a token ID
     * based on its rarity level.
     * @param tokenId ID of the token.
     * @return uint256 Corresponding multiplier for the token.
     * @dev Reverts if the token ID is invalid.
     */
    function getMultiplier(uint256 tokenId) public view returns (uint256) {
        if (tokenId >= 0 && tokenId <= 2) {
            return multipliers[0];
        } else if (tokenId >= 3 && tokenId <= 5) {
            return multipliers[1];
        } else if (tokenId >= 6 && tokenId <= 8) {
            return multipliers[2];
        } else if (tokenId >= 9 && tokenId <= 10) {
            return multipliers[3];
        } else if (tokenId == 11) {
            return multipliers[4];
        } else {
            revert("Invalid tokenId");
        }
    }

    /**
     * @dev Returns the wrapped NFTs owned by a specific user and season.
     * @param user The address of the user whose wrapped NFTs are being queried.
     * @param season The season ID for which the wrapped NFTs are being queried.
     * @return tokenIds An array of the wrapped NFT token IDs owned by the user.
     * @return amounts An array of the corresponding amounts of each wrapped NFT owned by the user.
     * @return uniqueTokenIds An array of the unique ERC721 token IDs staked by the user.
     */
    function getuserWrappedNFTs(address user, uint256 season)
        public
        view
        returns (
            uint256[] memory tokenIds,
            uint256[] memory amounts,
            uint256[] memory uniqueTokenIds
        )
    {
        // Define the range of token IDs based on your contract's requirements
        uint256 minTokenId = 0;
        uint256 maxTokenId = 11;

        uint256[] memory _tokenIds = new uint256[](maxTokenId - minTokenId + 1);
        uint256[] memory _amounts = new uint256[](maxTokenId - minTokenId + 1);

        for (uint256 tokenId = minTokenId; tokenId <= maxTokenId; tokenId++) {
            _tokenIds[tokenId - minTokenId] = tokenId;
            _amounts[tokenId - minTokenId] = userWrappedNFTs[user][season][
                tokenId
            ];
        }

        // Get unique ERC721 token IDs staked by the user from the mapping
        uint256 uniqueBalance = balanceOf(user, UNIQUE);
        uint256[] memory _uniqueTokenIds = new uint256[](uniqueBalance);

        if (uniqueBalance > 0) {
            _uniqueTokenIds = userUniqueStaked[user];
        }

        return (_tokenIds, _amounts, _uniqueTokenIds);
    }
}
