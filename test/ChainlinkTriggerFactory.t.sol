// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "src/ChainlinkTriggerFactory.sol";
import "test/utils/TriggerTestSetup.sol";
import "test/utils/MockChainlinkOracle.sol";

// TODO Use `vm.mockCall` instead of a dedicated mocking contract.
contract MockManager is ICState {
  // Any set you ask about is managed by this contract \o/.
  function sets(ISet /* set */) external pure returns(IManager.SetData memory) {
    return IManager.SetData(true, true, 0, 0);
  }

  // This is a no-op, it's not needed for these tests.
  function updateMarketState(ISet /* set */, CState /* newMarketState */) external {}
}

contract ChainlinkTriggerFactoryTestBaseSetup is TriggerTestSetup {
  address constant ethUsdOracleMainnet    = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; //   ETH / USD on mainnet
  address constant stEthUsdOracleMainnet  = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8; // stETH / USD on mainnet
  address constant usdcUsdOracleMainnet   = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; //  USDC / USD on mainnet
  address constant bnbEthOracleMainnet    = 0xc546d2d06144F9DD42815b8bA46Ee7B8FcAFa4a2; //   BNB / ETH on mainnet

  address constant ethUsdOracleOptimism   = 0x13e3Ee699D1909E989722E753853AE30b17e08c5; //   ETH / USD on Optimism
  address constant stEthUsdOracleOptimism = 0x41878779a388585509657CE5Fb95a80050502186; // stETH / USD on Optimism
  address constant usdcUsdOracleOptimism  = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3; //  USDC / USD on Optimism
  address constant linkEthOracleOptimism  = 0x464A1515ADc20de946f8d0DEB99cead8CEAE310d; //  LINK / ETH on Optimism

  ChainlinkTriggerFactory factory;

  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed truthOracle,
    address indexed trackingOracle,
    uint256 priceTolerance,
    uint256 truthFrequencyTolerance,
    uint256 trackingFrequencyTolerance,
    string name,
    string description,
    string logoURI
  );

  function setUp() public virtual override {
    super.setUp();
    manager = IManager(address(new MockManager()));
    factory = new ChainlinkTriggerFactory(manager);
    vm.makePersistent(address(manager), address(factory));
  }

  function _addMaxSetsToTrigger(IChainlinkTrigger _trigger) internal {
    uint256 _maxSetCount = _trigger.MAX_SET_LENGTH();
    vm.startPrank(address(manager));
    for(uint256 i = 0; i < _maxSetCount; i++) {
      _trigger.addSet(ISet(address(uint160(uint256(keccak256(abi.encode(i)))))));
    }
    vm.stopPrank();
  }
}

contract ChainlinkTriggerFactoryTestSetup is ChainlinkTriggerFactoryTestBaseSetup {
  function setUp() public override {
    super.setUp();

    // This is needed b/c we check that the oracle pair's decimals match during deploy.
    vm.etch(ethUsdOracleMainnet, address(new FixedPriceAggregator(8, 1e8)).code);
    vm.etch(stEthUsdOracleMainnet, address(new FixedPriceAggregator(8, 1e8)).code);
    vm.etch(usdcUsdOracleMainnet, address(new FixedPriceAggregator(8, 1e8)).code);
  }
}

