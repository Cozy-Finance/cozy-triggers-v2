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

  int256 constant AFFIRMATIVE_ANSWER = 1e18;
  int256 constant NEGATIVE_ANSWER = 0e18;
  int256 constant INDETERMINATE_ANSWER = 0.5e18;
  int256 constant TOO_EARLY_ANSWER = type(int256).min;

  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed umaOracleFinder,
    string query,
    address indexed rewardToken,
    uint256 rewardAmount,
    uint256 bondAmount,
    uint256 proposalDisputeWindow,
    string name,
    string description,
    string logoURI
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
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow,
      0 // This is the first trigger of its kind being created.
    );

    deal(address(rewardToken), address(this), _rewardAmount);
    rewardToken.approve(address(factory), _rewardAmount);

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
      _proposalDisputeWindow,
      "Terra hack trigger",
      "A trigger that will toggle if Terra is hacked",
      "https://via.placeholder.com/150"
    );

    UMATrigger _trigger = factory.deployTrigger(
      "Has Terra been hacked?",
      rewardToken,
      uint256(_rewardAmount),
      _bondAmount,
      _proposalDisputeWindow,
      UMATriggerFactory.TriggerMetadata(
        "Terra hack trigger",
        "A trigger that will toggle if Terra is hacked",
        "https://via.placeholder.com/150"
      )
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

  function _settleQueryViaDVM(
    int256 _answer,
    address _requester,
    uint256 _queryTimestamp,
    bytes memory _query
  ) public {
    // Warp forward in time so that if a new query is issued as a result of
    // settlement it will not have the same block.timestamp as the origainl,
    // which will cause the request to fail.
    vm.warp(block.timestamp + 42);

    vm.mockCall(
      address(_getDVM()),
      abi.encodeWithSelector(OracleAncillaryInterface.hasPrice.selector),
      abi.encode(true)
    );
    vm.mockCall(
      address(_getDVM()),
      abi.encodeWithSelector(OracleAncillaryInterface.getPrice.selector),
      abi.encode(_answer)
    );
    umaOracle.settle(
      _requester,
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      _query
    );
    vm.clearMockedCalls();
  }

  function testFork_RunProgrammaticCheckSettlesRequests(
    int256 _settledAnswer,
    bool _isDisputed,
    bool _isExternallySettled
  ) internal {
    vm.selectFork(forkId);
    uint256 _rewardAmount = 42;
    uint256 _bondAmount = 4200;
    uint256 _proposalDisputeWindow = 2 days;
    string memory _query = "q: Has protocol XYZ been hacked?";

    deal(address(rewardToken), address(this), _rewardAmount);
    rewardToken.approve(address(factory), _rewardAmount);

    UMATrigger _trigger = factory.deployTrigger(
      _query,
      rewardToken,
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow,
      UMATriggerFactory.TriggerMetadata(
        "XYZ hack trigger",
        "A trigger that will toggle if XYZ is hacked",
        "https://via.placeholder.com/150"
      )
    );

    uint256 _queryTimestamp = _trigger.requestTimestamp();
    OptimisticOracleV2Interface.Request memory _umaRequest;
    _umaRequest = umaOracle.getRequest(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes(_query)
    );

    // Fund the account and approve the umaOracle for the bondAmount so that an
    // answer can be proposed.
    deal(address(rewardToken), address(this), _bondAmount + _umaRequest.finalFee);
    rewardToken.approve(address(umaOracle), _bondAmount + _umaRequest.finalFee);

    if (_settledAnswer != AFFIRMATIVE_ANSWER) {
      // Attempt to propose a non-YES answer, it should not succeed b/c the
      // trigger reverts in a callback.
      if ( _settledAnswer == TOO_EARLY_ANSWER) {
        vm.expectRevert("Cannot propose 'too early'");
      } else { vm.expectRevert(UMATrigger.InvalidProposal.selector);}
      umaOracle.proposePrice(
        address(_trigger),
        bytes32("YES_OR_NO_QUERY"),
        _queryTimestamp,
        bytes(_query),
        _settledAnswer
      );

      // Confirm that no answer succeeded in being proposed.
      _umaRequest = umaOracle.getRequest(
        address(_trigger),
        bytes32("YES_OR_NO_QUERY"),
        _queryTimestamp,
        bytes(_query)
      );
      assertEq(_umaRequest.proposer, address(0));
      assertEq(_umaRequest.proposedPrice, 0);
    }

    // We have to propose a positive answer to move the request lifecycle
    // forward -- only positive answers are accepted as proposals.
    umaOracle.proposePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes(_query),
      AFFIRMATIVE_ANSWER
    );

    // Try calling runProgrammaticCheck. It should revert because the request
    // isn't settleable yet.
    vm.expectRevert(UMATrigger.Unsettleable.selector);
    _trigger.runProgrammaticCheck();
    assertEq(_trigger.state(), CState.FROZEN);

    if (_isDisputed || _settledAnswer != AFFIRMATIVE_ANSWER) {
      // Dispute the answer.
      deal(address(rewardToken), address(0xBEEF), _bondAmount + _umaRequest.finalFee);
      vm.startPrank(address(0xBEEF));
      rewardToken.approve(address(umaOracle), _bondAmount + _umaRequest.finalFee);
      umaOracle.disputePrice(
        address(_trigger),
        bytes32("YES_OR_NO_QUERY"),
        _queryTimestamp,
        bytes(_query)
      );
      vm.stopPrank();

      // Have the DVM resolve to the _settledAnswer.
      vm.warp(block.timestamp + _proposalDisputeWindow);
      vm.mockCall(
        address(_getDVM()),
        abi.encodeWithSelector(OracleAncillaryInterface.hasPrice.selector),
        abi.encode(true)
      );
      vm.mockCall(
        address(_getDVM()),
        abi.encodeWithSelector(OracleAncillaryInterface.getPrice.selector),
        abi.encode(_settledAnswer)
      );
    } else {
      // There is no need to dispute or appeal to the DVM; just run out the
      // dispute window and UMA will settle on the proposed answer.
      vm.warp(block.timestamp + _proposalDisputeWindow);
    }

    if (_isExternallySettled) {
      assertEq(_trigger.shouldTrigger(), false);
      // Call settle on the UMA contract.
      umaOracle.settle(
        address(_trigger),
        bytes32("YES_OR_NO_QUERY"),
        _queryTimestamp,
        bytes(_query)
      );
      if (_settledAnswer == AFFIRMATIVE_ANSWER) {
        assertEq(_trigger.shouldTrigger(), true);
        // A new query should NOT have been submitted;
        assertEq(_trigger.requestTimestamp(), _queryTimestamp);
      } else {
        // The market should return to the ACTIVE state.
        assertEq(_trigger.state(), CState.ACTIVE);
        // A new query SHOULD have been submitted;
        assertGt(_trigger.requestTimestamp(), _queryTimestamp);
      }
    }

    // A random user calls the programmatic check;
    uint256 _initSettlerBalance = rewardToken.balanceOf(address(0xC0FFEE));
    // The call will revert as unsettleable if the settled answer was not "YES",
    // as a new query will have been submitted. The trigger checks on the
    // status of the latest trigger in `runProgrammaticCheck`.
    if (_settledAnswer != AFFIRMATIVE_ANSWER) vm.expectRevert(UMATrigger.Unsettleable.selector);
    vm.prank(address(0xC0FFEE));
    _trigger.runProgrammaticCheck();

    if (_settledAnswer == AFFIRMATIVE_ANSWER) {
      assertEq(_trigger.state(), CState.TRIGGERED);
      if (_isDisputed) {
        // The reward was sent to the caller.
        assertEq(
          rewardToken.balanceOf(address(0xC0FFEE)),
          _initSettlerBalance + _rewardAmount
        );
      }
    } else {
      // The market should return to the ACTIVE state.
      assertEq(_trigger.state(), CState.ACTIVE);
      // A new query should have been issued to UMA at this point.
      assertGt(_trigger.requestTimestamp(), _queryTimestamp);
    }
  }

  function testFork_DeployTriggerCreatesAUMARequest(
    uint96 _rewardAmount,
    uint96 _bondAmount,
    uint32 _proposalDisputeWindow
  ) internal {
    vm.selectFork(forkId);

    deal(address(rewardToken), address(this), _rewardAmount);
    rewardToken.approve(address(factory), _rewardAmount);

    UMATrigger _trigger = factory.deployTrigger(
      "Has Terra been hacked?",
      rewardToken,
      uint256(_rewardAmount),
      _bondAmount,
      _proposalDisputeWindow,
      UMATriggerFactory.TriggerMetadata(
        "Terra hack trigger",
        "A trigger that will toggle if Terra is hacked",
        "https://via.placeholder.com/150"
      )
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

    // Propose a positive answer, it will succeed.
    umaOracle.proposePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has Terra been hacked?"),
      AFFIRMATIVE_ANSWER // A positive answer.
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
    _settleQueryViaDVM(
      NEGATIVE_ANSWER,
      address(_trigger),
      _queryTimestamp,
      bytes("Has Terra been hacked?")
    );

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
      AFFIRMATIVE_ANSWER // A positive answer.
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

    deal(address(rewardToken), address(this), _rewardAmount);
    assertEq(rewardToken.allowance(address(this), address(factory)), 0);
    rewardToken.approve(address(factory), _rewardAmount);

    UMATrigger _trigger = factory.deployTrigger(
      "Has Mt Gox been hacked?",
      rewardToken,
      uint256(_rewardAmount),
      _bondAmount,
      _proposalDisputeWindow,
      UMATriggerFactory.TriggerMetadata(
        "Mt. Gox hack trigger",
        "A trigger that will toggle if Mt. Gox is hacked",
        "https://via.placeholder.com/150"
      )
    );
    // Ensure that the entire allowance has been spent.
    assertEq(rewardToken.allowance(address(this), address(factory)), 0);

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
      AFFIRMATIVE_ANSWER // A positive answer.
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
    _settleQueryViaDVM(
      AFFIRMATIVE_ANSWER, // The DVM returns a settled price of 1 == "YES".
      address(_trigger),
      _queryTimestamp,
      bytes("Has Mt Gox been hacked?")
    );
    assertEq(_trigger.shouldTrigger(), true);

    // Run the trigger programmatic check.
    // The caller should receive the token balance as a reward for calling it.
    vm.startPrank(address(0xC0FFEE)); // Just a random caller.
    assertEq(rewardToken.balanceOf(address(0xC0FFEE)), 0);
    assertEq(_trigger.runProgrammaticCheck(), CState.TRIGGERED);
    assertEq(_trigger.state(), CState.TRIGGERED);
    assertEq(rewardToken.balanceOf(address(0xC0FFEE)), _rewardAmount);
  }

  function testFork_TriggerFreezesMarketsWhenAnswersAreProposed(
    uint96 _rewardAmount,
    uint96 _bondAmount,
    uint32 _proposalDisputeWindow
  ) internal {
    vm.selectFork(forkId);

    deal(address(rewardToken), address(this), _rewardAmount);
    rewardToken.approve(address(factory), _rewardAmount);

    UMATrigger _trigger = factory.deployTrigger(
      "Has USDT been hacked?",
      rewardToken,
      uint256(_rewardAmount),
      _bondAmount,
      _proposalDisputeWindow,
      UMATriggerFactory.TriggerMetadata(
        "USDT hack trigger",
        "A trigger that will toggle if USDT is hacked",
        "https://via.placeholder.com/150"
      )
    );
    uint256 _queryTimestamp = block.timestamp;

    // A random user cannot just call the priceProposed callback and freeze the market.
    vm.expectRevert(BaseTrigger.Unauthorized.selector);
    _trigger.priceProposed(
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has USDT been hacked?")
    );
    assertEq(_trigger.state(), CState.ACTIVE);

    OptimisticOracleV2Interface.Request memory _umaRequest;
    _umaRequest = umaOracle.getRequest(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has USDT been hacked?")
    );

    // Have someone propose a positive answer.
    deal(address(rewardToken), address(0xBEEF), _bondAmount + _umaRequest.finalFee);
    vm.startPrank(address(0xBEEF));
    rewardToken.approve(address(umaOracle), _bondAmount + _umaRequest.finalFee);
    umaOracle.proposePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has USDT been hacked?"),
      AFFIRMATIVE_ANSWER // A positive answer.
    );
    vm.stopPrank();

    // The market should now be frozen so no one can withdraw funds.
    assertEq(_trigger.state(), CState.FROZEN);

    // Have someone else dispute the answer.
    deal(address(rewardToken), address(42), _bondAmount + _umaRequest.finalFee);
    vm.startPrank(address(42));
    rewardToken.approve(address(umaOracle), _bondAmount + _umaRequest.finalFee);
    umaOracle.disputePrice(
      address(_trigger),
      bytes32("YES_OR_NO_QUERY"),
      _queryTimestamp,
      bytes("Has USDT been hacked?")
    );
    vm.stopPrank();

    // Settle and have the DVM side with the disputer: there was no hack.
    _settleQueryViaDVM(
      NEGATIVE_ANSWER,
      address(_trigger),
      _queryTimestamp,
      bytes("Has USDT been hacked?")
    );

    // The market should now be back to active so that funds can be withdrawn.
    assertEq(_trigger.state(), CState.ACTIVE);
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
  function testFork1_TriggerFreezesMarketsWhenAnswersAreProposed() public {
    testFork_TriggerFreezesMarketsWhenAnswersAreProposed(42, 2000, 12 hours);
  }
  function testFork1_RunProgrammaticCheckSettlesRequests() public {
    //                                            oracle answer,   externally settled,  disputed
    testFork_RunProgrammaticCheckSettlesRequests( AFFIRMATIVE_ANSWER,   false,           false);
    testFork_RunProgrammaticCheckSettlesRequests( AFFIRMATIVE_ANSWER,   true,            false);
    testFork_RunProgrammaticCheckSettlesRequests( AFFIRMATIVE_ANSWER,   false,           true);
    testFork_RunProgrammaticCheckSettlesRequests( AFFIRMATIVE_ANSWER,   true,            true);
    testFork_RunProgrammaticCheckSettlesRequests( NEGATIVE_ANSWER,      false,           true);
    testFork_RunProgrammaticCheckSettlesRequests( NEGATIVE_ANSWER,      true,            true);
    testFork_RunProgrammaticCheckSettlesRequests( INDETERMINATE_ANSWER, false,           true);
    testFork_RunProgrammaticCheckSettlesRequests( INDETERMINATE_ANSWER, true,            true);
    testFork_RunProgrammaticCheckSettlesRequests( TOO_EARLY_ANSWER,     false,           true);
    testFork_RunProgrammaticCheckSettlesRequests( TOO_EARLY_ANSWER,     true,            true);
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
  function testFork10_TriggerFreezesMarketsWhenAnswersAreProposed() public {
    testFork_TriggerFreezesMarketsWhenAnswersAreProposed(42, 2000, 12 hours);
  }
  function testFork10_RunProgrammaticCheckSettlesRequests() public {
    //                                            oracle answer,   externally settled,  disputed
    testFork_RunProgrammaticCheckSettlesRequests( AFFIRMATIVE_ANSWER,   false,           false);
    testFork_RunProgrammaticCheckSettlesRequests( AFFIRMATIVE_ANSWER,   true,            false);
    testFork_RunProgrammaticCheckSettlesRequests( AFFIRMATIVE_ANSWER,   false,           true);
    testFork_RunProgrammaticCheckSettlesRequests( AFFIRMATIVE_ANSWER,   true,            true);
    testFork_RunProgrammaticCheckSettlesRequests( NEGATIVE_ANSWER,      false,           true);
    testFork_RunProgrammaticCheckSettlesRequests( NEGATIVE_ANSWER,      true,            true);
    testFork_RunProgrammaticCheckSettlesRequests( INDETERMINATE_ANSWER, false,           true);
    testFork_RunProgrammaticCheckSettlesRequests( INDETERMINATE_ANSWER, true,            true);
    testFork_RunProgrammaticCheckSettlesRequests( TOO_EARLY_ANSWER,     false,           true);
    testFork_RunProgrammaticCheckSettlesRequests( TOO_EARLY_ANSWER,     true,            true);
  }
}
