// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

/**
 * @dev Interface for interacting with Cozy protocol Sets. This is not a comprehensive
 * interface, and only contains the methods needed by triggers.
 */
interface ISet {
  function setOwner(address set) external view returns (address);
  function owner() external view returns (address);
}
