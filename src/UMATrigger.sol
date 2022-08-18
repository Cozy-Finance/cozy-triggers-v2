// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "uma-protocol/packages/core/contracts/oracle/interfaces/FinderInterface.sol";
import "uma-protocol/packages/core/contracts/oracle/interfaces/OptimisticOracleV2Interface.sol";
import 'src/abstract/BaseTrigger.sol';
import "src/lib/SafeTransferLib.sol";

/**
 * @notice This is an automated trigger contract which will move markets into a
 * TRIGGERED state in the event that the UMA Optimistic Oracle answers "YES" to
 * a provided query, e.g. "Was protocol ABCD hacked on or after block 42". More
 * information about UMA oracles and the lifecycle of queries can be found here:
 * https://docs.umaproject.org/.
 * @dev The high-level lifecycle of a UMA request is as follows:
 *   - someone asks a question of the oracle and provides a reward for someone
 *     to answer it
 *   - users of the UMA prediction market view the question (usually here:
 *     https://oracle.umaproject.org/)
 *   - someone proposes an answer to the question in hopes of claiming the
 *     reward`
 *   - users of UMA see the proposed answer and have a chance to dispute it
 *   - there is a finite period of time within which to dispute the answer
 *   - if the answer is not disputed during this period, the oracle finalizes
 *     the answer and the proposer gets the reward
 *   - if the answer is disputed, the question is sent to the DVM (Data
 *     Verification Mechanism) in which UMA token holders vote on who is right
 * There are four essential players in the above process:
 *   1. Requester: the account that is asking the oracle a question.
 *   2. Proposer: the account that submits an answer to the question.
 *   3. Disputer: the account (if any) that disagrees with the proposed answer.
 *   4. The DVM: a DAO that is the final arbiter of disputed proposals.
 * This trigger plays the first role in this lifecycle. It submits a request for
 * an answer to a yes-or-no question (the query) to the Optimistic Oracle.
 * Questions need to be phrased in such a way that if a "Yes" answer is given
 * to them, then this contract will go into a TRIGGERED state and p-token
 * holders will be able to claim the protection that they purchased. For
 * example, if you wanted to create a market selling protection for Compound
 * yeild, you might deploy a UMATrigger with a query like "Was Compound hacked
 * after block X?" If the oracle responds with a "Yes" answer, this contract
 * would move the associated market into the TRIGGERED state and people who had
 * purchased protection from that market would get paid out.
 *   But what if Compound hasn't been hacked? Can't someone just respond "No" to
 * the trigger's query? Wouldn't that be the right answer and wouldn't it mean
 * the end of the query lifecycle? Yes. For this exact reason, we have enabled
 * callbacks (see the `priceProposed` function) which will revert in the event
 * that someone attempts to propose a negative answer to the question. We want
 * the queries to remain open indefinitely until there is a positive answer,
 * i.e. "Yes, there was a hack". **This should be communicated in the query text.**
 *   In the event that a YES answer to a query is disputed and the DVM sides
 * with the disputer (i.e. a NO answer), we immediately re-submit the query to
 * the DVM through another callback (see `priceSettled`). In this way, our query
 * will always be open with the oracle. If/when the event that we are concerned
 * with happens the trigger will immediately be notified.
 */
