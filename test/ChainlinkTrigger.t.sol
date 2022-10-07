// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "src/ChainlinkTrigger.sol";
import "test/utils/TriggerTestSetup.sol";
import "test/utils/MockChainlinkOracle.sol";

contract MockManager is ICState {
  // Any set you ask about is managed by this contract \o/.
  function sets(ISet /* set */) external pure returns(IManager.SetData memory) {
    return IManager.SetData(true, true, 0, 0);
  }

  // This can just be a no-op for the test.
  function updateMarketState(ISet /* the set */, CState /* new state */) external {}
}

contract MockChainlinkTrigger is ChainlinkTrigger {
  constructor(
    IManager _manager,
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _targetOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) ChainlinkTrigger(_manager, _truthOracle, _targetOracle, _priceTolerance, _truthFrequencyTolerance, _trackingFrequencyTolerance) {}

  function TEST_HOOK_programmaticCheck() public view returns (bool) { return programmaticCheck(); }

  function TEST_HOOK_setState(CState _newState) public { state = _newState; }
}

abstract contract ChainlinkTriggerUnitTest is TriggerTestSetup {
  uint256 constant basePrice = 1945400000000; // The answer for BTC/USD at block 15135183.
  uint256 priceTolerance = 0.15e4; // 15%.
  uint256 truthFrequencyTolerance = 60;
  uint256 trackingFrequencyTolerance = 80;

  MockChainlinkTrigger trigger;
  MockChainlinkOracle truthOracle;
  MockChainlinkOracle targetOracle;

  function setUp() public override {
    super.setUp();
    set = ISet(address(42));
    IManager _manager = IManager(address(new MockManager()));

    truthOracle = new MockChainlinkOracle(basePrice);
    targetOracle = new MockChainlinkOracle(1947681501285); // The answer for WBTC/USD at block 15135183.

    trigger = new MockChainlinkTrigger(
      _manager,
      truthOracle,
      targetOracle,
      priceTolerance,
      truthFrequencyTolerance,
      trackingFrequencyTolerance
    );

    vm.prank(address(_manager));
    trigger.addSet(set);
  }
}

contract ChainlinkTriggerConstructorTest is ChainlinkTriggerUnitTest {
  function test_ConstructorRunProgrammaticCheck() public {
    IManager _manager = IManager(address(new MockManager()));

    truthOracle = new MockChainlinkOracle(basePrice);

    // Truth oracle has a base price of 1945400000000 and the price tolerance is 0.15e4, so with a target oracle price
    // of 1e12, runProgrammaticCheck() should result in the trigger becoming triggered.
    targetOracle = new MockChainlinkOracle(1e12);
    trigger = new MockChainlinkTrigger(
      _manager,
      truthOracle,
      targetOracle,
      priceTolerance,
      truthFrequencyTolerance,
      trackingFrequencyTolerance
    );

    // The trigger constructor should have executed runProgrammaticCheck() which should have transitioned
    // the trigger into the triggered state.
    assertEq(trigger.state(), CState.TRIGGERED);
  }

  function test_ConstructorAcknowledge() public {
    IManager _manager = IManager(address(new MockManager()));
    trigger = new MockChainlinkTrigger(
      _manager,
      truthOracle,
      targetOracle,
      priceTolerance,
      truthFrequencyTolerance,
      trackingFrequencyTolerance
    );
    assertTrue(trigger.acknowledged()); // Programmatic triggers should be automatically acknowledged in the constructor.
  }
}

contract RunProgrammaticCheckTest is ChainlinkTriggerUnitTest {
  using FixedPointMathLib for uint256;

  function runProgrammaticCheckAssertions(uint256 _targetPrice, CState _expectedTriggerState) public {
    // Setup.
    trigger.TEST_HOOK_setState(CState.ACTIVE);
    targetOracle.TEST_HOOK_setPrice(_targetPrice);

    // Exercise.
    if (_expectedTriggerState == CState.TRIGGERED) {
      vm.expectCall(
        address(trigger.manager()),
        abi.encodeCall(IManager.updateMarketState, (set, CState.TRIGGERED))
      );
    }
    assertEq(trigger.runProgrammaticCheck(), _expectedTriggerState);
    assertEq(trigger.state(), _expectedTriggerState);
  }

  function test_RunProgrammaticCheckUpdatesTriggerState() public {
    uint256 _overBaseOutsideTolerance = basePrice.mulDivDown(1e4 + priceTolerance, 1e4) + 1e9;
    runProgrammaticCheckAssertions(_overBaseOutsideTolerance, CState.TRIGGERED);

    uint256 _overBaseAtTolerance = basePrice.mulDivDown(1e4 + priceTolerance, 1e4);
    runProgrammaticCheckAssertions(_overBaseAtTolerance, CState.ACTIVE);

    uint256 _overBaseWithinTolerance = basePrice.mulDivDown(1e4 + priceTolerance, 1e4) - 1e9;
    runProgrammaticCheckAssertions(_overBaseWithinTolerance, CState.ACTIVE);

    runProgrammaticCheckAssertions(basePrice, CState.ACTIVE); // At base exactly.

    uint256 _underBaseWithinTolerance = basePrice.mulDivDown(1e4 - priceTolerance, 1e4) + 1e9;
    runProgrammaticCheckAssertions(_underBaseWithinTolerance, CState.ACTIVE);

    uint256 _underBaseAtTolerance = basePrice.mulDivDown(1e4 - priceTolerance, 1e4);
    runProgrammaticCheckAssertions(_underBaseAtTolerance, CState.ACTIVE);

    uint256 _underBaseOutsideTolerance = basePrice.mulDivDown(1e4 - priceTolerance, 1e4) - 1e9;
    runProgrammaticCheckAssertions(_underBaseOutsideTolerance, CState.TRIGGERED);
  }
}

