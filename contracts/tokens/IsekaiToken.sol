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
 * Percentage in basis points
 */
contract IsekaiToken is ERC20, Ownable, ReentrancyGuard {
    uint256 private taxPercentage;
    address private taxDestination;
    address private taxAdmin;
    mapping(address => bool) private _excludedFromTax;
    mapping(address => bool) private _whitelistedLPs;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _initialsupply,
        uint256 _taxPercentage
    ) ERC20(name, symbol) {
        require(
            _taxPercentage <= 10000,
            "IsekaiToken: tax percentage must be between 0 and 10000 (0-100%)"
        );
        address sushiswapRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
        _whitelistedLPs[sushiswapRouter] = true;
        _excludedFromTax[msg.sender] = true;
        taxPercentage = _taxPercentage;
        taxDestination = msg.sender;
        taxAdmin = msg.sender;
        // Mint the supply to the deployer wallet, mint ability is then burnt!
        _mint(msg.sender, _initialsupply);
    }

    modifier onlyAdmin() {
        require(msg.sender == taxAdmin, "Caller is not authorized");
        _;
    }

    /**
     * @dev Overrides the default _transfer function in ERC20.sol to implement
     * the tax calculation. If the sender and the recipient are not excluded from the tax,
     * the tax percentage is calculated and the tax amount is transferred to the
     * tax destination address. The remaining net amount is then transferred to the recipient.
     * If both wallets are EOA's bypass the tax.
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
            !_whitelistedLPs[recipient] &&
            (isSenderContract || isRecipientContract)
        ) {
            taxAmount = (amount * taxPercentage) / 10000;
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

    function manageWhitelistedLP(address addr, bool addTrue) public onlyAdmin {
        if (addTrue) {
            _whitelistedLPs[addr] = true;
        } else {
            _whitelistedLPs[addr] = false;
        }
    }

    /**
     * @dev Updates the tax percentage. Tax can only be lowered, never raised.
     * @param newPercentage The new tax percentage to be set.
     */
    function uTP(uint256 newPercentage) public onlyAdmin {
        require(newPercentage < taxPercentage, "Tax can only be lowered");
        taxPercentage = newPercentage;
    }

    /**
     * @dev Updates the tax destination address. Only the owner of the contract can call this function.
     * @param newDestination The new tax destination address to be set.
     */
    function uTD(address newDestination) public onlyAdmin {
        require(newDestination != address(0), "Bad address");
        taxDestination = newDestination;
    }

    /**
     * @dev Include or exclude a specific address from the tax calculation.
     * @param account The address to be included/excluded from the tax calculation.
     */
    function manageTaxExclusion(address account, bool state) public onlyAdmin {
        _excludedFromTax[account] = state;
    }
}
