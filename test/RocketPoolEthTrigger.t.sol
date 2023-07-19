// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "src/RocketPoolEthTrigger.sol";
import "test/utils/TriggerTestSetup.sol";
import "test/utils/MockChainlinkOracle.sol";
import "test/utils/MockRocketPoolOVMPriceOracle.sol";
import {MarketState} from "src/structs/StateEnums.sol";

contract MockManager {
  // Any set you ask about is managed by this contract \o/.
  function isSet(ISet /* set */ ) external pure returns (bool) {
    return true;
  }
}

contract MockSet {
  // no-op for testing
  function updateMarketState(MarketState) external {}
}

contract MockRocketPoolEthTrigger is RocketPoolEthTrigger {
  constructor(
    IManager _manager,
    AggregatorV3Interface _chainlinkOracle,
    IRocketPoolOVMPriceOracle _rocketPoolOracle,
    uint256 _priceTolerance,
    uint256 _chainlinkFrequencyTolerance,
    uint256 _rocketPoolFrequencyTolerance
  )
    RocketPoolEthTrigger(
      _manager,
      _chainlinkOracle,
      _rocketPoolOracle,
      _priceTolerance,
      _chainlinkFrequencyTolerance,
      _rocketPoolFrequencyTolerance
    )
  {
    sets.push(ISet(address(new MockSet())));
  }

  function TEST_HOOK_programmaticCheck() public view returns (bool) {
    return programmaticCheck();
  }

  function TEST_HOOK_setState(MarketState _newState) public {
    state = _newState;
  }
}

abstract contract RocketPoolEthTriggerUnitTest is TriggerTestSetup {
  uint256 constant ZOC = 1e4;
  uint256 constant basePrice = 1077183031474780077; // The answer for rETH/ETH at block 107094497.
  uint256 priceTolerance = 0.15e4; // 15%.
  uint256 chainlinkFrequencyTolerance = 60;
  uint256 rocketPoolFrequencyTolerance = 80;

  MockRocketPoolEthTrigger trigger;
  MockChainlinkOracle chainlinkOracle;
  MockRocketPoolOVMPriceOracle rocketPoolOracle;

  function setUp() public override {
    super.setUp();
    set = ISet(address(new MockSet()));
    IManager _manager = IManager(address(new MockManager()));

    chainlinkOracle = new MockChainlinkOracle(basePrice, 18);
    rocketPoolOracle = new MockRocketPoolOVMPriceOracle(basePrice, block.timestamp); // The answer for WBTC/USD at block 15135183.

    trigger = new MockRocketPoolEthTrigger(
      _manager,
      chainlinkOracle,
      rocketPoolOracle,
      priceTolerance,
      chainlinkFrequencyTolerance,
      rocketPoolFrequencyTolerance
    );

    vm.prank(address(set));
    trigger.addSet(set);
  }
}

contract RocketPoolEthTriggerConstructorTest is RocketPoolEthTriggerUnitTest {
  function test_ConstructorRunProgrammaticCheck() public {
    IManager _manager = IManager(address(new MockManager()));

    chainlinkOracle = new MockChainlinkOracle(basePrice, 18);

    // Chianlink oracle has a base price of 1077183031474780077 and the price tolerance is 0.15e4, so with a Rocket Pool oracle price
    // of 1292619638000000000 (~120% of base price), runProgrammaticCheck() should result in the trigger becoming triggered.
    rocketPoolOracle = new MockRocketPoolOVMPriceOracle(1292619638000000000, block.timestamp);
    trigger = new MockRocketPoolEthTrigger(
      _manager,
      chainlinkOracle,
      rocketPoolOracle,
      priceTolerance,
      chainlinkFrequencyTolerance,
      rocketPoolFrequencyTolerance
    );

    // The trigger constructor should have executed runProgrammaticCheck() which should have transitioned
    // the trigger into the triggered state.
    assertEq(trigger.state(), MarketState.TRIGGERED);

    chainlinkOracle = new MockChainlinkOracle(basePrice, 18);

    // Chianlink oracle has a base price of 1077183031474780077 and the price tolerance is 0.15e4, so with a Rocket Pool oracle price
    // of 1184901335000000000 (~110% of base price), runProgrammaticCheck() should not result in the trigger becoming triggered.
    rocketPoolOracle = new MockRocketPoolOVMPriceOracle(1184901335000000000, block.timestamp);
    trigger = new MockRocketPoolEthTrigger(
      _manager,
      chainlinkOracle,
      rocketPoolOracle,
      priceTolerance,
      chainlinkFrequencyTolerance,
      rocketPoolFrequencyTolerance
    );
    assertEq(trigger.state(), MarketState.ACTIVE);
  }

  function test_ConstructorAcknowledge() public {
    IManager _manager = IManager(address(new MockManager()));
    trigger = new MockRocketPoolEthTrigger(
      _manager,
      chainlinkOracle,
      rocketPoolOracle,
      priceTolerance,
      chainlinkFrequencyTolerance,
      rocketPoolFrequencyTolerance
    );
    assertTrue(trigger.acknowledged()); // Programmatic triggers should be automatically acknowledged in the
      // constructor.
  }

  function testFuzz_ConstructorInvalidPriceTolerance(uint256 _priceTolerance) public {
    _priceTolerance = bound(_priceTolerance, ZOC, type(uint256).max);

    IManager _manager = IManager(address(new MockManager()));
    vm.expectRevert(RocketPoolEthTrigger.InvalidPriceTolerance.selector);
    trigger = new MockRocketPoolEthTrigger(
      _manager,
      chainlinkOracle,
      rocketPoolOracle,
      _priceTolerance,
      chainlinkFrequencyTolerance,
      rocketPoolFrequencyTolerance
    );
  }

  function test_ConstructorChainlinkOracleDifferentDecimals() public {
    chainlinkOracle = new MockChainlinkOracle(basePrice, 8); // Should have 18 decimals.
    IManager _manager = IManager(address(new MockManager()));

    vm.expectRevert(RocketPoolEthTrigger.InvalidDecimals.selector);
    trigger = new MockRocketPoolEthTrigger(
      _manager,
      chainlinkOracle,
      rocketPoolOracle,
      priceTolerance,
      chainlinkFrequencyTolerance,
      rocketPoolFrequencyTolerance
    );
  }
}