// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/**
 * @notice Receives updates from L1 on the canonical rETH exchange rate
 */
interface IRocketPoolOVMPriceOracle {
  /// @notice The timestamp of the block in which the rate was last updated
  function lastUpdated() external view returns (uint256);

  /// @dev The rETH exchange rate in the form of how much ETH 1 rETH is worth
  function rate() external view returns (uint256);
}
