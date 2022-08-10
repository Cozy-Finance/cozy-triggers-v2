// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "uma-protocol/packages/core/contracts/oracle/interfaces/OracleAncillaryInterface.sol";
import "src/UMATriggerFactory.sol";
import "test/utils/TriggerTestSetup.sol";

contract DeployTriggerSharedTest is TriggerTestSetup {
  UMATriggerFactory factory;
  uint256 forkId;
  address umaOracleFinder;
  OptimisticOracleV2Interface umaOracle;
  IERC20 rewardToken;

  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed umaOracleFinder,
    string query,
    address indexed rewardToken,
    uint256 rewardAmount,
    uint256 bondAmount,
    uint256 proposalDisputeWindow
  );

  function setUp() public virtual override {
    super.setUp();
  }

  function testFork_DeployTriggerDeploysANewTrigger(
    uint96 _rewardAmount,
    uint96 _bondAmount,
    uint32 _proposalDisputeWindow
  ) internal {
    vm.selectFork(forkId);

    address _computedTriggerAddress = factory.computeTriggerAddress(
      "Has Terra been hacked?",
      rewardToken,
      address(this),
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow,
      0 // This is the first trigger of its kind being created.
    );

    deal(address(rewardToken), address(this), _rewardAmount);
    rewardToken.approve(_computedTriggerAddress, _rewardAmount);

    vm.expectEmit(true, true, true, true);
    emit TriggerDeployed(
      address(_computedTriggerAddress),
      factory.triggerConfigId(
        "Has Terra been hacked?",
        rewardToken,
        _rewardAmount,
        _bondAmount,
        _proposalDisputeWindow
      ),
      address(umaOracleFinder),
      "Has Terra been hacked?",
      address(rewardToken),
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow
    );

    UMATrigger _trigger = factory.deployTrigger(
      "Has Terra been hacked?",
      rewardToken,
      address(this),
      uint256(_rewardAmount),
      _bondAmount,
      _proposalDisputeWindow
    );

    assertEq(address(_trigger), _computedTriggerAddress);
    assertEq(_trigger.state(), CState.ACTIVE);
    assertEq(_trigger.getSets().length, 0);
    assertEq(_trigger.manager(), factory.manager());
    assertEq(address(_trigger.oracleFinder()), address(factory.oracleFinder()));
    assertEq(address(_trigger.getOracle()), address(umaOracle));
    assertEq(_trigger.query(), "Has Terra been hacked?");
    assertEq(address(_trigger.rewardToken()), address(rewardToken));
    assertEq(_trigger.bondAmount(), _bondAmount);
    assertEq(_trigger.proposalDisputeWindow(), _proposalDisputeWindow);
  }

  function _getDVM() internal view returns (OracleAncillaryInterface) {
    return OracleAncillaryInterface(
      FinderInterface(umaOracleFinder).getImplementationAddress(bytes32("Oracle"))
    );
  }

  function testFork_DeployTriggerCreatesAUMARequest(
    uint96 _rewardAmount,
    uint96 _bondAmount,
    uint32 _proposalDisputeWindow
  ) internal {
    vm.selectFork(forkId);

    address _computedTriggerAddress = factory.computeTriggerAddress(
      "Has Terra been hacked?",
      rewardToken,
      address(this),
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow,
      0 // This is the first trigger of its kind being created.
    );

    deal(address(rewardToken), address(this), _rewardAmount);
    rewardToken.approve(_computedTriggerAddress, _rewardAmount);

    UMATrigger _trigger = factory.deployTrigger(
      "Has Terra been hacked?",
      rewardToken,
      address(this),
      uint256(_rewardAmount),
      _bondAmount,
      _proposalDisputeWindow
    );

    uint256 _queryTimestamp = _trigger.requestTimestamp();
    OptimisticOracleV2Interface.Request memory _umaRequest;
    _umaRequest = umaOracle.getRequest(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?")
    );

    assertEq(_umaRequest.proposer, address(0)); // No answer proposed yet.
    assertEq(_umaRequest.disputer, address(0)); // No answer to dispute yet.
    assertEq(address(_umaRequest.currency), address(rewardToken));
    assertEq(_umaRequest.settled, false);
    assertEq(_umaRequest.requestSettings.eventBased, true);
    assertEq(_umaRequest.requestSettings.refundOnDispute, true);
    assertEq(_umaRequest.requestSettings.callbackOnPriceProposed, true);
    assertEq(_umaRequest.requestSettings.callbackOnPriceDisputed, false);
    assertEq(_umaRequest.requestSettings.callbackOnPriceSettled, true);
    assertEq(_umaRequest.requestSettings.bond, _bondAmount);
    assertEq(_umaRequest.requestSettings.customLiveness, _proposalDisputeWindow);
    assertEq(_umaRequest.reward, _rewardAmount);
    assertEq(_umaRequest.expirationTime, 0); // No expiration time was set.

    // Fund the account and approve the umaOracle for the bondAmount.
    deal(address(rewardToken), address(this), _bondAmount + _umaRequest.finalFee);
    rewardToken.approve(address(umaOracle), _bondAmount + _umaRequest.finalFee);

    // Attempt to propose a negative answer, it should not succeed b/c the
    // trigger reverts in a callback.
    vm.expectRevert(UMATrigger.InvalidProposal.selector);
    umaOracle.proposePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?"),
      0 // A negative answer.
    );
    _umaRequest = umaOracle.getRequest(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?")
    );
    assertEq(_umaRequest.proposer, address(0));
    assertEq(_umaRequest.proposedPrice, 0);

    // Propose a positive answer, it will succeed.
    umaOracle.proposePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?"),
      1 // A positive answer.
    );

    // Jump ahead to the very end of the dispute window.
    vm.warp(block.timestamp + _proposalDisputeWindow - 1);

    // Have someone else dispute the answer.
    deal(address(rewardToken), address(42), _bondAmount + _umaRequest.finalFee);
    vm.startPrank(address(42));
    rewardToken.approve(address(umaOracle), _bondAmount + _umaRequest.finalFee);
    umaOracle.disputePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?")
    );
    vm.stopPrank();

    // Settle and have the DVM side with the disputer: there was no hack.
    vm.mockCall(
      address(_getDVM()),
      abi.encodeWithSelector(OracleAncillaryInterface.hasPrice.selector),
      abi.encode(true)
    );
    vm.mockCall(
      address(_getDVM()),
      abi.encodeWithSelector(OracleAncillaryInterface.getPrice.selector),
      abi.encode(0) // The DVM returns a settled price of 0 == "NO".
    );
    umaOracle.settle(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?")
    );
    vm.clearMockedCalls();

    // A new request should have been issued with the existing reward.
    // There is a new timestamp because there is a new query.
    assertLt(_queryTimestamp, _trigger.requestTimestamp());
    _queryTimestamp = _trigger.requestTimestamp();
    _umaRequest = umaOracle.getRequest(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?")
    );
    assertEq(_umaRequest.settled, false);

    // Propose a positive answer to the new query.
    deal(address(rewardToken), address(this), _bondAmount + _umaRequest.finalFee);
    rewardToken.approve(address(umaOracle), _bondAmount + _umaRequest.finalFee);
    umaOracle.proposePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?"),
      1 // A positive answer.
    );

    // Warp past the liveness interval to avoid having to go through the DVM again.
    vm.warp(block.timestamp + _proposalDisputeWindow);

    // Settle the request.
    assertEq(_umaRequest.settled, false);
    umaOracle.settle(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?")
    );
    _umaRequest = umaOracle.getRequest(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?")
    );
    assertEq(_umaRequest.settled, true);
    assertEq(_trigger.shouldTrigger(), true);

    // Run the trigger programmatic check.
    assertEq(_trigger.runProgrammaticCheck(), CState.TRIGGERED);
  }

  function testFork_DeployTriggerRefundsWhoeverCallsRunProgrammaticTrigger(
    uint96 _rewardAmount,
    uint96 _bondAmount,
    uint32 _proposalDisputeWindow
  ) internal {
    vm.selectFork(forkId);

    address _computedTriggerAddress = factory.computeTriggerAddress(
      "Has Mt Gox been hacked?",
      rewardToken,
      address(this),
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow,
      0 // This is the first trigger of its kind being created.
    );

    deal(address(rewardToken), address(this), _rewardAmount);
    assertEq(rewardToken.allowance(address(this), _computedTriggerAddress), 0);
    rewardToken.approve(_computedTriggerAddress, _rewardAmount);

    UMATrigger _trigger = factory.deployTrigger(
      "Has Mt Gox been hacked?",
      rewardToken,
      address(this),
      uint256(_rewardAmount),
      _bondAmount,
      _proposalDisputeWindow
    );
    // Ensure that the entire allowance has been spent.
    assertEq(rewardToken.allowance(address(this), _computedTriggerAddress), 0);

    uint256 _queryTimestamp = block.timestamp;
    OptimisticOracleV2Interface.Request memory _umaRequest;
    _umaRequest = umaOracle.getRequest(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Mt Gox been hacked?")
    );

    // Have someone propose a positive answer.
    deal(address(rewardToken), address(0xBEEF), _bondAmount + _umaRequest.finalFee);
    vm.startPrank(address(0xBEEF));
    rewardToken.approve(address(umaOracle), _bondAmount + _umaRequest.finalFee);
    umaOracle.proposePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Mt Gox been hacked?"),
      1 // A positive answer.
    );
    vm.stopPrank();

    // Have someone else dispute the answer.
    deal(address(rewardToken), address(42), _bondAmount + _umaRequest.finalFee);
    vm.startPrank(address(42));
    rewardToken.approve(address(umaOracle), _bondAmount + _umaRequest.finalFee);
    umaOracle.disputePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Mt Gox been hacked?")
    );
    vm.stopPrank();

    // Settle and have the DVM side with the proposer: there was indeed a hack.
    assertEq(_trigger.shouldTrigger(), false);
    vm.mockCall(
      address(_getDVM()),
      abi.encodeWithSelector(OracleAncillaryInterface.hasPrice.selector),
      abi.encode(true)
    );
    vm.mockCall(
      address(_getDVM()),
      abi.encodeWithSelector(OracleAncillaryInterface.getPrice.selector),
      abi.encode(1) // The DVM returns a settled price of 1 == "YES".
    );
    umaOracle.settle(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Mt Gox been hacked?")
    );
    vm.clearMockedCalls();
    assertEq(_trigger.shouldTrigger(), true);

    // Run the trigger programmatic check.
    // The caller should receive the token balance as a reward for calling it.
    vm.startPrank(address(0xC0FFEE)); // Just a random caller.
    assertEq(rewardToken.balanceOf(address(0xC0FFEE)), 0);
    assertEq(_trigger.runProgrammaticCheck(), CState.TRIGGERED);
    assertEq(_trigger.state(), CState.TRIGGERED);
    assertEq(rewardToken.balanceOf(address(0xC0FFEE)), _rewardAmount);
  }
}

