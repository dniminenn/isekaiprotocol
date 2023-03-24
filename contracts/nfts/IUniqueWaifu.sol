// SPDX-License-Identifier: UNLICENSED
// @author Isekai Dev

pragma solidity ^0.8.0 .0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title IUniqueWaifu
 * @notice Interface for querying the `legendary` status of a token without being able to modify the contract state.
 */
interface IUniqueWaifu is IERC721 {
    function getLegendary(uint256 id) external view returns (bool);
}
