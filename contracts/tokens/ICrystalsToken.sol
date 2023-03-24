// SPDX-License-Identifier: UNLICENSED
// @author Isekai Dev

pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ICrystalsToken
 * @notice Interface for querying the `minting` and `burning` Crystals.
 */
interface ICrystalsToken is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
