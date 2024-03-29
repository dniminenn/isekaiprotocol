// SPDX-License-Identifier: Unlicensed
// @author Isekai Dev

pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title UniqueWaifu
 * @dev ERC721A-compatible contract for minting and managing unique waifu NFTs.
 * @author Isekai Dev
 * @notice This contract allows users to mint unique waifu NFTs and provides functions for managing the collection.
 * @notice The contract also implements functions for interfacing with OpenSea.
 */
contract UniqueWaifu is
    ERC721,
    ERC721Enumerable,
    ERC721Burnable,
    Pausable,
    Ownable,
    ReentrancyGuard
{
    uint256 _mintnonce;
    mapping(bytes32 => bool) private _pendingMints;

    string private _baseUrl = "https://assets.isekai.online/legends/";
    // used by opensea contractURI() to populate collection overview
    string private _contractUrl =
        "https://assets.isekai.online/legends/IsekaiLegends.json";
    uint256 public _amountClaim = 100000000000000000000;

    address private _oracleAddress;
    address private _bridgeAddress;
    mapping(address => bool) private _authorizedAddresses;

    mapping(uint256 => bool) private _isLegendary;

    uint256 private _royaltyPercentage = 5;

    // for oracle use
    event MintRequest(address indexed user, uint256 nonce);
    // to update user dapp
    event MintProcessed(address indexed user, uint256 nonce);

    constructor(
        string memory baseUrl,
        string memory contractUrl,
        uint256 price,
        uint256 royaltyPercentage
    ) ERC721("Isekai Legends", "ISEKAI") {
        _baseUrl = baseUrl;
        _contractUrl = contractUrl;
        _amountClaim = price;
        _royaltyPercentage = royaltyPercentage;
        _mintnonce = 1; // first ID = 1
        _pause();
    }

    modifier onlyOracle() {
        require(
            msg.sender == _oracleAddress,
            "Only the oracle can call this function."
        );
        _;
    }

    modifier onlyBridge() {
        require(
            msg.sender == _bridgeAddress,
            "Only the vridge can call this function."
        );
        _;
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

    /** Emergency pause, can only be reset by multisig
     */
    function pause() public onlyAuthorized {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Sets the address of the oracle that can call restricted functions.
     * @param oracle The address of the oracle.
     */
    function setOracleAddress(address oracle) public onlyOwner {
        _oracleAddress = oracle;
    }

    /**
     * @dev Sets the address of the bridge that can call restricted functions.
     * @param bridge The address of the bridge.
     */
    function setBridgeAddress(address bridge) public onlyOwner {
        _bridgeAddress = bridge;
    }

    function addAuthorizedAddress(address newAddress) public onlyOwner {
        require(_authorizedAddresses[newAddress] == false, "Oops");
        _authorizedAddresses[newAddress] = true;
    }

    function removeAuthorizedAddress(address addressToRemove) public onlyOwner {
        require(_authorizedAddresses[addressToRemove] == true, "Oops");
        _authorizedAddresses[addressToRemove] = false;
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
    function processMint(
        address _to,
        bool isLegendary,
        uint256 nonce
    ) public onlyOracle whenNotPaused {
        bytes32 index = keccak256(abi.encodePacked(_to, nonce));
        require(_pendingMints[index], "No pending request for user");
        _isLegendary[nonce] = isLegendary;
        _pendingMints[index] = false;
        _safeMint(_to, nonce);
        emit MintProcessed(_to, nonce);
    }

    /**
     * @dev Mints an arbitrary NFT, ID must not exist
     */
    function specialMint(address _to, uint256 id) public onlyOwner {
        _safeMint(_to, id);
    }

    /**
     * @dev Mints an arbitrary NFT, ID must not exist
     */
    function bridgeMint(address _to, uint256 id) public onlyBridge {
        _safeMint(_to, id);
    }


    // cash out
    function withdrawOwner(address payable _to, uint256 _amount)
        public
        onlyOwner
    {
        _to.transfer(_amount);
    }

    /**
     * @dev Allows a user to request the minting of a unique waifu NFT by paying the current mint price.
     */
    function requestMint() public payable nonReentrant whenNotPaused {
        require(_amountClaim != 0, "Mint disabled");
        bytes32 index = keccak256(abi.encodePacked(msg.sender, _mintnonce));
        require(msg.value == _amountClaim, "Incorrect price");
        _pendingMints[index] = true;
        emit MintRequest(msg.sender, _mintnonce);
        _mintnonce++;
    }

    function requestExists(address user, uint256 nonce)
        external
        view
        returns (bool)
    {
        bytes32 index = keccak256(abi.encodePacked(user, nonce));
        return _pendingMints[index];
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

    /**
     * @dev EIP2985 royaltyInfo for every marketplace except OpenSea (lol..)
     * Used by NOT OpenSea
     * @param tokenId just there to conform to standard
     * @param salePrice populated by marketplace contract
     * @return receiver the address of the owner
     * @return royaltyAmount the amount of royalties
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = address(owner());
        royaltyAmount = salePrice * (_royaltyPercentage / 100);
        return (receiver, royaltyAmount);
    }

    function setRoyaltyPercentage(uint256 percent) public onlyOwner {
        _royaltyPercentage = percent;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * Override isApprovedForAll to auto-approve OS's proxy contract
     */
    function isApprovedForAll(address _address, address _operator)
        public
        view
        override(ERC721, IERC721)
        returns (bool isOperator)
    {
        // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }

        // otherwise, use the default ERC721.isApprovedForAll()
        return super.isApprovedForAll(_address, _operator);
    }
}
