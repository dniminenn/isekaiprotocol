// SPDX-License-Identifier: unlicensed
// @author Isekai Dev
pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "contracts/tokens/ICrystalsToken.sol";

/**
 * @title SeasonalWaifu
 * @dev This contract represents an ERC1155 token contract.
 * Allows users to request and mint new tokens by sending MATIC.
 * Allows users to mint using crystals, which are emitted from the LPRewarder
 * Tokens are minted by an oracle that verifies the payment and processes the minting request.
 * The contract also allows the owner to update the token price and set the base URI for all token IDs.
 */
contract SeasonalWaifu is ERC1155, Ownable {
    using Strings for uint256;

    uint256 private _lastProcessedNonce;
    mapping(uint256 => bool) private _processedNonces;
    uint256 public tokenPrice;
    string private baseURI;
    address private _oracleAddress;
    ICrystalsToken private crystals;

    // for oracle use
    event MintRequest(address indexed user, uint256 nonce, uint256 crystals);
    // to update user dapp
    event MintProcessed(address indexed user, uint256 tokenId, uint256 nonce);

    constructor(uint256 _tokenPrice, string memory _baseURI, address _crystals) ERC1155("") {
        tokenPrice = _tokenPrice; // Price MATIC wei
        _lastProcessedNonce = 0;
        baseURI = _baseURI;
        crystals = ICrystalsToken(_crystals);
    }

    modifier onlyOracle() {
        require(
            msg.sender == _oracleAddress,
            "Only the oracle can call this function."
        );
        _;
    }

    function setOracleAddress(address oracle) public onlyOwner {
        _oracleAddress = oracle;
    }

    /**
     * @dev Allows a user to request a new token
     * Emits a `MintRequest` event indicating that a new token has been requested.
     * @dev Requires the user to send an amount of MATIC equal to the current token price.
     * @dev Throws an error if the nonce has already been processed.
     */
    function requestMint() public payable {
        require(msg.value == tokenPrice, "Insufficient MATIC sent");

        uint256 nonce = _lastProcessedNonce + 1;
        require(!_processedNonces[nonce], "Already processed");
        _lastProcessedNonce = nonce;
        emit MintRequest(msg.sender, nonce, 0);
    }

    /**
     * @dev Allows a user to request a new token
     * Emits a `MintRequest` event indicating that a new token has been requested.
     * @dev Requires the user to burn 1 crystal. No approval required ;)
     * @dev Throws an error if the nonce has already been processed.
     */
    function requestMintCrystals() public {
        uint256 nonce = _lastProcessedNonce + 1;
        require(crystals.balanceOf(msg.sender) >= 1, "Not enough $CRYSTALS");
        require(!_processedNonces[nonce], "Already processed");

        crystals.burn(msg.sender, 1);

        // We should tell our Oracle that we are using crystals
        // for better odds...
        emit MintRequest(msg.sender, nonce, 1);
    }

    /**
     * @dev Mints a new token and assigns it to the specified user.
     * @param user The address of the user to whom the token should be assigned.
     * @param id The ID of the token to mint.
     * @param amount The amount of tokens to mint.
     * @param nonce The nonce of the request to mint a new token.
     * @param data Additional data to include in the minting transaction.
     * @dev Throws an error if the nonce has already been processed.
     * Emits a `MintProcessed` event indicating that a new token has been minted and assigned to the specified user.
     */
    function mint(
        address user,
        uint256 id,
        uint256 amount,
        uint256 nonce,
        bytes memory data
    ) external onlyOracle {
        require(!_processedNonces[nonce], "Already processed");
        require(id <= 11); // 12 varieties
        _processedNonces[nonce] = true;
        _mint(user, id, 1, data); // always one... add foil pak functionality!
        emit MintProcessed(user, id, nonce);
    }

    /**
     * @dev Returns the last processed nonce.
     * @return uint256 representing the last processed nonce.
     */
    function lastProcessedNonce() public view returns (uint256) {
        return _lastProcessedNonce;
    }

    /**
     * @dev Updates the price of the tokens.
     * @param newPrice The new price of the tokens.
     */
    function updateTokenPrice(uint256 newPrice) public onlyOwner {
        tokenPrice = newPrice;
    }

    /**
     * @dev Sets the base URI for all token IDs.
     * @param _baseURI The new base URI to set.
     */
    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @dev Returns an URI for a given token ID.
     * @param tokenId uint256 ID of the token to query.
     * @return string containing the URI for the given token ID.
     */
    function uri(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }
}
