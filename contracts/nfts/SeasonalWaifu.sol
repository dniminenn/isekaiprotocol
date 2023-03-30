// SPDX-License-Identifier: unlicensed
// @author Isekai Dev

pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "contracts/tokens/ICrystalsToken.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SeasonalWaifu
 * @dev This contract represents an ERC1155 token contract.
 * Allows users to request and mint new tokens by sending MATIC.
 * Allows users to mint using crystals, which are emitted from the LPRewarder
 * Tokens are minted by an oracle that verifies the payment and processes the minting request.
 * The contract also allows the owner to update the token price and set the base URI for all token IDs.
 */
contract SeasonalWaifu is ERC1155, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;

    uint256 _mintnonce;
    mapping(bytes32 => bool) private _pendingMints;
    uint256 public tokenPrice;
    string private baseURI;
    address private _oracleAddress;
    ICrystalsToken private crystals;
    bool autobuy;

    IUniswapV2Router02 public uniswapRouter;
    // Our DEX
    address public isekaiAddress;
    address private uniswapRouterAddress;

    mapping(address => bool) private _authorizedAddresses;

    // for oracle use
    event MintRequest(
        address indexed user,
        uint256 nonce,
        uint256 crystals,
        uint256 amount
    );
    // to update user dapp
    event MintProcessed(
        address indexed user,
        uint256[] tokenIds,
        uint256 nonce
    );

    uint256 constant VARIETIES = 12;
    uint256 constant ETH = 0;
    uint256 constant CRYSTALS = 1;
    uint256 foildiscount;

    uint256 royaltyPercentage;

    string public name = "Isekai Legends Season";
    string public symbol = "ISEKAI";

    constructor(
        uint256 _tokenPrice,
        string memory _baseURI,
        address _crystals,
        address _uniswapRouterAddress,
        address _isekaiAddress,
        uint256 season
    ) ERC1155("") {
        tokenPrice = _tokenPrice; // Price MATIC wei
        baseURI = _baseURI;
        crystals = ICrystalsToken(_crystals);
        uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
        isekaiAddress = _isekaiAddress;
        foildiscount = 0;
        royaltyPercentage = 5;
        // Returns Isekai Legends Season 0
        // and that will be the name displayed on block explorer
        name = string(abi.encodePacked(name, " ", season.toString()));
        pause();
    }

    modifier onlyOracle() {
        require(
            msg.sender == _oracleAddress,
            "Only the oracle can call this function."
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

    function setOracleAddress(address oracle) public onlyOwner {
        _oracleAddress = oracle;
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
     * @dev Allows a user to request a new token
     * @param foilpack Set true if user wants to buy a foilpack
     * Emits a `MintRequest` event indicating that a new token has been requested.
     * @dev Requires the user to send an amount of MATIC equal to the current token price.
     * @dev Throws an error if the nonce has already been processed.
     */
    function requestMint(bool foilpack) public payable whenNotPaused nonReentrant {
        uint256 price = tokenPrice;
        uint256 amount = 1;
        if (foilpack) {
            price *= ((100 - foildiscount) / 100);
            amount = 10;
        }
        require(msg.value == price, "Insufficient MATIC sent");

        emit MintRequest(msg.sender, _mintnonce, ETH, amount);
        bytes32 index = keccak256(abi.encodePacked(msg.sender,_mintnonce));
        _pendingMints[index] = true;
        _mintnonce++;

        if (autobuy) {
            address[] memory path = new address[](2);
            path[0] = uniswapRouter.WETH();
            path[1] = isekaiAddress;
            uniswapRouter.swapExactETHForTokens{value: msg.value}(
                0, // Accept any amount of tokens
                path,
                address(owner()), // Recipient of the tokens
                block.timestamp + 300 // Deadline (5 minutes)
            );
        }
    }

    /**
     * @dev Allow owner to disable autobuy functionality
     * @param _autobuy true or false
     */
    function setAutoBuy(bool _autobuy) public onlyOwner {
        autobuy = _autobuy;
    }

    /**
     * @dev Allows owner to set new DEX for autobuy
     * @param _router New router address
     */
    function setDEXRouter(address _router) public onlyOwner {
        uniswapRouter = IUniswapV2Router02(_router);
    }

    /**
     * @dev Allows a user to request news token
     * Emits a `MintRequest` event indicating that a new token has been requested.
     * @dev Requires the user to burn amount X crystal. No approval required ;)
     * @dev Throws an error if the nonce has already been processed.
     */
    function requestMintCrystals(uint256 amount) public whenNotPaused nonReentrant {
        uint256 crystalprice = amount * (10**18); // lets burn whole tokens lol
        require(
            crystals.balanceOf(msg.sender) >= crystalprice,
            "Not enough $CRYSTALS"
        );
        
        bytes32 index = keccak256(abi.encodePacked(msg.sender, _mintnonce));
        _pendingMints[index] = true;

        crystals.burn(msg.sender, crystalprice);

        // We should tell our Oracle that we are using crystals
        // for better odds...
        emit MintRequest(msg.sender, _mintnonce, CRYSTALS, amount);

        _mintnonce++;
    }

    /**
     * @dev Allows owner to set discount for foil packs
     *
     */
    function setFoilpackDiscount(uint256 _discount) public onlyOwner {
        foildiscount = _discount;
    }

    /**
     * @dev Mints either 1 or 10 new token and assigns it to the specified user.
     * @param user The address of the user to whom the token should be assigned.
     * @param ids[] Array with the IDs of the token to mint.
     * @param nonce The nonce of the request to mint a new token.
     * @dev Throws an error if the nonce has already been processed.
     * Emits a `MintProcessed` event indicating that a new token has been minted and assigned to the specified user.
     */
    function mint(
        address user,
        uint256[] memory ids,
        uint256 nonce
    ) external onlyOracle {
        bytes32 index = keccak256(abi.encodePacked(user,nonce));
        require(_pendingMints[index], "No pending request by this user");
        for (uint256 i = 0; i < ids.length; i++) {
            require(ids[i] < VARIETIES, "ID out of range");
            _mint(user, ids[i], 1, "");
        }
        _pendingMints[index] = false;
        emit MintProcessed(user, ids, nonce);
    }

    function requestExists(address user, uint256 nonce)  external view returns(bool) {
        bytes32 index = keccak256(abi.encodePacked(user,nonce));
        return _pendingMints[index];
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

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = address(owner());
        royaltyAmount = salePrice * (royaltyPercentage / 100);
        return (receiver, royaltyAmount);
    }

    function setRoyaltyPercentage(uint256 percent) public onlyOwner {
        royaltyPercentage = percent;
    }

    function withdrawOwner(address payable _to, uint256 _amount)
        public
        onlyOwner
    {
        _to.transfer(_amount);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * Override isApprovedForAll to auto-approve OS's proxy contract
     */
    function isApprovedForAll(address _address, address _operator)
        public
        view
        override
        returns (bool isOperator)
    {
        // if OpenSea's ERC1155 Proxy Address is detected, auto-return true
        if (_operator == address(0x207Fa8Df3a17D96Ca7EA4f2893fcdCb78a304101)) {
            return true;
        }
        // otherwise, use the default ERC1155.isApprovedForAll()
        return super.isApprovedForAll(_address, _operator);
    }
}