contract DeployTriggerForkTest is ChainlinkTriggerFactoryTestBaseSetup {
  uint256 mainnetForkId;
  uint256 optimismForkId;

  function setUp() public override {
    super.setUp();

    uint256 mainnetForkBlock = 15181633; // The mainnet block number at the time this test was written.
    uint256 optimismForkBlock = 25582446; // The optimism block number
    mainnetForkId = vm.createFork(vm.envString("MAINNET_RPC_URL"), mainnetForkBlock);
    optimismForkId = vm.createFork(vm.envString("OPTIMISM_RPC_URL"), optimismForkBlock);
  }

  function testFork_DeployTriggerRevertsWithMismatchedOracles(
    uint256 _forkId,
    address _truthOracle,
    address _trackingOracle
  ) internal {
    vm.selectFork(_forkId);

    assertNotEq(
      AggregatorV3Interface(_truthOracle).decimals(),
      AggregatorV3Interface(_trackingOracle).decimals()
    );

    vm.expectRevert(ChainlinkTriggerFactory.InvalidOraclePair.selector);

    factory.deployTrigger(
      AggregatorV3Interface(_truthOracle),
      AggregatorV3Interface(_trackingOracle),
      0.1e4, // priceTolerance.
      45, // truthFrequencyTolerance.
      45, // trackingFrequencyTolerance
      IChainlinkTriggerFactory.TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150"
      )
    );
  }

  function testFork_DeployTriggerChainlinkIntegration(
    uint256 _forkId,
    address _truthOracle,
    address _trackingOracle,
    int256 _pegPrice,
    uint8 _pegDecimals
  ) internal {
    vm.selectFork(_forkId);

    // While running this test, none of the prices of the used feed pairs differ by over 0.6e4.
    // We want to ensure that the trigger isn't deployed and updated to the triggered state in
    // the trigger constructor.
    uint256 _priceTolerance = 0.6e4;

    // This value is fairly arbitrary. We set it to 24 hours, which should be longer than the
    // "heartbeat" for all feeds used in this test. New price data is written when the off-chain
    // price moves more than the feed's deviation threshold, or if the heartbeat duration elapses
    // without other updates. We set the tracking oracle to 1 hour longer to ensure they don't match for testing.
    uint256 _truthFrequencyTolerance = 24 hours;
    uint256 _trackingFrequencyTolerance = 25 hours;

    IChainlinkTrigger _trigger;
    if (_pegPrice == 0 && _pegDecimals == 0) {
      // We are NOT deploying a peg trigger.
      _trigger = factory.deployTrigger(
        AggregatorV3Interface(_truthOracle),
        AggregatorV3Interface(_trackingOracle),
        _priceTolerance,
        _truthFrequencyTolerance,
        _trackingFrequencyTolerance,
        IChainlinkTriggerFactory.TriggerMetadata(
          "Chainlink Trigger",
          "A trigger that compares prices on Chainlink against a threshold",
          "https://via.placeholder.com/150"
        )
      );
      assertEq(_trigger.truthFrequencyTolerance(), _truthFrequencyTolerance);
    } else {
      // We are deploying a peg trigger.
      _trigger = factory.deployTrigger(
        _pegPrice,
        _pegDecimals,
        AggregatorV3Interface(_trackingOracle),
        _priceTolerance,
        _trackingFrequencyTolerance,
        IChainlinkTriggerFactory.TriggerMetadata(
          "Peg Protection Trigger",
          "A trigger that protects from something depegging",
          "https://via.placeholder.com/150"
        )
      );
      AggregatorV3Interface _pegOracle = _trigger.truthOracle();
      (,int256 _priceInt,,,) = _pegOracle.latestRoundData();
      assertEq(_priceInt, _pegPrice);
      assertEq(_pegOracle.decimals(), _pegDecimals);
      _truthOracle = address(_pegOracle);

      // For peg triggers, we set the frequency tolerance to 0 for the truth FixedPriceAggregator peg oracle.
      assertEq(_trigger.truthFrequencyTolerance(), 0);
    }

    assertEq(_trigger.state(), CState.ACTIVE);
    assertEq(_trigger.getSets().length, 0);
    assertEq(_trigger.manager(), factory.manager());
    assertEq(_trigger.truthOracle(), AggregatorV3Interface(_truthOracle));
    assertEq(_trigger.trackingOracle(), AggregatorV3Interface(_trackingOracle));
    assertEq(_trigger.priceTolerance(), _priceTolerance);
    assertEq(_trigger.trackingFrequencyTolerance(), _trackingFrequencyTolerance);

    // Mock the tracking oracle's price to 0.
    vm.mockCall(
      address(_trackingOracle),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(uint80(1), int256(0), 0, block.timestamp, uint80(1))
    );

    // `runProgrammaticCheck` should trigger if the oracle data is fetched, because the tracking oracle's
    // price has been mocked to 0 which results in a price delta greater than _priceTolerance between the
    // truth and tracking oracles.
    vm.expectEmit(true, true, true, true);
    emit TriggerStateUpdated(CState.TRIGGERED);
    assertEq(_trigger.runProgrammaticCheck(), CState.TRIGGERED);
  }

  function testFork_DeployTriggerChainlinkIntegration(
    uint256 _forkId,
    address _truthOracle,
    address _trackingOracle
  ) internal {
    testFork_DeployTriggerChainlinkIntegration(_forkId, _truthOracle, _trackingOracle, 0, 0);
  }

  function testFork1_DeployTriggerChainlinkIntegration() public {
    testFork_DeployTriggerChainlinkIntegration(mainnetForkId, ethUsdOracleMainnet, stEthUsdOracleMainnet);
    testFork_DeployTriggerChainlinkIntegration(mainnetForkId, address(0), usdcUsdOracleMainnet, 1e8, 8);
    testFork_DeployTriggerRevertsWithMismatchedOracles(mainnetForkId, ethUsdOracleMainnet, bnbEthOracleMainnet);
  }

  function testFork10_DeployTriggerChainlinkIntegration() public {
    testFork_DeployTriggerChainlinkIntegration(optimismForkId, ethUsdOracleOptimism, stEthUsdOracleOptimism);
    // We're using a peg price of $2 because the oracle price for USDC is exactly 1e8 at the block we've forked from
    // and the test presupposes that the spot price will not match the peg.
    testFork_DeployTriggerChainlinkIntegration(optimismForkId, address(0), usdcUsdOracleOptimism, 2e8, 8);
    testFork_DeployTriggerRevertsWithMismatchedOracles(optimismForkId, ethUsdOracleOptimism, linkEthOracleOptimism);
  }
}

