// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "src/interfaces/ICState.sol";
import "src/interfaces/ISet.sol";

/**
 * @dev Interface for interacting with the Cozy protocol Manager. This is not a comprehensive
 * interface, and only contains the methods needed by triggers.
 */
interface IManager is ICState {
  // Information on a given set.
  struct SetData {
    // When a set is created, this is updated to true.
    bool exists;
     // If true, this set can use funds from the backstop.
    bool approved;
    // Earliest timestamp at which finalizeUpdateConfigs can be called to apply config updates queued by updateConfigs.
    uint64 configUpdateTime;
    // Maps from set address to the latest timestamp after configUpdateTime at which finalizeUpdateConfigs can be
    // called to apply config updates queued by updateConfigs. After this timestamp, the queued config updates
    // expire and can no longer be applied.
    uint64 configUpdateDeadline;
  }

  function sets(ISet set) external returns (SetData memory);
  function updateMarketState(ISet set, CState newMarketState) external;
}
