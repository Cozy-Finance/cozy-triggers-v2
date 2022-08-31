// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "test/utils/MinimalTrigger.sol";
import "test/utils/TriggerTestSetup.sol";

contract BaseTriggerCoreTest is TriggerTestSetup, ITriggerEvents {
  MinimalTrigger trigger;

  function setUp() public override {
    super.setUp();
    ISet[] memory _triggerSets = new ISet[](1);
    _triggerSets[0] = set;
    trigger = new MinimalTrigger(manager, _triggerSets);
    trigger.TEST_HOOK_acknowledge(true);
  }

  function test_AddSetRevertsIfNotCalledFromManagerOrSet() public {
    address _caller = makeAddr("random caller");
    vm.prank(_caller);
    vm.expectRevert(BaseTrigger.Unauthorized.selector);
    trigger.addSet(ISet(_caller));
  }

  function test_CannotAddAnotherMangersSet() public {
    // Deploy a set that lists the correct manager as its manager, but which is not
    // actually in the manager's SetData.
    ISet _imposterSet = ISet(makeAddr("random set"));

    // The set lists the Cozy protocol manager as its manager.
    vm.mockCall(
      address(_imposterSet),
      abi.encodeWithSignature("manager()"),
      abi.encode(address(manager))
    );

    // But it shouldn't matter since the manager doesn't know about that set.
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IManager.sets.selector, _imposterSet),
      abi.encode(false /* set does not exist in manager */, true, 0, 0)
    );

    vm.prank(address(trigger.manager()));
    vm.expectRevert(BaseTrigger.Unauthorized.selector);
    trigger.addSet(_imposterSet);
  }

  function test_AddSetWillNotAddDuplicateSetsToATrigger() public {
    ISet _lastSetAdded = trigger.sets(0);
    uint256 _setCount = trigger.getSets().length;

    // The call wil be successful since the set is in trigger.sets. But the set should not have been added.
    vm.prank(address(manager));
    trigger.addSet(_lastSetAdded);
    assertEq(_setCount, trigger.getSets().length);

     // You can add a new set, however.
    vm.expectEmit(true, true, true, true);
    emit SetAdded(set2);
    vm.prank(address(manager));
    trigger.addSet(set2);
    _setCount++;
    assertEq(_setCount, trigger.getSets().length);
    assertEq(address(trigger.sets(_setCount - 1)), address(set2));

     // You still cannot add a duplicate set at this point.
    vm.prank(address(manager));
    trigger.addSet(set2);
    assertEq(_setCount, trigger.getSets().length);
    assertEq(address(trigger.sets(_setCount - 1)), address(set2));
  }

  function test_CannotDOSTheTriggerWithSets() public {
    uint256 _setCount = trigger.getSets().length;
    uint256 _maxSetCount = trigger.MAX_SET_LENGTH();

     MarketInfo[] memory _marketInfoSingleMarket = new MarketInfo[](1);
     _marketInfoSingleMarket[0] = MarketInfo(address(trigger), address(costModel), 10000, 0);

    for(uint256 i; i < _maxSetCount - 1 ; i++) { // Minus 1 because there is already one ISet.
      address _newSet = makeAddr(string.concat("set", vm.toString(i))); // e.g. "set1" is the label.

      vm.prank(address(manager));
      trigger.addSet(ISet(_newSet));

      _setCount++;
      assertEq(_setCount, trigger.getSets().length);
      assertEq(address(trigger.sets(_setCount - 1)), _newSet);
    }

     // If we try to add another set, it should revert.
     assertEq(trigger.MAX_SET_LENGTH(), trigger.getSets().length);
     vm.expectRevert(BaseTrigger.SetLimitReached.selector);
     vm.prank(address(manager));
     trigger.addSet(ISet(makeAddr("reverting set")));
  }

  // | From / To | ACTIVE      | FROZEN      | PAUSED   | TRIGGERED |
  // | --------- | ----------- | ----------- | -------- | --------- |
  // | ACTIVE    | -           | true        | false    | false     |
  // | FROZEN    | true        | -           | false    | true      |
  // | PAUSED    | false       | false       | -        | false     | <-- PAUSED is a set-level state, triggers cannot be paused
  // | TRIGGERED | false       | false       | false    | -         | <-- TRIGGERED is a terminal state
  // Transitions where from == to are allowed since the IManager converts them into a no-op.

  function test_ValidTriggerStateTransitions() public {
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.ACTIVE, CState.ACTIVE), true);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.ACTIVE, CState.FROZEN), true);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.ACTIVE, CState.PAUSED), false);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.ACTIVE, CState.TRIGGERED), true);

    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.FROZEN, CState.ACTIVE), true);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.FROZEN, CState.FROZEN), true);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.FROZEN, CState.PAUSED), false);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.FROZEN, CState.TRIGGERED), true);

    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.PAUSED, CState.ACTIVE), false);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.PAUSED, CState.FROZEN), false);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.PAUSED, CState.PAUSED), true);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.PAUSED, CState.TRIGGERED), false);

    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.TRIGGERED, CState.ACTIVE), false);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.TRIGGERED, CState.FROZEN), false);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.TRIGGERED, CState.PAUSED), false);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(CState.TRIGGERED, CState.TRIGGERED), false);
  }
}