contract UMATrigger is BaseTrigger {
  using SafeTransferLib for IERC20;

  /// @notice The type of query that will be submitted to the oracle.
  bytes32 public constant queryIdentifier = bytes32("YES_OR_NO_QUERY");

  /// @notice The UMA contract used to lookup the UMA Optimistic Oracle.
  FinderInterface public immutable oracleFinder;

  /// @notice The identifier used to lookup the UMA Optimistic Oracle with the finder.
  bytes32 internal constant ORACLE_LOOKUP_IDENTIFIER = bytes32("OptimisticOracleV2");

  /// @notice The query that is sent to the UMA Optimistic Oracle for evaluation.
  /// It should be phrased so that only a positive answer is appropriate, e.g.
  /// "Was protocol ABCD hacked on or after block number 42". Negative answers
  /// are disallowed so that queries can remain open in UMA until the events we
  /// care about happen, if ever.
  string public query;

  /// @notice The token used to pay the reward to users that propose answers to the query.
  IERC20 public immutable rewardToken;

  /// @notice The amount of `rewardToken` that must be staked by a user wanting
  /// to propose or dispute an answer to the query. See UMA's price dispute
  /// workflow for more information. It's recommended that the bond amount be a
  /// significant value to deter addresses from proposing malicious, false, or
  /// otherwise self-interested answers to the query.
  uint256 public immutable bondAmount;

  /// @notice The window of time in seconds within which a proposed answer may
  /// be disputed. See UMA's "customLiveness" setting for more information. It's
  /// recommended that the dispute window be fairly long (12-24 hours), given
  /// the difficulty of assessing expected queries (e.g. "Was protocol ABCD
  /// hacked") and the amount of funds potentially at stake.
  uint256 public immutable proposalDisputeWindow;

  /// @notice The most recent timestamp that the query was submitted to the UMA oracle.
  uint256 public requestTimestamp;

  /// @notice Whether or not this trigger will enter the TRIGGERED state the
  /// next time `runProgrammaticCheck` is called.
  bool public shouldTrigger;

  /// @dev Thrown when a negative answer is proposed to the submitted query.
  error InvalidProposal();

  /// @dev Thrown when the trigger attempts to settle an unsettleable UMA request.
  error Unsettleable();

  /// @dev UMA expects answers to be denominated as wads. So, e.g., a p3 answer
  /// of 0.5 would be represented as 0.5e18.
  int256 internal constant AFFIRMATIVE_ANSWER = 1e18;

  constructor(
    IManager _manager,
    FinderInterface _oracleFinder,
    string memory _query,
    IERC20 _rewardToken,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) BaseTrigger(_manager) {
    oracleFinder = _oracleFinder;
    query = _query;
    rewardToken = _rewardToken;
    bondAmount = _bondAmount;
    proposalDisputeWindow = _proposalDisputeWindow;

    _submitRequestToOracle();
  }

  /// @notice Submits the trigger query to the UMA Optimistic Oracle for evaluation.
  function _submitRequestToOracle(OptimisticOracleV2Interface _oracle) internal {
    uint256 _rewardAmount = rewardToken.balanceOf(address(this));
    rewardToken.approve(address(_oracle), _rewardAmount);
    requestTimestamp = block.timestamp;

    // The UMA function for submitting a query to the oracle is `requestPrice`
    // even though not all queries are price queries. Another name for this
    // function might have been `requestAnswer`.
    _oracle.requestPrice(
      queryIdentifier,
      requestTimestamp,
      bytes(query),
      rewardToken,
      _rewardAmount
    );

    // Set this as an event-based query so that no one can propose the "too
    // soon" answer and so that we automatically get the reward back if there
    // is a dispute. This allows us to re-query the oracle for ~free.
    _oracle.setEventBased(queryIdentifier, requestTimestamp, bytes(query));

    // Set the amount of rewardTokens that have to be staked in order to answer
    // the query or dispute an answer to the query.
    _oracle.setBond(queryIdentifier, requestTimestamp, bytes(query), bondAmount);

    // Set the proposal dispute window -- i.e. how long people have to challenge
    // and answer to the query.
    _oracle.setCustomLiveness(queryIdentifier, requestTimestamp, bytes(query), proposalDisputeWindow);

    // We want to be notified by the UMA oracle when answers and proposed and
    // when answers are confirmed/settled.
    _oracle.setCallbacks(
      queryIdentifier,
      requestTimestamp,
      bytes(query),
      true,  // Enable the answer-proposed callback.
      false, // Don't enable the answer-disputed callback.
      true   // Enable the answer-settled callback.
    );
  }

  function _submitRequestToOracle() internal {
    _submitRequestToOracle(getOracle());
  }

  /// @notice UMA callback for proposals. This function is called by the UMA
  /// oracle when a new answer is proposed for the query. Its only purpose is to
  /// prevent people from proposing negative answers and prematurely closing our
  /// queries. For example, if our query were something like "Has Compound been
  /// hacked since block X?" the correct answer could easily be "No" right now.
  /// But we we don't care if the answer is "No". The trigger only cares when
  /// hacks *actually happen*. So we revert when people try to submit negative
  /// answers, as negative answers that are undisputed would resolve our query
  /// and we'd have to pay a new reward to resubmit.
  /// @param _identifier price identifier being requested.
  /// @param _timestamp timestamp of the original query request.
  /// @param _ancillaryData ancillary data of the original query request.
  function priceProposed(
    bytes32 _identifier,
    uint256 _timestamp,
    bytes memory _ancillaryData
  ) external {
    OptimisticOracleV2Interface _oracle = getOracle();
    // Besides confirming that the caller is the UMA oracle, we also confirm
    // that the args passed in match the args used to submit our latest query to
    // UMA. This is done as an extra safeguard that we are responding to an
    // event related to the specific query we care about. It is possible, for
    // example, for multiple queries to be submitted to the oracle that differ
    // only with respect to timestamp. So we want to make sure we know which
    // query the oracle has settled on an answer to.
    if (
      msg.sender != address(_oracle) ||
      _timestamp != requestTimestamp ||
      keccak256(_ancillaryData) != keccak256(bytes(query)) ||
      _identifier != queryIdentifier
    ) revert Unauthorized();

    OptimisticOracleV2Interface.Request memory _umaRequest;
    _umaRequest = _oracle.getRequest(address(this), _identifier, _timestamp, _ancillaryData);

    // Revert if the answer was anything other than "YES". We don't want to be told
    // that a hack/exploit has *not* happened yet, or it cannot be determined, etc.
    if (_umaRequest.proposedPrice != AFFIRMATIVE_ANSWER) revert InvalidProposal();

    // Freeze the market and set so that funds cannot be withdrawn, since
    // there's now a real possibility that we are going to trigger.
    _updateTriggerState(CState.FROZEN);
  }

  /// @notice UMA callback for settlement. This code is run when the protocol
  /// has confirmed an answer to the query.
  /// @dev This callback is kept intentionally lean, as we don't want to risk
  /// reverting and blocking settlement.
  /// @param _identifier price identifier being requested.
  /// @param _timestamp timestamp of the original query request.
  /// @param _ancillaryData ancillary data of the original query request.
  /// @param _answer the oracle's answer to the query.
  function priceSettled(
    bytes32 _identifier,
    uint256 _timestamp,
    bytes memory _ancillaryData,
    int256 _answer
  ) external {
    OptimisticOracleV2Interface _oracle = getOracle();

    // See `priceProposed` for why we authorize callers in this way.
    if (
      msg.sender != address(_oracle) ||
      _timestamp != requestTimestamp ||
      keccak256(_ancillaryData) != keccak256(bytes(query)) ||
      _identifier != queryIdentifier
    ) revert Unauthorized();

    if (_answer == AFFIRMATIVE_ANSWER) {
      shouldTrigger = true;
    } else {
      // If the answer was not affirmative, i.e. "Yes, the protocol was hacked",
      // the trigger should return to the ACTIVE state. And we need to resubmit our
      // query so that we are informed if the event we care about happens in the
      // future.
      _updateTriggerState(CState.ACTIVE);
      _submitRequestToOracle(_oracle);
    }
  }

  /// @notice This function attempts to confirm and finalize (i.e. "settle") the
  /// answer to the query with the UMA oracle. It reverts with Unsettleable if
  /// it cannot settle the query, but does NOT revert if the oracle has already
  /// settled the query on its own. If the oracle's answer is an
  /// AFFIRMATIVE_ANSWER, this function will toggle the trigger and update
  /// associated markets.
  function runProgrammaticCheck() external returns (CState) {
    // Rather than revert when triggered, we simply return the state and exit.
    // Both behaviors are acceptable, but returning is friendlier to the caller
    // as they don't need to handle a revert and can simply parse the
    // transaction's logs to know if the call resulted in a state change.
    if (state == CState.TRIGGERED) return state;

    OptimisticOracleV2Interface _oracle = getOracle();
    bool _oracleHasPrice = _oracle.hasPrice(
      address(this),
      queryIdentifier,
      requestTimestamp,
      bytes(query)
    );
    if (!_oracleHasPrice) revert Unsettleable();
    OptimisticOracleV2Interface.Request memory _umaRequest = _oracle.getRequest(
      address(this),
      queryIdentifier,
      requestTimestamp,
      bytes(query)
    );
    if (!_umaRequest.settled) {
      _oracle.settle(
        address(this),
        queryIdentifier,
        requestTimestamp,
        bytes(query)
      );
    }

    if (shouldTrigger) {
      // Give the reward balance to the caller to make up for gas costs and
      // incentivize keeping markets in line with trigger state.
      uint256 _rewardBalance = rewardToken.balanceOf(address(this));
      if (_rewardBalance > 0) rewardToken.safeTransfer(msg.sender, _rewardBalance);

      return _updateTriggerState(CState.TRIGGERED);
    }
    return state;
  }

  /// @notice The UMA Optimistic Oracle queried by this trigger.
  function getOracle() public view returns (OptimisticOracleV2Interface) {
    return OptimisticOracleV2Interface(
      oracleFinder.getImplementationAddress(ORACLE_LOOKUP_IDENTIFIER)
    );
  }
}