contract DeployTriggerTest is ChainlinkTriggerFactoryTestSetup {
  function testFuzz_DeployTriggerDeploysAChainlinkTriggerWithDesiredSpecs(
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public {
    IChainlinkTrigger _trigger = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      IChainlinkTriggerFactory.TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150"
      )
    );

    assertEq(_trigger.getSets().length, 0);
    assertEq(_trigger.manager(), factory.manager());
    assertEq(_trigger.truthOracle(), AggregatorV3Interface(ethUsdOracleMainnet));
    assertEq(_trigger.trackingOracle(), AggregatorV3Interface(stEthUsdOracleMainnet));
    assertEq(_trigger.priceTolerance(), _priceTolerance);
    assertEq(_trigger.truthFrequencyTolerance(), _truthFrequencyTolerance);
    assertEq(_trigger.trackingFrequencyTolerance(), _trackingFrequencyTolerance);
  }

  function testFuzz_DeployTriggerEmitsAnEvent(
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public {
    address _triggerAddr = factory.computeTriggerAddress(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      0 // This is the first trigger of its kind.
    );
    bytes32 _triggerConfigId = factory.triggerConfigId(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    vm.expectEmit(true, true, true, true);
    emit TriggerDeployed(
      _triggerAddr,
      _triggerConfigId,
      stEthUsdOracleMainnet,
      ethUsdOracleMainnet,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      "Chainlink Trigger",
      "A trigger that compares prices on Chainlink against a threshold",
      "https://via.placeholder.com/150"
    );

    factory.deployTrigger(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      IChainlinkTriggerFactory.TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150"
      )
    );
  }

  function testFuzz_DeployTriggerDeploysANewTriggerEachTime(
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public {
    bytes32 _triggerConfigId = factory.triggerConfigId(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    assertEq(factory.triggerCount(_triggerConfigId), 0);

    IChainlinkTrigger _triggerA = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      IChainlinkTriggerFactory.TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150"
      )
    );

    assertEq(factory.triggerCount(_triggerConfigId), 1);

    IChainlinkTrigger _triggerB = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      IChainlinkTriggerFactory.TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150"
      )
    );

    assertEq(factory.triggerCount(_triggerConfigId), 2);

    assertNotEq(address(_triggerA), address(_triggerB));
  }

  function testFuzz_DeployTriggerDeploysToDifferentAddressesOnDifferentChains(
    uint8 _chainId
  ) public {
    vm.assume(_chainId != block.chainid);

    uint256 _priceTolerance = 0.42e4;
    uint256 _truthFrequencyTolerance = 42;
    uint256 _trackingFrequencyTolerance = 43;

    IChainlinkTrigger _triggerA = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      IChainlinkTriggerFactory.TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150"
      )
    );

    vm.chainId(_chainId);

    IChainlinkTrigger _triggerB = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      IChainlinkTriggerFactory.TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150"
      )
    );

    assertNotEq(address(_triggerA), address(_triggerB));
  }
}

