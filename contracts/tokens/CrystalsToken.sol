// SPDX-License-Identifier: UNLICENSED
// @author Isekai Dev
pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Crystals
 * @dev ERC20 token to reward LP farmers with seasonal waifus, untradable and unapprovable.
 * The only way to obtain it is through the LP Rewarder contract.
 * Utility: minting seasonal waifus and future use.
 */
contract CrystalsToken is ERC20, Ownable {
    address public lpRewarder;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /**
     * @dev Set the address of the LP Rewarder contract. Can only be called once.
     * @param _lpRewarder The address of the LP Rewarder contract.
     */
    function setLPRewarder(address _lpRewarder) external onlyOwner {
        require(lpRewarder == address(0), "LPRewarder address already set");
        lpRewarder = _lpRewarder;
    }


    /**
     * @dev Mint new Crystals tokens to the specified address. Can only
     * be called by the LP Rewarder contract.
     * @param to The address to mint the new tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == lpRewarder, "Only LPRewarder can mint");
        _mint(to, amount);
    }

    /**
     * @dev Burn Crystals tokens from the specified address.
     * @param from The address to burn the tokens from.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /**
     * @dev Override the _transfer function from ERC20. Disallow all transfers.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        revert("Transfers not allowed");
    }

    /**
     * @dev Override the _approve function from ERC20. Disallow all approvals.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual override {
        revert("Approvals not allowed");
    }
}