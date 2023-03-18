// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IsekaiToken is ERC20, Ownable {
    uint256 public taxPercentage;
    address public taxDestination;
    mapping(address => bool) private _excludedFromTax;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _taxPercentage,
        address _taxDestination
    ) ERC20(name, symbol) {
        taxPercentage = _taxPercentage;
        taxDestination = _taxDestination; // our waifu staking contract
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 taxAmount = 0;
        if (!_excludedFromTax[sender] && !_excludedFromTax[recipient]) {
            taxAmount = (amount * taxPercentage) / 100;
        }
        uint256 netAmount = amount - taxAmount;

        if (taxAmount > 0) {
            super._transfer(sender, taxDestination, taxAmount);
        }
        super._transfer(sender, recipient, netAmount);
    }

    function updateTaxPercentage(uint256 newPercentage) public onlyOwner {
        require(newPercentage < 100);
        taxPercentage = newPercentage;
    }

    function updateTaxDestination(address newDestination) public onlyOwner {
        taxDestination = newDestination;
    }

    function excludeFromTax(address account) public onlyOwner {
        _excludedFromTax[account] = true;
    }

    function includeInTax(address account) public onlyOwner {
        _excludedFromTax[account] = false;
    }

    function isExcludedFromTax(address account) public view returns (bool) {
        return _excludedFromTax[account];
    }
}
