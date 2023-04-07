// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "test/utils/MinimalTrigger.sol";
import "test/utils/TriggerTestSetup.sol";

contract MockSet {
  // no-op for testing
  function updateMarketState(MarketState) external {}
}

contract BaseTriggerCoreTest is TriggerTestSetup {
  MinimalTrigger trigger;

  function setUp() public override {
    super.setUp();
    ISet[] memory _triggerSets = new ISet[](1);
    _triggerSets[0] = ISet(address(new MockSet()));
    trigger = new MinimalTrigger(manager, _triggerSets);
    trigger.TEST_HOOK_acknowledge(true);
  }

  function test_AddSetRevertsIfNotExistingInManager() public {
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IManager.isSet.selector),
      abi.encode(false) // Set exists and is approved for backstop, config update time and deadline are zero.
    );
    address _caller = makeAddr("random caller");
    vm.prank(_caller);
    vm.expectRevert(BaseTrigger.Unauthorized.selector);
    trigger.addSet(ISet(_caller));
  }

  function test_AddSetRevertsIfNotCalledBySet() public {
    address _caller = makeAddr("random caller");
    vm.prank(_caller);
    vm.expectRevert(BaseTrigger.Unauthorized.selector);
    trigger.addSet(ISet(set));
  }

  function test_CannotAddAnotherMangersSet() public {
    // Deploy a set that lists the correct manager as its manager, but which is not
    // actually in the manager's SetData.
    ISet _imposterSet = ISet(makeAddr("random set"));

    // The set lists the Cozy protocol manager as its manager.
    vm.mockCall(address(_imposterSet), abi.encodeWithSignature("manager()"), abi.encode(address(manager)));

    // But it shouldn't matter since the manager doesn't know about that set.
    vm.mockCall(address(manager), abi.encodeWithSelector(IManager.isSet.selector, _imposterSet), abi.encode(false));

    vm.prank(address(_imposterSet));
    vm.expectRevert(BaseTrigger.Unauthorized.selector);
    trigger.addSet(_imposterSet);
  }

  function test_AddSetWillNotAddDuplicateSetsToATrigger() public {
    ISet _lastSetAdded = trigger.sets(0);
    uint256 _setCount = trigger.getSets().length;

    // The call wil be successful since the set is in trigger.sets. But the set should not have been added.
    vm.prank(address(_lastSetAdded));
    trigger.addSet(_lastSetAdded);
    assertEq(_setCount, trigger.getSets().length);

    // You can add a new set, however.
    vm.expectEmit(true, true, true, true);
    emit SetAdded(set2);
    vm.prank(address(set2));
    trigger.addSet(set2);
    _setCount++;
    assertEq(_setCount, trigger.getSets().length);
    assertEq(address(trigger.sets(_setCount - 1)), address(set2));

    // You still cannot add a duplicate set at this point.
    vm.prank(address(set2));
    trigger.addSet(set2);
    assertEq(_setCount, trigger.getSets().length);
    assertEq(address(trigger.sets(_setCount - 1)), address(set2));
  }

  function test_CannotDOSTheTriggerWithSets() public {
    uint256 _setCount = trigger.getSets().length;
    uint256 _maxSetCount = trigger.MAX_SET_LENGTH();

    for (uint256 i; i < _maxSetCount - 1; i++) {
      // Minus 1 because there is already one ISet.
      address _newSet = makeAddr(string.concat("set", vm.toString(i))); // e.g. "set1" is the label.

      vm.prank(address(_newSet));
      trigger.addSet(ISet(_newSet));

      _setCount++;
      assertEq(_setCount, trigger.getSets().length);
      assertEq(address(trigger.sets(_setCount - 1)), _newSet);
    }

    // If we try to add another set, it should revert.
    assertEq(trigger.MAX_SET_LENGTH(), trigger.getSets().length);
    vm.expectRevert(BaseTrigger.SetLimitReached.selector);
    vm.prank(makeAddr("reverting set"));
    trigger.addSet(ISet(makeAddr("reverting set")));
  }

  // | From / To | ACTIVE      | FROZEN      | PAUSED   | TRIGGERED |
  // | --------- | ----------- | ----------- | -------- | --------- |
  // | ACTIVE    | -           | true        | false    | false     |
  // | FROZEN    | true        | -           | false    | true      |
  // | PAUSED    | false       | false       | -        | false     | <-- PAUSED is a set-level state, triggers cannot
  // be paused
  // | TRIGGERED | false       | false       | false    | -         | <-- TRIGGERED is a terminal state
  // Transitions where from == to are allowed since the IManager converts them into a no-op.

  function test_ValidTriggerStateTransitions() public {
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(MarketState.ACTIVE, MarketState.ACTIVE), true);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(MarketState.ACTIVE, MarketState.FROZEN), true);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(MarketState.ACTIVE, MarketState.TRIGGERED), true);

    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(MarketState.FROZEN, MarketState.ACTIVE), true);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(MarketState.FROZEN, MarketState.FROZEN), true);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(MarketState.FROZEN, MarketState.TRIGGERED), true);

    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(MarketState.TRIGGERED, MarketState.ACTIVE), false);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(MarketState.TRIGGERED, MarketState.FROZEN), false);
    assertEq(trigger.TEST_HOOK_isValidTriggerStateTransition(MarketState.TRIGGERED, MarketState.TRIGGERED), false);
  }
}

