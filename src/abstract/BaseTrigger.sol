// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "cozy-v2-interfaces/interfaces/IBaseTrigger.sol";

/**
 * @dev Core trigger interface and implementation. All triggers should inherit from this to ensure they conform
 * to the required trigger interface.
 */
abstract contract BaseTrigger is ICState, IBaseTrigger {
  /// @notice Current trigger state.
  CState public state;

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve a specific Set.
  ISet[] public sets;

  /// @notice Prevent DOS attacks by limiting the number of sets.
  uint256 public constant MAX_SET_LENGTH = 25;

  /// @notice The manager of the Cozy protocol.
  IManager public immutable manager;

  /// @dev Thrown when a state update results in an invalid state transition.
  error InvalidStateTransition();

  /// @dev Thrown when trying to add a set to the `sets` array when it's length is already at `MAX_SET_LENGTH`.
  error SetLimitReached();

  /// @dev Thrown when trying to add a set to the `sets` array when the trigger has not been acknowledged.
  error Unacknowledged();

  /// @dev Thrown when the caller is not authorized to perform the action.
  error Unauthorized();

  /// @param _manager The manager of the Cozy protocol.
  constructor(IManager _manager) {
    manager = _manager;
  }

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger state.
  /// @dev This must be implemented by contracts that inherit this contract. For manual triggers, after the trigger is deployed
  /// this should initially return false, and instead return true once the entity responsible for transitioning trigger state
  /// acknowledges the trigger. For programmatic triggers, this should always return true.
  function acknowledged() public virtual returns (bool);

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve all Sets.
  function getSets() public view returns(ISet[] memory) {
    return sets;
  }

  /// @notice The number of Sets that use this trigger in a market.
  function getSetsLength() public view returns(uint256) {
    return sets.length;
  }

  /// @dev Call this method to update Set addresses after deploy. Returns false if the trigger has not been acknowledged.
  function addSet(ISet _set) external returns (bool) {
    if (msg.sender != address(manager)) revert Unauthorized();
    if (!acknowledged()) revert Unacknowledged();
    (bool _exists,,,) = manager.sets(_set);
    if (!_exists) revert Unauthorized();

    uint256 setLength = sets.length;
    if (setLength >= MAX_SET_LENGTH) revert SetLimitReached();
    for (uint256 i = 0; i < setLength; i = uncheckedIncrement(i)) {
      if (sets[i] == _set) return true;
    }
    sets.push(_set);
    emit SetAdded(_set);
    return true;
  }

  /// @dev Child contracts should use this function to handle Trigger state transitions.
  function _updateTriggerState(CState _newState) internal returns (CState) {
    if (!_isValidTriggerStateTransition(state, _newState)) revert InvalidStateTransition();
    state = _newState;
    uint256 setLength = sets.length;
    for (uint256 i = 0; i < setLength; i = uncheckedIncrement(i)) {
      manager.updateMarketState(sets[i], _newState);
    }
    emit TriggerStateUpdated(_newState);
    return _newState;
  }

  /// @dev Reimplement this function if different state transitions are needed.
  function _isValidTriggerStateTransition(CState _oldState, CState _newState) internal virtual returns(bool) {
    // | From / To | ACTIVE      | FROZEN      | PAUSED   | TRIGGERED |
    // | --------- | ----------- | ----------- | -------- | --------- |
    // | ACTIVE    | -           | true        | false    | true      |
    // | FROZEN    | true        | -           | false    | true      |
    // | PAUSED    | false       | false       | -        | false     | <-- PAUSED is a set-level state, triggers cannot be paused
    // | TRIGGERED | false       | false       | false    | -         | <-- TRIGGERED is a terminal state

    if (_oldState == CState.TRIGGERED) return false;
    if (_oldState == _newState) return true; // If oldState == newState, return true since the Manager will convert that into a no-op.
    if (_oldState == CState.ACTIVE && _newState == CState.FROZEN) return true;
    if (_oldState == CState.FROZEN && _newState == CState.ACTIVE) return true;
    if (_oldState == CState.ACTIVE && _newState == CState.TRIGGERED) return true;
    if (_oldState == CState.FROZEN && _newState == CState.TRIGGERED) return true;
    return false;
  }

  /// @dev Unchecked increment of the provided value. Realistically it's impossible to overflow a
  /// uint256 so this is always safe.
  function uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked { return i + 1; }
  }
}
