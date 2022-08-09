// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "src/abstract/BaseTrigger.sol";
import "src/interfaces/IManager.sol";
import "src/interfaces/ISet.sol";

contract MinimalTrigger is BaseTrigger {
  constructor(IManager _manager, ISet[] memory _sets) BaseTrigger(_manager) {
    sets = _sets;
    state = CState.ACTIVE;
  }

  function TEST_HOOK_updateTriggerState(CState _newState) public {
    _updateTriggerState(_newState);
  }

  function TEST_HOOK_isValidTriggerStateTransition(
    CState _oldState,
    CState _newState
  ) public returns(bool) {
    return _isValidTriggerStateTransition(_oldState, _newState);
  }
}
