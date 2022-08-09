// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/**
 * @dev Interface that all decay models must conform to.
 */
interface IDecayModel {
  /// @notice Returns current decay rate of PToken value, as percent per second, where the percent is a wad.
  /// @param utilization Current utilization of the market.
  function decayRate(uint256 utilization) external view returns (uint256);
}
