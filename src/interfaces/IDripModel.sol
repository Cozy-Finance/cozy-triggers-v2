// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/**
 * @dev Interface that all drip models must conform to.
 */
interface IDripModel {
  /// @notice Returns the percentage of the fee pool that should be dripped to suppliers, per second, as a wad.
  /// @dev The returned value is not equivalent to the annual yield earned by suppliers. Annual yield can be
  /// computed as supplierFeePool * dripRate * secondsPerYear / totalAssets.
  /// @param utilization Current utilization of the set.
  function dripRate(uint256 utilization) external view returns (uint256);
}
