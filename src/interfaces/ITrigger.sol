// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/ITriggerEvents.sol";

/**
 * @dev The minimal functions a trigger must implement to work with the Cozy protocol.
 */
interface ITrigger is ITriggerEvents {
  /// @notice The current trigger state. This should never return PAUSED.
  function state() external returns (CState);

  /// @notice Called by the Manager to add a newly created set to the trigger's list of sets.
  function addSet(ISet set) external returns (bool);

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger state.
  function acknowledged() external returns (bool);
}