contract ComputeTriggerAddressTest is ChainlinkTriggerFactoryTestSetup {
  function testFuzz_ComputeTriggerAddressMatchesDeployedAddress(
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public {
    address _expectedAddress = factory.computeTriggerAddress(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      0 // This is the first trigger of its kind.
    );

    IChainlinkTrigger _trigger = factory.deployTrigger(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      IChainlinkTriggerFactory.TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150"
      )
    );

    assertEq(_expectedAddress, address(_trigger));
  }

  function testFuzz_ComputeTriggerAddressComputesSameAddressesOnDifferentChains(
    uint8 _chainId
  ) public {
    vm.assume(_chainId != block.chainid);

    address _addressA = factory.computeTriggerAddress(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      0.2e4, // priceTolerance.
      360, // frequencyTolerance.
      390,
      42 // This is the 42nd trigger of its kind.
    );

    vm.chainId(_chainId);

    address _addressB = factory.computeTriggerAddress(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      0.2e4, // priceTolerance.
      360, // frequencyTolerance.
      390,
      42 // This is the 42nd trigger of its kind.
    );

    assertEq(_addressA, _addressB);
  }
}

contract TriggerConfigIdTest is ChainlinkTriggerFactoryTestSetup {
  function testFuzz_TriggerConfigIdIsDeterministic(
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public {
    bytes32 _configIdA = factory.triggerConfigId(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );
    bytes32 _configIdB = factory.triggerConfigId(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );
    assertEq(_configIdA, _configIdB);
  }

  function testFuzz_TriggerConfigIdCanBeUsedToGetTheTriggerCount(
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public {
    bytes32 _triggerConfigId = factory.triggerConfigId(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    assertEq(factory.triggerCount(_triggerConfigId), 0);

    factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      IChainlinkTriggerFactory.TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150"
      )
    );

    assertEq(factory.triggerCount(_triggerConfigId), 1);
  }
}

contract FindAvailableTriggerTest is ChainlinkTriggerFactoryTestSetup {
  function test_FindAvailableTriggerWhenNoneExist() public {
    testFuzz_FindAvailableTriggerWhenMultipleExistAndAreAvailable(
      0.5e4, // priceTolerance.
      24 * 60 * 60, // truthFrequencyTolerance.
      25 * 60 * 60, // trackingFrequencyTolerance.
      0 // Do not deploy any triggers.
    );
  }

  function testFuzz_FindAvailableTriggerWhenMultipleExistAndAreAvailable(
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance,
    uint8 _triggersToDeploy
  ) public {
    // This test is really slow (10+ seconds) without reasonable bounds.
    _triggersToDeploy = uint8(bound(_triggersToDeploy, 0, 10));

    IChainlinkTrigger _initTrigger;
    for (uint256 i = 0; i < _triggersToDeploy; i++) {
      IChainlinkTrigger _trigger = factory.deployTrigger(
        AggregatorV3Interface(ethUsdOracleMainnet),
        AggregatorV3Interface(stEthUsdOracleMainnet),
        _priceTolerance,
        _truthFrequencyTolerance,
        _trackingFrequencyTolerance,
        IChainlinkTriggerFactory.TriggerMetadata(
          "Chainlink Trigger",
          "A trigger that compares prices on Chainlink against a threshold",
          "https://via.placeholder.com/150"
        )
      );
      if (i == 0) _initTrigger = _trigger;
    }

    address _expectedTrigger = factory.findAvailableTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    // The first available trigger should be returned.
    assertEq(_expectedTrigger, address(_initTrigger));
  }

  function testFuzz_FindAvailableTriggerWhenMultipleExistButAreUnavailable(
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance,
    uint8 _triggersToDeploy
  ) public {
    // This test is really slow (10+ seconds) without reasonable bounds.
    _triggersToDeploy = uint8(bound(_triggersToDeploy, 0, 10));

    IChainlinkTrigger _trigger;
    for (uint256 i = 0; i < _triggersToDeploy; i++) {
      _trigger = factory.deployTrigger(
        AggregatorV3Interface(stEthUsdOracleMainnet),
        AggregatorV3Interface(ethUsdOracleMainnet),
        _priceTolerance,
        _truthFrequencyTolerance,
        _trackingFrequencyTolerance,
        IChainlinkTriggerFactory.TriggerMetadata(
          "Chainlink Trigger",
          "A trigger that compares prices on Chainlink against a threshold",
          "https://via.placeholder.com/150"
        )
      );
      _addMaxSetsToTrigger(_trigger);
    }

    address _expectedTrigger = factory.findAvailableTrigger(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    assertEq(_expectedTrigger, address(0));
  }
}

contract DeployPeggedTriggerTest is ChainlinkTriggerFactoryTestSetup {
  function test_DeployTriggerDeploysFixedPriceAggregator() public {
    IChainlinkTrigger _trigger = factory.deployTrigger(
      1e8, // Fixed price.
      8, // Decimals.
      AggregatorV3Interface(usdcUsdOracleMainnet),
      0.001e4, // 0.1% price tolerance.
      60, // 60s frequency tolerance.
      IChainlinkTriggerFactory.TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150"
      )
    );

    assertEq(_trigger.state(), CState.ACTIVE);
    assertEq(_trigger.getSets().length, 0);
    assertEq(_trigger.manager(), factory.manager());
    assertEq(_trigger.trackingOracle(), AggregatorV3Interface(usdcUsdOracleMainnet));
    assertEq(_trigger.priceTolerance(), 0.001e4);
    // For peg triggers, we set the frequency tolerance to 0 for the truth FixedPriceAggregator peg oracle.
    assertEq(_trigger.truthFrequencyTolerance(), 0);
    assertEq(_trigger.trackingFrequencyTolerance(), 60);

    (,int256 _priceInt,, uint256 _updatedAt,) = _trigger.truthOracle().latestRoundData();
    assertEq(_priceInt, 1e8);
    assertEq(_updatedAt, block.timestamp);
  }

  function test_DeployTriggerIdempotency() public {
    IChainlinkTrigger _triggerA = factory.deployTrigger(
      1e8, // Fixed price.
      8, // Decimals.
      AggregatorV3Interface(usdcUsdOracleMainnet),
      0.001e4, // 0.1% price tolerance.
      60, // 60s frequency tolerance.
      IChainlinkTriggerFactory.TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150"
      )
    );

    IChainlinkTrigger _triggerB = factory.deployTrigger(
      1e8, // Fixed price.
      8, // Decimals.
      AggregatorV3Interface(usdcUsdOracleMainnet),
      0.042e4, // 4.2% price tolerance.
      360, // 360s frequency tolerance.
      IChainlinkTriggerFactory.TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150"
      )
    );

    assertEq(_triggerA.truthOracle(), _triggerB.truthOracle());

    // Deploy a new trigger with a different peg.
    IChainlinkTrigger _triggerC = factory.deployTrigger(
      1e18, // Fixed price.
      8, // Decimals.
      AggregatorV3Interface(usdcUsdOracleMainnet),
      0.042e4, // 4.2% price tolerance.
      360, // 360s frequency tolerance.
      IChainlinkTriggerFactory.TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150"
      )
    );

    // A new peg oracle would need to have been deployed.
    assertNotEq(_triggerB.truthOracle(), _triggerC.truthOracle());
  }
}

