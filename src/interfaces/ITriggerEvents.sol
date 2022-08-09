// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/ICState.sol";
import "src/interfaces/ISet.sol";

/**
 * @dev Events that may be emitted by a trigger. Only `TriggerStateUpdated` is required.
 */
interface ITriggerEvents is ICState {
  /// @dev Emitted when a new set is added to the trigger's list of sets.
  event SetAdded(ISet set);

  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(CState indexed state);
}