abstract contract UpdateTriggerStateTest is TriggerTestSetup, ITriggerEvents {
  MinimalTrigger trigger;
  ISet[] sets;

  function test_UpdateTriggerStateTest1()  public { updateTriggerStateTest(CState.ACTIVE, CState.ACTIVE, false); }
  function test_UpdateTriggerStateTest2()  public { updateTriggerStateTest(CState.ACTIVE, CState.FROZEN, false); }
  function test_UpdateTriggerStateTest3()  public { updateTriggerStateTest(CState.ACTIVE, CState.PAUSED, true); }
  function test_UpdateTriggerStateTest4()  public { updateTriggerStateTest(CState.ACTIVE, CState.TRIGGERED, false); }

  function test_UpdateTriggerStateTest5()  public { updateTriggerStateTest(CState.FROZEN, CState.ACTIVE, false); }
  function test_UpdateTriggerStateTest6()  public { updateTriggerStateTest(CState.FROZEN, CState.FROZEN, false); }
  function test_UpdateTriggerStateTest7()  public { updateTriggerStateTest(CState.FROZEN, CState.PAUSED, true); }
  function test_UpdateTriggerStateTest8()  public { updateTriggerStateTest(CState.FROZEN, CState.TRIGGERED, false); }

  function test_UpdateTriggerStateTest9()  public { updateTriggerStateTest(CState.PAUSED, CState.ACTIVE, true); }
  function test_UpdateTriggerStateTest10() public { updateTriggerStateTest(CState.PAUSED, CState.FROZEN, true); }
  function test_UpdateTriggerStateTest11() public { updateTriggerStateTest(CState.PAUSED, CState.PAUSED, true); }
  function test_UpdateTriggerStateTest12() public { updateTriggerStateTest(CState.PAUSED, CState.TRIGGERED, true); }

  function test_UpdateTriggerStateTest13() public { updateTriggerStateTest(CState.TRIGGERED, CState.ACTIVE, true); }
  function test_UpdateTriggerStateTest14() public { updateTriggerStateTest(CState.TRIGGERED, CState.FROZEN, true); }
  function test_UpdateTriggerStateTest15() public { updateTriggerStateTest(CState.TRIGGERED, CState.PAUSED, true); }
  function test_UpdateTriggerStateTest16() public { updateTriggerStateTest(CState.TRIGGERED, CState.TRIGGERED, true); }

  function updateTriggerStateTest(CState _fromState, CState _toState, bool _expectNoChange) internal {
    updateTriggerState(trigger, _fromState);

    if (_expectNoChange) {
      if (_toState != trigger.state() || _fromState == CState.TRIGGERED) {
        // In these cases we expect a revert, other cases are successful no-ops.
        vm.expectRevert(BaseTrigger.InvalidStateTransition.selector);
      }
      trigger.TEST_HOOK_updateTriggerState(_toState);

      // There should be no state updates.
      assertEq(trigger.state(), _fromState);
    } else {
      vm.expectEmit(true, false, false, false);
      emit TriggerStateUpdated(_toState);
      trigger.TEST_HOOK_updateTriggerState(_toState);

      assertEq(trigger.state(), _toState);
    }
  }
}

contract UpdateTriggerStateOneSetTest is UpdateTriggerStateTest {
  function setUp() public override {
    super.setUp();
    sets.push(set);
    trigger = new MinimalTrigger(manager, sets);
  }
}

contract UpdateTriggerStateMultipleSetsTest is UpdateTriggerStateTest {
  function setUp() public override {
    super.setUp();
    sets.push(set);
    sets.push(set2);
    trigger = new MinimalTrigger(manager, sets);
  }
}

contract TriggerAcknowledged is TriggerTestSetup {
  MinimalTrigger trigger;

  function setUp() public override {
    super.setUp();
    ISet[] memory _triggerSets = new ISet[](1);
    _triggerSets[0] = set;
    trigger = new MinimalTrigger(manager, _triggerSets);
  }

  function test_AddSetRevertsIfUnacknowledged() public {
    vm.prank(address(manager));
    vm.expectRevert(BaseTrigger.Unacknowledged.selector);
    trigger.addSet(ISet(address(0xBEEF)));
  }

  function test_AddSetReturnsTrueIfAcknowledged() public {
    trigger.TEST_HOOK_acknowledge(true);
    vm.prank(address(manager));
    bool success = trigger.addSet(ISet(address(0xBEEF)));
    assertTrue(success);
  }
}