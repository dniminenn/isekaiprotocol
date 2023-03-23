// SPDX-License-Identifier: Unlicensed
// @author Isekai Dev

pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./erc721a/ERC721A.sol";

/**
 * @title UniqueWaifu
 * @dev ERC721A-compatible contract for minting and managing unique waifu NFTs.
 * @author Isekai Dev
 * @notice This contract allows users to mint unique waifu NFTs and provides functions for managing the collection.
 * @notice The contract also implements functions for interfacing with OpenSea.
 */
contract UniqueWaifu is ERC721A, Ownable {
    string private _baseUrl = "https://assets.isekai.online/legends/";
    // used by opensea contractURI() to populate collection overview
    string private _contractUrl =
        "https://assets.isekai.online/legends/IsekaiLegends.json";
    uint256 private _amountClaim = 100000000000000000000;

    address private _oracleAddress;

    mapping(uint256 => bool) private _isLegendary;

    constructor(
        string memory baseUrl,
        string memory contractUrl,
        uint256 price
    ) ERC721A("Isekai Legends", "ISEKAI") {
        _baseUrl = baseUrl;
        _contractUrl = contractUrl;
        _amountClaim = price;
    }

    modifier onlyOracle() {
        require(
            msg.sender == _oracleAddress,
            "Only the oracle can call this function."
        );
        _;
    }

    /**
     * @dev Sets the address of the oracle that can call restricted functions.
     * @param oracle The address of the oracle.
     */
    function setOracleAddress(address oracle) public onlyOwner {
        _oracleAddress = oracle;
    }

    // override the first token id to 1 instead of 0
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /**
     * @dev Returns the status of a specific legendary NFT.
     * @param id The ID of the NFT being queried.
     * @return true if the NFT is legendary, false otherwise.
     */
    function getLegendary(uint256 id) public view returns (bool) {
        return _isLegendary[id];
    }

    // set mint price after deploy, or change anytime
    function setClaim(uint256 _amount) public onlyOwner {
        _amountClaim = _amount;
    }

    /**
     * @dev Mints a single unique waifu NFT to the specified wallet address.
     * @param _to The address of the wallet to receive the NFT.
     * @param isLegendary Whether the NFT should be a legendary one or not.
     */
    function processMint(address _to, bool isLegendary) public onlyOracle {
        _safeMint(_to, 1);
        uint256 currentid = totalSupply() + 1;
        if (isLegendary) {
            _isLegendary[currentid] = true;
        }
    }

    // cash out
    function withdraw(address payable _to, uint256 _amount) public onlyOwner {
        _to.transfer(_amount);
    }

    /**
     * @dev Allows a user to request the minting of a unique waifu NFT by paying the current mint price.
     */
    function requestMint() public payable {
        require(msg.value == _amountClaim, "Incorrect price");
        // implement Event for requesting oracle
    }

    /**
     * @dev Returns the base URL for the location of the NFT metadata.
     * @return The base URL for the location of the NFT metadata.
     */
    function baseTokenURI() public view returns (string memory) {
        return _baseUrl;
    }

    /**
     * @dev Updates the base URL for the location of the NFT metadata.
     * @param newBase The new base URL.
     */
    function updateBase(string memory newBase) public onlyOwner {
        _baseUrl = newBase;
    }

    /**
     * @dev Returns the location of the metadata for a specific NFT.
     * @param _tokenId The ID of the NFT being queried.
     * @return The location of the metadata for the specified NFT.
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    baseTokenURI(),
                    Strings.toString(_tokenId),
                    ".json"
                )
            );
    }

    /**
     * @dev Returns the location of the JSON file that provides information about the collection.
     * Used by OpenSea
     * @return The location of the JSON file that provides information about the collection.
     */
    function contractURI() public view returns (string memory) {
        return _contractUrl;
    }
}
