// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "src/abstract/BaseTrigger.sol";
import "src/interfaces/IManager.sol";
import "src/interfaces/ISet.sol";

/**
 * @notice A trigger template offering various possible implementations.
 *
 * @dev
 * MECHANICS
 * The Trigger and Manager know about each other. Whenever the trigger's state changes, it calls
 * Manager.updateMarketState(_state) so the Market is immediately aware of the state update.
 *
 * DESIGN SPACE
 * This trigger is a recommended contract template, but there is no way to enforce that all triggers
 * confirm to this spec. The only true requirement of the trigger is that any state change calls
 * Manager.updateMarketState(_state) to update the Market of the new trigger state, with _state being
 * an enum of { ACTIVE, FROZEN, TRIGGERED }
 *
 * This template provides four parameters that trigger developers can use to customize the behavior
 * of the trigger. These parameters are:
 *
 *   freezers:          A list of addresses that are allowed to change state from ACTIVE to FROZEN
 *   boss:              A single address that is allowed to change state from ACTIVE to FROZEN, and
 *                      also has permission to unfreeze the trigger, i.e. transition from FROZEN to
 *                      ACTIVE or TRIGGERED
 *   programmaticCheck: A method that implements atomic, on-chain logic to determine if a trigger
 *                      condition has occurred
 *   isAutoTrigger:     If true, and if a programmaticCheck is present, the trigger will transition
 *                      to TRIGGERED when the programmaticCheck's condition was met. If false, the
 *                      trigger will transition to FROZEN when the programmaticCheck condition is met
 *
 * This results in 16 possible trigger configurations. Some of these configurations are invalid, and
 * some are effectively identical to one another. The table below documents these configurations.
 * Because the core protocol has no way of enforcing that triggers are legitimate, we do not
 * attempt to detect invalid configurations in the constructor, since not all invalid
 * configurations are even detectable on-chain.
 *
 * Another property of this template is that the freezers and boss roles are immutable, i.e. they
 * cannot be changed after deployment. This is recommended because these roles, especially the
 * boss, have a lot of power, and having to monitor the trigger contract for address changes (e.g.
 * from a multisig or DAO to an EOA) adds overhead and risk for protection seekers. However, this
 * immutability is not enforced by the core protocol, so it is ultimately up to the trigger
 * developer to decide whether roles should be immutable or not.
 *
 * CONFIGURATIONS
 * +-------------------------------------------------+------------------------------------------------------------------------------+
 * | freezers  boss    programmaticCheck  autoToggle | result                                                                       |
 * +-------------------------------------------------+------------------------------------------------------------------------------+
 * | none      False   no-op              False      | invalid: never toggles                                                       |
 * | none      False   no-op              True       | invalid: never toggles                                                       |
 * | none      False   has logic          False      | invalid: stuck after transition to frozen                                    |
 * | none      False   has logic          True       | valid:   pure programmatic trigger                                           |
 * +-------------------------------------------------+------------------------------------------------------------------------------+
 * | none      True    no-op              False      | valid:   boss can freeze, boss can unfreeze                                  |
 * | none      True    no-op              True       | valid:   boss can freeze, boss can unfreeze                                  |
 * | none      True    has logic          False      | valid:   boss can freeze, boss can unfreeze, programmatic can freeze         |
 * | none      True    has logic          True       | valid:   boss can freeze, boss can unfreeze, programmatic can trigger        |
 * +-------------------------------------------------+------------------------------------------------------------------------------+
 * | 1+        False   no-op              False      | invalid: never toggles                                                       |
 * | 1+        False   no-op              True       | invalid: never toggles                                                       |
 * | 1+        False   has logic          False      | invalid: stuck after transition to frozen                                    |
 * | 1+        False   has logic          True       | valid:   pure programmatic trigger                                           |
 * +-------------------------------------------------+------------------------------------------------------------------------------+
 * | 1+        True    no-op              False      | valid:   boss can freeze, boss/freezer can unfreeze                          |
 * | 1+        True    no-op              True       | valid:   boss can freeze, boss/freezer can unfreeze                          |
 * | 1+        True    has logic          False      | valid:   boss/programmatic can freeze, boss/freezer can unfreeze             |
 * | 1+        True    has logic          True       | valid:   boss can freeze, boss/freezer can unfreeze, programmatic can toggle |
 * +-------------------------------------------------+------------------------------------------------------------------------------+
 */