contract ProgrammaticCheckTest is ChainlinkTriggerUnitTest {
  using FixedPointMathLib for uint256;

  function test_ProgrammaticCheckAtDiscretePoints() public {
    // 0.00000001e18
    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 + priceTolerance, 1e4) + 1e9); // Over base outside tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 + priceTolerance, 1e4)); // Over base at tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 + priceTolerance, 1e4) - 1e9); // Over base within tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice); // At base exactly.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 - priceTolerance, 1e4) + 1e9); // Under base within tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 - priceTolerance, 1e4)); // Under base at tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 - priceTolerance, 1e4) - 1e9); // Under base outside tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);
  }

  function test_TruthOracleZeroPrice() public {
    truthOracle.TEST_HOOK_setPrice(0);
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);
  }

  function testFuzz_ProgrammaticCheckRevertsIfUpdatedAtExceedsBlockTimestamp(
    uint256 _truthOracleUpdatedAt,
    uint256 _targetOracleUpdatedAt
  ) public {
    uint256 _currentTimestamp = 165738985; // When this test was written.
    // Warp to the current timestamp to avoid Arithmetic over/underflow with dates.
    vm.warp(_currentTimestamp);

    _truthOracleUpdatedAt = bound(
      _truthOracleUpdatedAt,
      block.timestamp - truthFrequencyTolerance,
      block.timestamp + 1 days
    );
    _targetOracleUpdatedAt = bound(
      _targetOracleUpdatedAt,
      block.timestamp - trackingFrequencyTolerance,
      block.timestamp + 1 days
    );

    truthOracle.TEST_HOOK_setUpdatedAt(_truthOracleUpdatedAt);
    targetOracle.TEST_HOOK_setUpdatedAt(_targetOracleUpdatedAt);

    if ( _truthOracleUpdatedAt > block.timestamp || _targetOracleUpdatedAt > block.timestamp) {
      vm.expectRevert(ChainlinkTrigger.InvalidTimestamp.selector);
    }

    trigger.TEST_HOOK_programmaticCheck();
  }

  function testFuzz_ProgrammaticCheckRevertsIfEitherOraclePriceIsStale(
    uint256 _truthOracleUpdatedAt,
    uint256 _targetOracleUpdatedAt
  ) public {
    uint256 _currentTimestamp = 165738985; // When this test was written.
    _truthOracleUpdatedAt = bound(_truthOracleUpdatedAt, 0, _currentTimestamp);
    _targetOracleUpdatedAt = bound(_targetOracleUpdatedAt, 0, _currentTimestamp);

    truthOracle.TEST_HOOK_setUpdatedAt(_truthOracleUpdatedAt);
    targetOracle.TEST_HOOK_setUpdatedAt(_targetOracleUpdatedAt);

    vm.warp(_currentTimestamp);
    if (
      _truthOracleUpdatedAt + truthFrequencyTolerance < block.timestamp ||
        _targetOracleUpdatedAt + trackingFrequencyTolerance < block.timestamp
    ) {
      vm.expectRevert(ChainlinkTrigger.StaleOraclePrice.selector);
    }

    trigger.TEST_HOOK_programmaticCheck();
  }

  function testFuzz_ProgrammaticCheckRoundUpDeltaPercentageBelowTolerance(uint128 _truthPrice) public {
    // In this test we subtract 1 from the value that is at the price tolerance from the truth
    // price, and confirm the trigger will not become triggered from a programmatic check. For any
    // truth price less than 7, any tracking value different than the truth price would result in
    // a delta greater than the tolerance (the setup price tolerance is 0.15e4, 15%).
    vm.assume(_truthPrice >= 7);

    truthOracle.TEST_HOOK_setPrice(_truthPrice);

    uint256 _trackingPrice = _truthPrice + (uint256(_truthPrice) * priceTolerance / 1e4) - 1;
    targetOracle.TEST_HOOK_setPrice(_trackingPrice);

    // Confirm the calculation in ChainlinkTrigger.programmaticCheck to determine the percentage
    // delta, which rounds up, does not cause the state of the trigger to become triggered.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);
  }

  function testFuzz_ProgrammaticCheckRoundUpDeltaPercentageEqualTolerance(uint128 _truthPrice) public {
    vm.assume(_truthPrice != 0);

    truthOracle.TEST_HOOK_setPrice(_truthPrice);

    uint256 _trackingPrice = _truthPrice + (uint256(_truthPrice) * priceTolerance / 1e4);
    targetOracle.TEST_HOOK_setPrice(_trackingPrice);

    // Confirm the calculation in ChainlinkTrigger.programmaticCheck to determine the percentage
    // delta, which rounds up, does not cause the state of the trigger to become triggered.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);
  }

  function testFuzz_ProgrammaticCheckRoundUpDeltaPercentageAboveTolerance(uint128 _truthPrice) public {
    // In this test we add 1 to the value that is at the price tolerance from the truth price, and
    // confirm the trigger will not become triggered from a programmatic check. For any truth price
    // less than 7, any tracking value different than the truth price would result in a delta
    // greater than the tolerance (the setup price tolerance is 0.15e4, 15%).
    vm.assume(_truthPrice >= 7);

    truthOracle.TEST_HOOK_setPrice(_truthPrice);

    uint256 _trackingPrice = _truthPrice + (uint256(_truthPrice) * priceTolerance / 1e4) + 1;
    targetOracle.TEST_HOOK_setPrice(_trackingPrice);

    // Confirm the calculation in ChainlinkTrigger.programmaticCheck to determine the percentage
    // delta, which rounds up, causes the state of the trigger to become triggered.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);
  }
}

