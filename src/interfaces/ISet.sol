// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {MarketState} from "src/structs/StateEnums.sol";
/**
 * @notice All protection markets live within a set.
 */

interface ISet {
  /// @notice Called by a trigger when it's state changes to `newMarketState_` to execute the state
  /// change in the corresponding market.
  function updateMarketState(MarketState newMarketState_) external;
}