contract FlexibleTrigger is BaseTrigger {
  /// @notice Maximum amount of time that the trigger state can be FROZEN, in seconds. If the trigger state is
  /// FROZEN for a duration that exceeds maxFreezeDuration, the trigger state transitions to TRIGGERED.
  uint256 public immutable maxFreezeDuration;

  /// @notice Timestamp that the trigger entered the FROZEN state, if FROZEN. 0 if not FROZEN.
  uint256 public freezeTime;

  /// @notice Address with permission to (1) transition the trigger state from ACTIVE to FROZEN,
  /// and (2) unfreeze the trigger, i.e. transition from FROZEN to ACTIVE or TRIGGERED.
  address public immutable boss;

  /// @notice If true, a programmatic check automatically flips state from ACTIVE to TRIGGERED.
  /// If false, a programmatic check automatically flips state from ACTIVE to FROZEN.
  bool public isAutoTrigger;

  bool internal isAcknowledged;

  /// @notice Addresses with permission to transition the trigger state from ACTIVE to FROZEN.
  mapping(address => bool) public freezers;

  /// @dev Emitted when a new freezer is added to the trigger's list of allowed freezers.
  event FreezerAdded(address freezer);

  /// @param _manager The manager of the Cozy protocol.
  /// @param _boss Address with permission to (1) transition the trigger state from ACTIVE to FROZEN,
  /// and (2) unfreeze the trigger, i.e. transition from FROZEN to ACTIVE or TRIGGERED.
  /// @param _freezers Addresses with permission to transition the trigger state from ACTIVE to FROZEN.
  /// @param _isAutoTrigger If true, a programmatic check automatically flips state from ACTIVE to TRIGGERED.
  /// If false, a programmatic check automatically flips state from ACTIVE to FROZEN.
  /// @param _maxFreezeDuration Maximum amount of time that the trigger state can be FROZEN, in seconds. If the trigger
  /// state is FROZEN for a duration that exceeds maxFreezeDuration, the trigger state transitions to TRIGGERED.
  constructor(
    IManager _manager,
    address _boss,
    address[] memory _freezers,
    bool _isAutoTrigger,
    uint256 _maxFreezeDuration
  ) BaseTrigger(_manager) {
    boss = _boss;
    maxFreezeDuration = _maxFreezeDuration;
    isAutoTrigger = _isAutoTrigger;
    state = CState.ACTIVE;

    uint256 _lenFreezers = _freezers.length; // Cache to avoid MLOAD on each loop iteration.
    for (uint256 i = 0; i < _lenFreezers;) {
      freezers[_freezers[i]] = true;
      emit FreezerAdded(_freezers[i]);
      unchecked { i++; }
    }
  }

  function acknowledge() external {
    if (msg.sender != boss) revert Unauthorized();
    isAcknowledged = true;
  }

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger state.
  /// @dev This trigger has a boss role that can freeze and unfreeze the trigger, so it requires acknowledgement.
  function acknowledged() public view override returns (bool) {
    return isAcknowledged;
  }

  /// @notice Transitions the trigger state from ACTIVE to FROZEN.
  function freeze() external {
    if (!freezers[msg.sender] && msg.sender != boss) revert Unauthorized();
    if (state != CState.ACTIVE) revert InvalidStateTransition();
    _updateTriggerState(CState.FROZEN);
    freezeTime = block.timestamp;
  }

  /// @notice Transitions the trigger state from FROZEN to ACTIVE.
  /// @dev We use a special method, instead of taking a `newState` input, to minimize the chance of
  /// the caller passing in the wrong `CState` value.
  function resume() external {
    if (msg.sender != boss) revert Unauthorized();
    if (state != CState.FROZEN) revert InvalidStateTransition();
    _updateTriggerState(CState.ACTIVE);
    freezeTime = 0;
  }

  /// @notice Transitions the trigger state from FROZEN to TRIGGERED
  /// @dev We use a special method, instead of taking a `newState` input, to minimize the chance of
  /// the caller passing in the wrong `CState` value.
  function trigger() external {
    if (msg.sender != boss) revert Unauthorized();
    _trigger();
  }

  /// @notice Callable by anyone, used to transition the trigger state from FROZEN to TRIGGERED
  /// if the trigger is currently FROZEN and has been FROZEN for longer than maxFreezeDuration.
  function publicTrigger() external {
    if (freezeTime + maxFreezeDuration >= block.timestamp) revert InvalidStateTransition();
    _trigger();
  }

  /// @notice If `programmaticCheck()` is defined, this method executes the check and makes the
  /// required state changes both in the trigger and the sets. This method will automatically
  /// transition the trigger state to TRIGGERED when `isAutoTrigger` is true, and transition it to
  /// FROZEN when `isAutoTrigger` is false.
  function runProgrammaticCheck() external returns (CState) {
    // Rather than revert if not active, we simply return the state and exit. Both behaviors are
    // acceptable, but returning is friendlier to the caller as they don't need to handle a revert
    // and can simply parse the transaction's logs to know if the call resulted in a state change.
    if (state != CState.ACTIVE) return state;

    bool _wasConditionMet = programmaticCheck();

    // If programmatic condition was not met, state does not change and we return current state.
    if (!_wasConditionMet) return state;

    // Otherwise, we toggle state accordingly.
    CState _newState = isAutoTrigger ? CState.TRIGGERED : CState.FROZEN;
    if (_newState == CState.FROZEN) freezeTime = block.timestamp;
    _updateTriggerState(_newState);

    return state;
  }

  /// @notice Executes logic to programmatically determine if the trigger should be toggled.
  /// @dev If a programmatic check is desired, override this function.
  function programmaticCheck() internal virtual returns (bool) {
    return false;
  }

  /// @notice Executes logic to transition the trigger into the triggered state if the trigger is currently frozen.
  function _trigger() internal {
    if (state != CState.FROZEN) revert InvalidStateTransition();
    _updateTriggerState(CState.TRIGGERED);
    freezeTime = 0;
  }
}