abstract contract PegProtectionTriggerUnitTest is TriggerTestSetup {
  MockChainlinkOracle truthOracle;
  MockChainlinkOracle trackingOracle;
  MockChainlinkTrigger trigger;
  uint256 frequencyTolerance = 3600; // 1 hour frequency tolerance.

  function setUp() public override {
    super.setUp();
    set = ISet(address(42));
    IManager _manager = IManager(address(new MockManager()));

    truthOracle = new MockChainlinkOracle(1e8); // A $1 peg.
    trackingOracle = new MockChainlinkOracle(1e8);

    trigger = new MockChainlinkTrigger(
      _manager,
      truthOracle,
      trackingOracle,
      0.05e4, // 5% price tolerance.
      1,
      frequencyTolerance
    );
    vm.prank(address(_manager));
    trigger.addSet(set);
  }
}

contract PegProtectionRunProgrammaticCheckTest is PegProtectionTriggerUnitTest {

  function runProgrammaticCheckAssertions(uint256 _price, CState _expectedTriggerState) public {
    // Setup.
    trigger.TEST_HOOK_setState(CState.ACTIVE);
    trackingOracle.TEST_HOOK_setPrice(_price);

    // Exercise.
    if (_expectedTriggerState == CState.TRIGGERED) {
      vm.expectCall(
        address(trigger.manager()),
        abi.encodeCall(IManager.updateMarketState, (set, CState.TRIGGERED))
      );
    }
    assertEq(trigger.runProgrammaticCheck(), _expectedTriggerState);
    assertEq(trigger.state(), _expectedTriggerState);
  }

  function test_RunProgrammaticCheckUpdatesTriggerState() public {
    runProgrammaticCheckAssertions(130000000, CState.TRIGGERED); // Over peg outside tolerance.
    runProgrammaticCheckAssertions(104000000, CState.ACTIVE); // Over peg but within tolerance.
    runProgrammaticCheckAssertions(105000000, CState.ACTIVE); // Over peg at tolerance.
    runProgrammaticCheckAssertions(100000000, CState.ACTIVE); // At peg exactly.
    runProgrammaticCheckAssertions(96000000, CState.ACTIVE); // Under peg but within tolerance.
    runProgrammaticCheckAssertions(95000000, CState.ACTIVE); // Under peg at tolerance.
    runProgrammaticCheckAssertions(90000000, CState.TRIGGERED); // Under peg outside tolerance.
  }
}

contract PegProtectionProgrammaticCheckTest is PegProtectionTriggerUnitTest {

  function test_ProgrammaticCheckAtDiscretePoints() public {
    trackingOracle.TEST_HOOK_setPrice(130000000); // Over peg outside tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);

    trackingOracle.TEST_HOOK_setPrice(104000000); // Over peg but within tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(105000000); // Over peg at tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(1e8); // At peg exactly.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(96000000); // Under peg but within tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(95000000); // Under peg at tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(90000000); // Under peg outside tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);
  }
}
