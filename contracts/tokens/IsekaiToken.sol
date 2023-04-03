// SPDX-License-Identifier: UNLICENSED
/// @author Isekai Dev

pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title IsekaiToken
 * @dev A custom ERC20 token that implements a tax on transfers.
 * The tax is calculated as a percentage of the transfer amount and
 * sent to a specified tax destination address.
 * The owner of the contract can update the tax percentage and tax destination,
 * and can exclude or include specific addresses from the tax calculation.
 */
contract IsekaiToken is ERC20, Ownable, ReentrancyGuard {
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
        taxDestination = _taxDestination;
    }

    /**
     * @dev Overrides the default _transfer function in ERC20.sol to implement
     * the tax calculation. If the sender and the recipient are not excluded from the tax,
     * the tax percentage is calculated and the tax amount is transferred to the
     * tax destination address. The remaining net amount is then transferred to the recipient.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override nonReentrant {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 taxAmount = 0;
        bool isSenderContract = _isContract(sender);
        bool isRecipientContract = _isContract(recipient);

        // charge tax when address is a contract AND neither address is excluded
        if (
            !_excludedFromTax[sender] &&
            !_excludedFromTax[recipient] &&
            (isSenderContract || isRecipientContract)
        ) {
            taxAmount = (amount * taxPercentage) / 100;
        }
        uint256 netAmount = amount - taxAmount;

        if (taxAmount > 0) {
            super._transfer(sender, taxDestination, taxAmount);
        }
        super._transfer(sender, recipient, netAmount);
    }

    /**
     * @dev Checks if the address is a contract by examining the bytecode length.
     */
    function _isContract(address addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }
        return (size > 0);
    }

    /**
     * @dev Allows the contract owner to mint new tokens.
     * @param to The address receiving the newly minted tokens.
     * @param amount The number of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Updates the tax percentage. Only the owner of the contract can call this function.
     * @param newPercentage The new tax percentage to be set.
     */
    function updateTaxPercentage(uint256 newPercentage) public onlyOwner {
        require(newPercentage < 100);
        taxPercentage = newPercentage;
    }

    /**
     * @dev Updates the tax destination address. Only the owner of the contract can call this function.
     * @param newDestination The new tax destination address to be set.
     */
    function updateTaxDestination(address newDestination) public onlyOwner {
        taxDestination = newDestination;
    }

    /**
     * @dev Excludes a specific address from the tax calculation. Only the owner of the contract can call this function.
     * @param account The address to be excluded from the tax calculation.
     */
    function excludeFromTax(address account) public onlyOwner {
        _excludedFromTax[account] = true;
    }

    /**
     * @dev Includes a specific address in the tax calculation. Only the owner of the contract can call this function.
     * @param account The address to be included in the tax calculation.
     */
    function includeInTax(address account) public onlyOwner {
        _excludedFromTax[account] = false;
    }

    /**
     * @dev Checks if a specific address is excluded from the tax calculation.
     * @param account The address to be checked.
     * @return A boolean indicating if the address is excluded from the tax calculation.
     */
    function isExcludedFromTax(address account) public view returns (bool) {
        return _excludedFromTax[account];
    }
}
