// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IsekaiSeason is ERC1155, Ownable {
    uint256 private _lastProcessedNonce;
    mapping(uint256 => bool) private _processedNonces;
    IERC20 public paymentToken;
    uint256 public tokenPrice;

    // for oracle use
    event MintRequest(address indexed user, uint256 nonce);
    // to update user dapp
    event MintProcessed(address indexed user, uint256 tokenId, uint256 nonce);

    constructor(IERC20 _paymentToken, uint256 _tokenPrice) ERC1155("https://api.example.com/token/{id}.json") {
        paymentToken = _paymentToken; // $ISEKAI token
        tokenPrice = _tokenPrice; // Price in $ISEKAI wei
        _lastProcessedNonce = 0;
    }

    function requestMint() public {
        // Transfer payment from the user
        require(paymentToken.transferFrom(_msgSender(), address(this), tokenPrice), "Payment failed");

        uint256 nonce = _lastProcessedNonce + 1;
        require(!_processedNonces[nonce], "Already processed");
        _lastProcessedNonce = nonce;
        emit MintRequest(_msgSender(), nonce);
    }

    // This will be called by our Oracle
    // upon receiving the MintRequest event
    function mint(address user, uint256 id, uint256 amount, uint256 nonce, bytes memory data) external onlyOwner {
        require(!_processedNonces[nonce], "Already processed");
        _processedNonces[nonce] = true;
        _mint(user, id, amount, data);
        emit MintProcessed(user, id, nonce);
    }

    // To bootstrap the oracle and to prevent double mints
    function lastProcessedNonce() public view returns (uint256) {
        return _lastProcessedNonce;
    }

    function updateTokenPrice(uint256 newPrice) public onlyOwner {
        tokenPrice = newPrice;
    }
}