contract DeployTriggerMainnetTest is DeployTriggerSharedTest {
  function setUp() public override {
    super.setUp();
    manager = IManager(address(42));

    uint256 mainnetForkBlock = 15238191; // The mainnet block number at the time this test was written.
    forkId = vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), mainnetForkBlock);

    // https://github.com/UMAprotocol/protocol/blob/f011a6531fbd7c09d22aa46ef04828cf98f7f854/packages/core/networks/1.json
    umaOracleFinder = 0x40f941E48A552bF496B154Af6bf55725f18D77c3;
    umaOracle = OptimisticOracleV2Interface(0xA0Ae6609447e57a42c51B50EAe921D701823FFAe);
    rewardToken = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC on mainnet,

    factory = new UMATriggerFactory(manager, FinderInterface(umaOracleFinder));
  }

  function testFork1_DeployTriggerDeploysANewTrigger() public {
    testFork_DeployTriggerDeploysANewTrigger(42, 2000, 24 hours);
  }
  function testFork1_DeployTriggerCreatesAUMARequest() public {
    testFork_DeployTriggerCreatesAUMARequest(42, 2000, 24 hours);
  }
  function testFork1_DeployTriggerRefundsTriggerCaller() public {
    testFork_DeployTriggerRefundsWhoeverCallsRunProgrammaticTrigger(42, 2000, 24 hours);
  }
}
contract DeployTriggerOptimismTest is DeployTriggerSharedTest {
  function setUp() public override {
    super.setUp();
    manager = IManager(address(42));

    // We don't have a fork block since Optimism has no blocks.
    // TODO how to pin tests for better performance?
    forkId = vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"));

    // https://github.com/UMAprotocol/protocol/blob/f011a6531fbd7c09d22aa46ef04828cf98f7f854/packages/core/networks/10.json
    umaOracleFinder = 0x278d6b1aA37d09769E519f05FcC5923161A8536D;
    umaOracle = OptimisticOracleV2Interface(0x255483434aba5a75dc60c1391bB162BCd9DE2882);
    rewardToken = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607); // USDC on Optimism.

    factory = new UMATriggerFactory(manager, FinderInterface(umaOracleFinder));
  }

  function testFork10_DeployTriggerDeploysANewTrigger() public {
    testFork_DeployTriggerDeploysANewTrigger(42, 2000, 24 hours);
  }
  function testFork10_DeployTriggerCreatesAUMARequest() public {
    testFork_DeployTriggerCreatesAUMARequest(42, 2000, 24 hours);
  }
  function testFork10_DeployTriggerRefundsTriggerCaller() public {
    testFork_DeployTriggerRefundsWhoeverCallsRunProgrammaticTrigger(42, 2000, 24 hours);
  }
}