contract DeployFixedPriceAggregatorTest is ChainlinkTriggerFactoryTestSetup {
  function testFuzz_DeployFixedPriceAggregatorIsIdempotent(
    int256 _price,
    uint8 _decimals,
    uint8 _chainId
  ) public {
    AggregatorV3Interface _oracleA = factory.deployFixedPriceAggregator(_price, _decimals);
    AggregatorV3Interface _oracleB = factory.deployFixedPriceAggregator(_price, _decimals);

    assertEq(_oracleA, _oracleB);
    assertEq(_oracleA.decimals(), _decimals);

    (,int256 _priceInt,, uint256 _updatedAt,) = _oracleA.latestRoundData();
    assertEq(_price, _priceInt);
    assertEq(_updatedAt, block.timestamp);

    // FixedPriceAggregators are deployed to the same address on different chains.
    vm.chainId(_chainId);
    AggregatorV3Interface _oracleC = factory.deployFixedPriceAggregator(_price, _decimals);
    assertEq(_oracleA, _oracleC);
  }

  function testFuzz_DeployFixedPriceAggregatorDeploysToComputedAddress(
    int256 _price,
    uint8 _decimals
  ) public {
    AggregatorV3Interface _oracle = factory.deployFixedPriceAggregator(_price, _decimals);
    address _expectedAddress = factory.computeFixedPriceAggregatorAddress(_price, _decimals);
    assertEq(_expectedAddress, address(_oracle));
  }
}
