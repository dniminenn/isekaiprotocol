// SPDX-License-Identifier: Unlicensed
// @author Isekai Dev

pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./erc721a/ERC721A.sol";

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

    function setOracleAddress(address oracle) public onlyOwner {
        _oracleAddress = oracle;
    }

    // override the first token id to 1 instead of 0
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function setLegendary(uint256 id) internal {
        _isLegendary[id] = true;
    }

    function getLegendary(uint256 id) public view returns (bool) {
        return _isLegendary[id];
    }

    // set mint price after deploy, or change anytime
    function setClaim(uint256 _amount) public onlyOwner {
        _amountClaim = _amount;
    }

    // mint single nft to wallet
    function processMint(address _to, bool isLegendary) public onlyOracle {
        _safeMint(_to, 1);
        uint256 currentid = totalSupply() + 1;
        if (isLegendary) setLegendary(currentid);
    }

    // cash out
    function withdraw(address payable _to, uint256 _amount) public onlyOwner {
        _to.transfer(_amount);
    }

    // public mint
    function requestMint() public payable {
        require(msg.value == _amountClaim, "Incorrect price");
        // implement Event for requesting oracle
    }

    // used by tokenURI to return metadata uri
    function baseTokenURI() public view returns (string memory) {
        return _baseUrl;
    }

    // use this to change metadata location, ie. from http to ipfs upon mint out
    function updateBase(string memory newBase) public onlyOwner {
        _baseUrl = newBase;
    }

    // return location of nft metadata
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

    // used by opensea to preload collection info
    function contractURI() public view returns (string memory) {
        return _contractUrl;
    }
}