abstract contract UpdateTriggerStateTest is TriggerTestSetup {
  MinimalTrigger trigger;
  ISet[] sets;

  function test_UpdateTriggerStateTest1() public {
    updateTriggerStateTest(MarketState.ACTIVE, MarketState.ACTIVE, false);
  }

  function test_UpdateTriggerStateTest2() public {
    updateTriggerStateTest(MarketState.ACTIVE, MarketState.FROZEN, false);
  }

  function test_UpdateTriggerStateTest4() public {
    updateTriggerStateTest(MarketState.ACTIVE, MarketState.TRIGGERED, false);
  }

  function test_UpdateTriggerStateTest5() public {
    updateTriggerStateTest(MarketState.FROZEN, MarketState.ACTIVE, false);
  }

  function test_UpdateTriggerStateTest6() public {
    updateTriggerStateTest(MarketState.FROZEN, MarketState.FROZEN, false);
  }

  function test_UpdateTriggerStateTest8() public {
    updateTriggerStateTest(MarketState.FROZEN, MarketState.TRIGGERED, false);
  }

  function test_UpdateTriggerStateTest13() public {
    updateTriggerStateTest(MarketState.TRIGGERED, MarketState.ACTIVE, true);
  }

  function test_UpdateTriggerStateTest14() public {
    updateTriggerStateTest(MarketState.TRIGGERED, MarketState.FROZEN, true);
  }

  function test_UpdateTriggerStateTest16() public {
    updateTriggerStateTest(MarketState.TRIGGERED, MarketState.TRIGGERED, true);
  }

  function updateTriggerStateTest(MarketState _fromState, MarketState _toState, bool _expectNoChange) internal {
    updateTriggerState(trigger, _fromState);

    if (_expectNoChange) {
      if (_toState != trigger.state() || _fromState == MarketState.TRIGGERED) {
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
    sets.push(ISet(address(new MockSet())));
    trigger = new MinimalTrigger(manager, sets);
  }
}

contract UpdateTriggerStateMultipleSetsTest is UpdateTriggerStateTest {
  function setUp() public override {
    super.setUp();
    sets.push(ISet(address(new MockSet())));
    sets.push(ISet(address(new MockSet())));
    trigger = new MinimalTrigger(manager, sets);
  }
}

contract TriggerAcknowledged is TriggerTestSetup {
  MinimalTrigger trigger;

  function setUp() public override {
    super.setUp();
    ISet[] memory _triggerSets = new ISet[](1);
    _triggerSets[0] = ISet(address(new MockSet()));
    trigger = new MinimalTrigger(manager, _triggerSets);
  }

  function test_AddSetRevertsIfUnacknowledged() public {
    vm.prank(address(0xBEEF));
    vm.expectRevert(BaseTrigger.Unacknowledged.selector);
    trigger.addSet(ISet(address(0xBEEF)));
  }

  function test_AddSetReturnsTrueIfAcknowledged() public {
    trigger.TEST_HOOK_acknowledge(true);
    vm.prank(address(0xBEEF));
    bool success = trigger.addSet(ISet(address(0xBEEF)));
    assertTrue(success);
  }
}
