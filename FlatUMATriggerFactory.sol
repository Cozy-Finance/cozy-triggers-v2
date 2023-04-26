// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

// A named import is used to avoid identifier naming conflicts between IERC20 imports. solc throws a DeclarationError
// if an interface with the same name is imported twice in a file using different paths, even if they have the
// same implementation. For example, if a file in the cozy-v2-interfaces submodule that is imported in this project
// imports an IERC20 interface with "import src/interfaces/IERC20.sol;", but in this project we import the same
// interface with "import cozy-v2-interfaces/interfaces/IERC20.sol;", a DeclarationError will be thrown.

/**
 * @dev Interface for ERC20 tokens.
 */
interface IERC20 {
  /// @dev Emitted when the allowance of a `spender` for an `owner` is updated, where `amount` is the new allowance.
  event Approval(address indexed owner, address indexed spender, uint256 value);
  /// @dev Emitted when `amount` tokens are moved from `from` to `to`.
  event Transfer(address indexed from, address indexed to, uint256 value);

  /// @notice Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `holder`.
  function allowance(address owner, address spender) external view returns (uint256);
  /// @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
  function approve(address spender, uint256 amount) external returns (bool);
  /// @notice Returns the amount of tokens owned by `account`.
  function balanceOf(address account) external view returns (uint256);
  /// @notice Returns the decimal places of the token.
  function decimals() external view returns (uint8);
  /// @notice Sets `_value` as the allowance of `_spender` over `_owner`s tokens, given a signed approval from the
  /// owner.
  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    external;
  /// @notice Returns the name of the token.
  function name() external view returns (string memory);
  /// @notice Returns the symbol of the token.
  function symbol() external view returns (string memory);
  /// @notice Returns the amount of tokens in existence.
  function totalSupply() external view returns (uint256);
  /// @notice Moves `_amount` tokens from the caller's account to `_to`.
  function transfer(address to, uint256 amount) external returns (bool);
  /// @notice Moves `_amount` tokens from `_from` to `_to` using the allowance mechanism. `_amount` is then deducted
  /// from the caller's allowance.
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/d155ee8d58f96426f57c015b34dee8a410c1eacc/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
/// @dev Note that this version of solmate's SafeTransferLib uses our own IERC20 interface instead of solmate's ERC20. Cozy's ERC20 was modified
/// from solmate to use an initializer to support usage as a minimal proxy.
library SafeTransferLib {
  // --------------------------------
  // -------- ETH OPERATIONS --------
  // --------------------------------

  function safeTransferETH(address to, uint256 amount) internal {
    bool success;

    assembly {
      // Transfer the ETH and store if it succeeded or not.
      success := call(gas(), to, amount, 0, 0, 0, 0)
    }

    require(success, "ETH_TRANSFER_FAILED");
  }

  // ----------------------------------
  // -------- ERC20 OPERATIONS --------
  // ----------------------------------

  function safeTransferFrom(
    IERC20 token,
    address from,
    address to,
    uint256 amount
  ) internal {
    bool success;

    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
      mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
      mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

      success := and(
        // Set success to whether the call reverted, if not we check it either
        // returned exactly 1 (can't just be non-zero data), or had no return data.
        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
        // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
        // Counterintuitively, this call must be positioned second to the or() call in the
        // surrounding and() call or else returndatasize() will be zero during the computation.
        call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
      )
    }

    require(success, "TRANSFER_FROM_FAILED");
  }

  function safeTransfer(
    IERC20 token,
    address to,
    uint256 amount
  ) internal {
    bool success;

    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
      mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

      success := and(
        // Set success to whether the call reverted, if not we check it either
        // returned exactly 1 (can't just be non-zero data), or had no return data.
        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
        // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
        // Counterintuitively, this call must be positioned second to the or() call in the
        // surrounding and() call or else returndatasize() will be zero during the computation.
        call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
      )
    }

    require(success, "TRANSFER_FAILED");
  }

  function safeApprove(
    IERC20 token,
    address to,
    uint256 amount
  ) internal {
    bool success;

    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
      mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

      success := and(
        // Set success to whether the call reverted, if not we check it either
        // returned exactly 1 (can't just be non-zero data), or had no return data.
        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
        // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
        // Counterintuitively, this call must be positioned second to the or() call in the
        // surrounding and() call or else returndatasize() will be zero during the computation.
        call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
      )
    }

    require(success, "APPROVE_FAILED");
  }
}

/**
 * @dev Interface that all DripDecay models must conform to.
 */
interface IDripDecayModel {
  /// @notice Returns a rate which is used as either:
  ///   - The percentage of the fee pool that should be dripped to suppliers, per second, as a wad.
  ///   - The decay rate of PToken value, as percent per second, where the percent is a wad.
  /// @dev The returned value, when interpreted as drip rate, is not equivalent to the annual yield
  /// earned by suppliers. Annual yield can be computed as
  /// `supplierFeePool * dripRate * secondsPerYear / totalAssets`.
  /// @param utilization Current utilization of the set.
  function dripDecayRate(uint256 utilization) external view returns (uint256);
}

/**
 * @dev Interface that all cost models must conform to.
 */
interface ICostModel {
  /// @notice Returns the cost of purchasing protection as a percentage of the amount being purchased, as a wad.
  /// For example, if you are purchasing $200 of protection and this method returns 1e17, then the cost of
  /// the purchase is 200 * 1e17 / 1e18 = $20.
  /// @param utilization Current utilization of the market.
  /// @param newUtilization Utilization ratio of the market after purchasing protection.
  function costFactor(uint256 utilization, uint256 newUtilization) external view returns (uint256);

  /// @notice Gives the return value in assets of returning protection, as a percentage of
  /// the supplier fee pool, as a wad. For example, if the supplier fee pool currently has $100
  /// and this method returns 1e17, then you will get $100 * 1e17 / 1e18 = $10 in assets back.
  /// @param utilization Current utilization of the market.
  /// @param newUtilization Utilization ratio of the market after cancelling protection.
  function refundFactor(uint256 utilization, uint256 newUtilization) external view returns (uint256);

  /// @notice Returns true if the cost model's storage variables need to be updated.
  function shouldUpdate() external view returns (bool);

  /// @notice Updates the cost model's storage variables.
  function update() external;
}

/**
 * @dev Contains the enums used to define valid Cozy states.
 * @dev All states except TRIGGERED are valid for sets, and all states except PAUSED are valid for markets/triggers.
 */

enum MarketState {
  ACTIVE,
  FROZEN,
  TRIGGERED
}

enum SetState {
  ACTIVE,
  PAUSED,
  FROZEN
}

/**
 * @notice All protection markets live within a set.
 */

interface ISet {
  /// @notice Called by a trigger when it's state changes to `newMarketState_` to execute the state
  /// change in the corresponding market.
  function updateMarketState(MarketState newMarketState_) external;
}

/**
 * @dev The minimal functions a trigger must implement to work with the Cozy protocol.
 */
interface ITrigger {
  /// @dev Emitted when a new set is added to the trigger's list of sets.
  event SetAdded(ISet set);

  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(MarketState indexed state);

  /// @notice The current trigger state. This should never return PAUSED.
  function state() external returns (MarketState);

  /// @notice Called by the Manager to add a newly created set to the trigger's list of sets.
  function addSet(ISet set) external returns (bool);

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger
  /// state.
  function acknowledged() external returns (bool);
}

/// @notice Set-level configuration.
struct SetConfig {
  uint32 leverageFactor; // The set's leverage factor.
  uint16 depositFee; // Fee applied on each deposit and mint.
  // If true, the weight of a market when triggered is automatically distributed pro rata among non-triggered markets.
  // If false, the set admin must manually rebalance weights through a configuration update.
  bool rebalanceWeightsOnTrigger;
}

/// @notice Market-level configuration.
struct MarketConfig {
  ITrigger trigger; // Address of the trigger contract for this market.
  ICostModel costModel; // Contract defining the cost model for this market.
  IDripDecayModel dripDecayModel; // The model used for decay rate of PTokens and the rate at which funds are dripped to
    // suppliers for their yield.
  uint16 weight; // Weight of this market. Sum of weights across all markets must sum to 100% (1e4, 1 zoc).
  uint16 purchaseFee; // Fee applied on each purchase.
  uint16 saleFee; // Penalty applied on ptoken sales.
}

/// @notice Metadata for a configuration update.
struct ConfigUpdateMetadata {
  // A hash representing queued `SetConfig` and `MarketConfig[]` updates. This hash is used to prove that the
  // `SetConfig` and `MarketConfig[]` params used when applying config updates are identical to the queued updates.
  // This strategy is used instead of storing non-hashed `SetConfig` and `MarketConfig[]` for gas optimization
  // and to avoid dynamic array manipulation. This hash is set to bytes32(0) when there is no config update queued.
  bytes32 queuedConfigUpdateHash;
  // Earliest timestamp at which ISet.finalizeUpdateConfigs can be called to apply config updates queued by
  // updateConfigs.
  uint64 configUpdateTime;
  // The latest timestamp after configUpdateTime at which ISet.finalizeUpdateConfigs can be called to apply config
  // updates queued by ISet.updateConfigs. After this timestamp, the queued config updates expire and can no longer be
  // applied.
  uint64 configUpdateDeadline;
}

/**
 * @notice The Manager is in charge of the full Cozy protocol. Configuration parameters are defined here, it serves
 * as the entry point for all privileged operations, and exposes the `createSet` method used to create new sets.
 */
interface IManager {
  /// @notice For the specified set, returns whether it's a valid Cozy set.
  function isSet(address) external view returns (bool);
  /// @notice The Cozy protocol owner.
  function owner() external view returns (address);

  /// @notice The Cozy protocol pauser.
  function pauser() external view returns (address);
}

/**
 * @dev Additional functions that are recommended to have in a trigger, but are not required.
 */
interface IBaseTrigger is ITrigger {
  /// @notice Returns the set address at the specified index in the trigger's list of sets.
  function sets(uint256 index) external returns (ISet set);

  /// @notice Returns all sets in the trigger's list of sets.
  function getSets() external returns (ISet[] memory);

  /// @notice Returns the number of Sets that use this trigger in a market.
  function getSetsLength() external returns (uint256 setsLength);

  /// @notice Returns the address of the trigger's manager.
  function manager() external returns (IManager managerAddress);

  /// @notice The maximum amount of sets that can be added to this trigger.
  function MAX_SET_LENGTH() external returns (uint256 maxSetLength);
}

/**
 * @dev Core trigger interface and implementation. All triggers should inherit from this to ensure they conform
 * to the required trigger interface.
 */
abstract contract BaseTrigger is IBaseTrigger {
  /// @notice Current trigger state.
  MarketState public state;

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve a specific Set.
  ISet[] public sets;

  /// @notice Prevent DOS attacks by limiting the number of sets.
  uint256 public constant MAX_SET_LENGTH = 50;

  /// @notice The manager of the Cozy protocol.
  IManager public immutable manager;

  /// @dev Thrown when a state update results in an invalid state transition.
  error InvalidStateTransition();

  /// @dev Thrown when trying to add a set to the `sets` array when it's length is already at `MAX_SET_LENGTH`.
  error SetLimitReached();

  /// @dev Thrown when trying to add a set to the `sets` array when the trigger has not been acknowledged.
  error Unacknowledged();

  /// @dev Thrown when the caller is not authorized to perform the action.
  error Unauthorized();

  /// @param _manager The manager of the Cozy protocol.
  constructor(IManager _manager) {
    manager = _manager;
  }

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger
  /// state.
  /// @dev This must be implemented by contracts that inherit this contract. For manual triggers, after the trigger is
  /// deployed this should initially return false, and instead return true once the entity responsible for
  /// transitioning trigger state acknowledges the trigger. For programmatic triggers, this should always return true.
  function acknowledged() public virtual returns (bool);

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve all Sets.
  function getSets() public view returns (ISet[] memory) {
    return sets;
  }

  /// @notice The number of Sets that use this trigger in a market.
  function getSetsLength() public view returns (uint256) {
    return sets.length;
  }

  /// @dev Call this method to update Set addresses after deploy. Returns false if the trigger has not been
  /// acknowledged.
  function addSet(ISet _set) external returns (bool) {
    if (msg.sender != address(_set)) revert Unauthorized();
    if (!acknowledged()) revert Unacknowledged();
    bool _exists = manager.isSet(address(_set));
    if (!_exists) revert Unauthorized();

    uint256 setLength = sets.length;
    if (setLength >= MAX_SET_LENGTH) revert SetLimitReached();
    for (uint256 i = 0; i < setLength; i = uncheckedIncrement(i)) {
      if (sets[i] == _set) return true;
    }
    sets.push(_set);
    emit SetAdded(_set);
    return true;
  }

  /// @dev Child contracts should use this function to handle Trigger state transitions.
  function _updateTriggerState(MarketState _newState) internal returns (MarketState) {
    if (!_isValidTriggerStateTransition(state, _newState)) revert InvalidStateTransition();
    state = _newState;
    uint256 setLength = sets.length;
    for (uint256 i = 0; i < setLength; i = uncheckedIncrement(i)) {
      sets[i].updateMarketState(_newState);
    }
    emit TriggerStateUpdated(_newState);
    return _newState;
  }

  /// @dev Reimplement this function if different state transitions are needed.
  function _isValidTriggerStateTransition(MarketState _oldState, MarketState _newState) internal virtual returns (bool) {
    // | From / To | ACTIVE      | FROZEN      | PAUSED   | TRIGGERED |
    // | --------- | ----------- | ----------- | -------- | --------- |
    // | ACTIVE    | -           | true        | false    | true      |
    // | FROZEN    | true        | -           | false    | true      |
    // | PAUSED    | false       | false       | -        | false     | <-- PAUSED is a set-level state, triggers cannot
    // be paused
    // | TRIGGERED | false       | false       | false    | -         | <-- TRIGGERED is a terminal state

    if (_oldState == MarketState.TRIGGERED) return false;
    // If oldState == newState, return true since the Set will convert that into a no-op.
    if (_oldState == _newState) return true;
    if (_oldState == MarketState.ACTIVE && _newState == MarketState.FROZEN) return true;
    if (_oldState == MarketState.FROZEN && _newState == MarketState.ACTIVE) return true;
    if (_oldState == MarketState.ACTIVE && _newState == MarketState.TRIGGERED) return true;
    if (_oldState == MarketState.FROZEN && _newState == MarketState.TRIGGERED) return true;
    return false;
  }

  /// @dev Unchecked increment of the provided value. Realistically it's impossible to overflow a
  /// uint256 so this is always safe.
  function uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }
}

// A named import is used to avoid identifier naming conflicts between IERC20 imports. solc throws a DeclarationError
// if an interface with the same name is imported twice in a file using different paths, even if they have the
// same implementation. For example, if a file in the cozy-v2-interfaces submodule that is imported in this project
// imports an IERC20 interface with "import src/interfaces/IERC20.sol;", but in this project we import the same
// interface with "import cozy-v2-interfaces/interfaces/IERC20.sol;", a DeclarationError will be thrown.

/**
 * @title Provides addresses of the live contracts implementing certain interfaces.
 * @dev Examples are the Oracle or Store interfaces.
 */
interface FinderInterface {
    /**
     * @notice Updates the address of the contract that implements `interfaceName`.
     * @param interfaceName bytes32 encoding of the interface name that is either changed or registered.
     * @param implementationAddress address of the deployed contract that implements the interface.
     */
    function changeImplementationAddress(bytes32 interfaceName, address implementationAddress) external;

    /**
     * @notice Gets the address of the contract that implements the given `interfaceName`.
     * @param interfaceName queried interface.
     * @return implementationAddress address of the deployed contract that implements the interface.
     */
    function getImplementationAddress(bytes32 interfaceName) external view returns (address);
}

/**
 * @title Financial contract facing Oracle interface.
 * @dev Interface used by financial contracts to interact with the Oracle. Voters will use a different interface.
 * @dev Modified from uma-protocol to use Cozy's implementation of IERC20 instead of OpenZeppelin's. Cozy's IERC20
 * conforms to Cozy's implementation of ERC20, which was modified from Solmate to use an initializer to support
 * usage as a minimal proxy.
 */
abstract contract OptimisticOracleV2Interface {
    event RequestPrice(
        address indexed requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes ancillaryData,
        address currency,
        uint256 reward,
        uint256 finalFee
    );
    event ProposePrice(
        address indexed requester,
        address indexed proposer,
        bytes32 identifier,
        uint256 timestamp,
        bytes ancillaryData,
        int256 proposedPrice,
        uint256 expirationTimestamp,
        address currency
    );
    event DisputePrice(
        address indexed requester,
        address indexed proposer,
        address indexed disputer,
        bytes32 identifier,
        uint256 timestamp,
        bytes ancillaryData,
        int256 proposedPrice
    );
    event Settle(
        address indexed requester,
        address indexed proposer,
        address indexed disputer,
        bytes32 identifier,
        uint256 timestamp,
        bytes ancillaryData,
        int256 price,
        uint256 payout
    );
    // Struct representing the state of a price request.
    enum State {
        Invalid, // Never requested.
        Requested, // Requested, no other actions taken.
        Proposed, // Proposed, but not expired or disputed yet.
        Expired, // Proposed, not disputed, past liveness.
        Disputed, // Disputed, but no DVM price returned yet.
        Resolved, // Disputed and DVM price is available.
        Settled // Final price has been set in the contract (can get here from Expired or Resolved).
    }

    struct RequestSettings {
        bool eventBased; // True if the request is set to be event-based.
        bool refundOnDispute; // True if the requester should be refunded their reward on dispute.
        bool callbackOnPriceProposed; // True if callbackOnPriceProposed callback is required.
        bool callbackOnPriceDisputed; // True if callbackOnPriceDisputed callback is required.
        bool callbackOnPriceSettled; // True if callbackOnPriceSettled callback is required.
        uint256 bond; // Bond that the proposer and disputer must pay on top of the final fee.
        uint256 customLiveness; // Custom liveness value set by the requester.
    }

    // Struct representing a price request.
    struct Request {
        address proposer; // Address of the proposer.
        address disputer; // Address of the disputer.
        IERC20 currency; // ERC20 token used to pay rewards and fees.
        bool settled; // True if the request is settled.
        RequestSettings requestSettings; // Custom settings associated with a request.
        int256 proposedPrice; // Price that the proposer submitted.
        int256 resolvedPrice; // Price resolved once the request is settled.
        uint256 expirationTime; // Time at which the request auto-settles without a dispute.
        uint256 reward; // Amount of the currency to pay to the proposer on settlement.
        uint256 finalFee; // Final fee to pay to the Store upon request to the DVM.
    }

    // This value must be <= the Voting contract's `ancillaryBytesLimit` value otherwise it is possible
    // that a price can be requested to this contract successfully, but cannot be disputed because the DVM refuses
    // to accept a price request made with ancillary data length over a certain size.
    uint256 public constant ancillaryBytesLimit = 8192;

    function defaultLiveness() external view virtual returns (uint256);

    function finder() external view virtual returns (FinderInterface);

    function getCurrentTime() external view virtual returns (uint256);

    // Note: this is required so that typechain generates a return value with named fields.
    mapping(bytes32 => Request) public requests;

    /**
     * @notice Requests a new price.
     * @param identifier price identifier being requested.
     * @param timestamp timestamp of the price being requested.
     * @param ancillaryData ancillary data representing additional args being passed with the price request.
     * @param currency ERC20 token used for payment of rewards and fees. Must be approved for use with the DVM.
     * @param reward reward offered to a successful proposer. Will be pulled from the caller. Note: this can be 0,
     *               which could make sense if the contract requests and proposes the value in the same call or
     *               provides its own reward system.
     * @return totalBond default bond (final fee) + final fee that the proposer and disputer will be required to pay.
     * This can be changed with a subsequent call to setBond().
     */
    function requestPrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        IERC20 currency,
        uint256 reward
    ) external virtual returns (uint256 totalBond);

    /**
     * @notice Set the proposal bond associated with a price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param bond custom bond amount to set.
     * @return totalBond new bond + final fee that the proposer and disputer will be required to pay. This can be
     * changed again with a subsequent call to setBond().
     */
    function setBond(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        uint256 bond
    ) external virtual returns (uint256 totalBond);

    /**
     * @notice Sets the request to refund the reward if the proposal is disputed. This can help to "hedge" the caller
     * in the event of a dispute-caused delay. Note: in the event of a dispute, the winner still receives the other's
     * bond, so there is still profit to be made even if the reward is refunded.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     */
    function setRefundOnDispute(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual;

    /**
     * @notice Sets a custom liveness value for the request. Liveness is the amount of time a proposal must wait before
     * being auto-resolved.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param customLiveness new custom liveness.
     */
    function setCustomLiveness(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        uint256 customLiveness
    ) external virtual;

    /**
     * @notice Sets the request to be an "event-based" request.
     * @dev Calling this method has a few impacts on the request:
     *
     * 1. The timestamp at which the request is evaluated is the time of the proposal, not the timestamp associated
     *    with the request.
     *
     * 2. The proposer cannot propose the "too early" value (TOO_EARLY_RESPONSE). This is to ensure that a proposer who
     *    prematurely proposes a response loses their bond.
     *
     * 3. RefundoOnDispute is automatically set, meaning disputes trigger the reward to be automatically refunded to
     *    the requesting contract.
     *
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     */
    function setEventBased(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual;

    /**
     * @notice Sets which callbacks should be enabled for the request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param callbackOnPriceProposed whether to enable the callback onPriceProposed.
     * @param callbackOnPriceDisputed whether to enable the callback onPriceDisputed.
     * @param callbackOnPriceSettled whether to enable the callback onPriceSettled.
     */
    function setCallbacks(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        bool callbackOnPriceProposed,
        bool callbackOnPriceDisputed,
        bool callbackOnPriceSettled
    ) external virtual;

    /**
     * @notice Proposes a price value on another address' behalf. Note: this address will receive any rewards that come
     * from this proposal. However, any bonds are pulled from the caller.
     * @param proposer address to set as the proposer.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param proposedPrice price being proposed.
     * @return totalBond the amount that's pulled from the caller's wallet as a bond. The bond will be returned to
     * the proposer once settled if the proposal is correct.
     */
    function proposePriceFor(
        address proposer,
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 proposedPrice
    ) public virtual returns (uint256 totalBond);

    /**
     * @notice Proposes a price value for an existing price request.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param proposedPrice price being proposed.
     * @return totalBond the amount that's pulled from the proposer's wallet as a bond. The bond will be returned to
     * the proposer once settled if the proposal is correct.
     */
    function proposePrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 proposedPrice
    ) external virtual returns (uint256 totalBond);

    /**
     * @notice Disputes a price request with an active proposal on another address' behalf. Note: this address will
     * receive any rewards that come from this dispute. However, any bonds are pulled from the caller.
     * @param disputer address to set as the disputer.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return totalBond the amount that's pulled from the caller's wallet as a bond. The bond will be returned to
     * the disputer once settled if the dispute was value (the proposal was incorrect).
     */
    function disputePriceFor(
        address disputer,
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public virtual returns (uint256 totalBond);

    /**
     * @notice Disputes a price value for an existing price request with an active proposal.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return totalBond the amount that's pulled from the disputer's wallet as a bond. The bond will be returned to
     * the disputer once settled if the dispute was valid (the proposal was incorrect).
     */
    function disputePrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual returns (uint256 totalBond);

    /**
     * @notice Retrieves a price that was previously requested by a caller. Reverts if the request is not settled
     * or settleable. Note: this method is not view so that this call may actually settle the price request if it
     * hasn't been settled.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return resolved price.
     */
    function settleAndGetPrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual returns (int256);

    /**
     * @notice Attempts to settle an outstanding price request. Will revert if it isn't settleable.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return payout the amount that the "winner" (proposer or disputer) receives on settlement. This amount includes
     * the returned bonds as well as additional rewards.
     */
    function settle(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual returns (uint256 payout);

    /**
     * @notice Gets the current data structure containing all information about a price request.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return the Request data structure.
     */
    function getRequest(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public view virtual returns (Request memory);

    /**
     * @notice Returns the state of a price request.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return the State enum value.
     */
    function getState(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public view virtual returns (State);

    /**
     * @notice Checks if a given request has resolved or been settled (i.e the optimistic oracle has a price).
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return true if price has resolved or settled, false otherwise.
     */
    function hasPrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public view virtual returns (bool);

    function stampAncillaryData(bytes memory ancillaryData, address requester)
        public
        view
        virtual
        returns (bytes memory);
}

/**
 * @notice This is an automated trigger contract which will move markets into a
 * TRIGGERED state in the event that the UMA Optimistic Oracle answers "YES" to
 * a provided query, e.g. "Was protocol ABCD hacked on or after block 42". More
 * information about UMA oracles and the lifecycle of queries can be found here:
 * https://docs.umaproject.org/.
 * @dev The high-level lifecycle of a UMA request is as follows:
 *   - someone asks a question of the oracle and provides a reward for someone
 *     to answer it
 *   - users of the UMA oracle system view the question (usually here:
 *     https://oracle.umaproject.org/)
 *   - someone proposes an answer to the question in hopes of claiming the
 *     reward`
 *   - users of UMA see the proposed answer and have a chance to dispute it
 *   - there is a finite period of time within which to dispute the answer
 *   - if the answer is not disputed during this period, the oracle can finalize
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
 * yield, you might deploy a UMATrigger with a query like "Was Compound hacked
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

  /// @notice The UMA Optimistic Oracle.
  OptimisticOracleV2Interface public immutable oracle;

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

  /// @notice Default address that will receive any leftover rewards.
  address public refundRecipient;

  /// @dev Thrown when a negative answer is proposed to the submitted query.
  error InvalidProposal();

  /// @dev Thrown when the trigger attempts to settle an unsettleable UMA request.
  error Unsettleable();

  /// @dev Emitted when an answer proposed to the submitted query is disputed
  /// and a request is sent to the DVM for dispute resolution by UMA tokenholders
  /// via voting.
  event ProposalDisputed();

  /// @dev Emitted when the query is resubmitted after a dispute resolution results
  /// in the proposed answer being rejected (so, the market returns to the active
  /// state).
  event QueryResubmitted();

  /// @dev UMA expects answers to be denominated as wads. So, e.g., a p3 answer
  /// of 0.5 would be represented as 0.5e18.
  int256 internal constant AFFIRMATIVE_ANSWER = 1e18;

  /// @param _manager The Cozy protocol Manager.
  /// @param _oracle The UMA Optimistic Oracle.
  /// @param _query The query that the trigger will send to the UMA Optimistic
  /// Oracle for evaluation.
  /// @param _rewardToken The token used to pay the reward to users that propose
  /// answers to the query. The reward token must be approved by UMA governance.
  /// Approved tokens can be found with the UMA AddressWhitelist contract on each
  /// chain supported by UMA.
  /// @param _refundRecipient Default address that will recieve any leftover
  /// rewards at UMA query settlement time.
  /// @param _bondAmount The amount of `rewardToken` that must be staked by a
  /// user wanting to propose or dispute an answer to the query. See UMA's price
  /// dispute workflow for more information. It's recommended that the bond
  /// amount be a significant value to deter addresses from proposing malicious,
  /// false, or otherwise self-interested answers to the query.
  /// @param _proposalDisputeWindow The window of time in seconds within which a
  /// proposed answer may be disputed. See UMA's "customLiveness" setting for
  /// more information. It's recommended that the dispute window be fairly long
  /// (12-24 hours), given the difficulty of assessing expected queries (e.g.
  /// "Was protocol ABCD hacked") and the amount of funds potentially at stake.
  constructor(
    IManager _manager,
    OptimisticOracleV2Interface _oracle,
    string memory _query,
    IERC20 _rewardToken,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) BaseTrigger(_manager) {
    oracle = _oracle;
    query = _query;
    rewardToken = _rewardToken;
    refundRecipient = _refundRecipient;
    bondAmount = _bondAmount;
    proposalDisputeWindow = _proposalDisputeWindow;

    _submitRequestToOracle();
  }

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger
  /// state.
  /// @notice UMA triggers are managed by the UMA decentralized voting system, so this always returns true.
  function acknowledged() public pure override returns (bool) {
    return true;
  }

  /// @notice Submits the trigger query to the UMA Optimistic Oracle for evaluation.
  function _submitRequestToOracle() internal {
    uint256 _rewardAmount = rewardToken.balanceOf(address(this));
    rewardToken.approve(address(oracle), _rewardAmount);
    requestTimestamp = block.timestamp;

    // The UMA function for submitting a query to the oracle is `requestPrice`
    // even though not all queries are price queries. Another name for this
    // function might have been `requestAnswer`.
    oracle.requestPrice(queryIdentifier, requestTimestamp, bytes(query), rewardToken, _rewardAmount);

    // Set this as an event-based query so that no one can propose the "too
    // soon" answer and so that we automatically get the reward back if there
    // is a dispute. This allows us to re-query the oracle for ~free.
    oracle.setEventBased(queryIdentifier, requestTimestamp, bytes(query));

    // Set the amount of rewardTokens that have to be staked in order to answer
    // the query or dispute an answer to the query.
    oracle.setBond(queryIdentifier, requestTimestamp, bytes(query), bondAmount);

    // Set the proposal dispute window -- i.e. how long people have to challenge
    // and answer to the query.
    oracle.setCustomLiveness(queryIdentifier, requestTimestamp, bytes(query), proposalDisputeWindow);

    // We want to be notified by the UMA oracle when answers and proposed and
    // when answers are confirmed/settled.
    oracle.setCallbacks(
      queryIdentifier,
      requestTimestamp,
      bytes(query),
      true, // Enable the answer-proposed callback.
      true, // Enable the answer-disputed callback.
      true // Enable the answer-settled callback.
    );
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
  function priceProposed(bytes32 _identifier, uint256 _timestamp, bytes memory _ancillaryData) external {
    // Besides confirming that the caller is the UMA oracle, we also confirm
    // that the args passed in match the args used to submit our latest query to
    // UMA. This is done as an extra safeguard that we are responding to an
    // event related to the specific query we care about. It is possible, for
    // example, for multiple queries to be submitted to the oracle that differ
    // only with respect to timestamp. So we want to make sure we know which
    // query the answer is for.
    if (
      msg.sender != address(oracle) || _timestamp != requestTimestamp
        || keccak256(_ancillaryData) != keccak256(bytes(query)) || _identifier != queryIdentifier
    ) revert Unauthorized();

    OptimisticOracleV2Interface.Request memory _umaRequest;
    _umaRequest = oracle.getRequest(address(this), _identifier, _timestamp, _ancillaryData);

    // Revert if the answer was anything other than "YES". We don't want to be told
    // that a hack/exploit has *not* happened yet, or it cannot be determined, etc.
    if (_umaRequest.proposedPrice != AFFIRMATIVE_ANSWER) revert InvalidProposal();

    // Freeze the market and set so that funds cannot be withdrawn, since
    // there's now a real possibility that we are going to trigger.
    _updateTriggerState(MarketState.FROZEN);
  }

  /// @notice UMA callback for settlement. This code is run when the protocol
  /// has confirmed an answer to the query.
  /// @dev This callback is kept intentionally lean, as we don't want to risk
  /// reverting and blocking settlement.
  /// @param _identifier price identifier being requested.
  /// @param _timestamp timestamp of the original query request.
  /// @param _ancillaryData ancillary data of the original query request.
  /// @param _answer the oracle's answer to the query.
  function priceSettled(bytes32 _identifier, uint256 _timestamp, bytes memory _ancillaryData, int256 _answer) external {
    // See `priceProposed` for why we authorize callers in this way.
    if (
      msg.sender != address(oracle) || _timestamp != requestTimestamp
        || keccak256(_ancillaryData) != keccak256(bytes(query)) || _identifier != queryIdentifier
    ) revert Unauthorized();

    if (_answer == AFFIRMATIVE_ANSWER) {
      uint256 _rewardBalance = rewardToken.balanceOf(address(this));
      if (_rewardBalance > 0) rewardToken.safeTransfer(refundRecipient, _rewardBalance);
      _updateTriggerState(MarketState.TRIGGERED);
    } else {
      // If the answer was not affirmative, i.e. "Yes, the protocol was hacked",
      // the trigger should return to the ACTIVE state. And we need to resubmit
      // our query so that we are informed if the event we care about happens in
      // the future.
      _updateTriggerState(MarketState.ACTIVE);
      _submitRequestToOracle();
      emit QueryResubmitted();
    }
  }

  /// @notice UMA callback for disputes. This code is run when the answer
  /// proposed to the query is disputed.
  /// @param _identifier price identifier being requested.
  /// @param _timestamp timestamp of the original query request.
  /// @param _ancillaryData ancillary data of the original query request.
  function priceDisputed(bytes32 _identifier, uint256 _timestamp, bytes memory _ancillaryData, uint256 /* _refund */ )
    external
  {
    // See `priceProposed` for why we authorize callers in this way.
    if (
      msg.sender != address(oracle) || _timestamp != requestTimestamp
        || keccak256(_ancillaryData) != keccak256(bytes(query)) || _identifier != queryIdentifier
    ) revert Unauthorized();

    emit ProposalDisputed();
  }

  /// @notice This function attempts to confirm and finalize (i.e. "settle") the
  /// answer to the query with the UMA oracle. It reverts with Unsettleable if
  /// it cannot settle the query, but does NOT revert if the oracle has already
  /// settled the query on its own. If the oracle's answer is an
  /// AFFIRMATIVE_ANSWER, this function will toggle the trigger and update
  /// associated markets.
  function runProgrammaticCheck() external returns (MarketState) {
    // Rather than revert when triggered, we simply return the state and exit.
    // Both behaviors are acceptable, but returning is friendlier to the caller
    // as they don't need to handle a revert and can simply parse the
    // transaction's logs to know if the call resulted in a state change.
    if (state == MarketState.TRIGGERED) return state;

    bool _oracleHasPrice = oracle.hasPrice(address(this), queryIdentifier, requestTimestamp, bytes(query));

    if (!_oracleHasPrice) revert Unsettleable();

    OptimisticOracleV2Interface.Request memory _umaRequest =
      oracle.getRequest(address(this), queryIdentifier, requestTimestamp, bytes(query));
    if (!_umaRequest.settled) {
      // Give the reward balance to the caller to make up for gas costs and
      // incentivize keeping markets in line with trigger state.
      refundRecipient = msg.sender;

      // `settle` will cause the oracle to call the trigger's `priceSettled` function.
      oracle.settle(address(this), queryIdentifier, requestTimestamp, bytes(query));
    }

    // If the request settled as a result of this call, trigger.state will have
    // been updated in the priceSettled callback.
    return state;
  }
}

/**
 * @notice This is an automated trigger contract which will move markets into a
 * TRIGGERED state in the event that the UMA Optimistic Oracle answers "YES" to
 * a provided query, e.g. "Was protocol ABCD hacked on or after block 42". More
 * information about UMA oracles and the lifecycle of queries can be found here:
 * https://docs.umaproject.org/.
 * @dev The high-level lifecycle of a UMA request is as follows:
 * - someone asks a question of the oracle and provides a reward for someone
 * to answer it
 * - users of the UMA prediction market view the question (usually here:
 * https://oracle.umaproject.org/)
 * - someone proposes an answer to the question in hopes of claiming the
 * reward`
 * - users of UMA see the proposed answer and have a chance to dispute it
 * - there is a finite period of time within which to dispute the answer
 * - if the answer is not disputed during this period, the oracle finalizes
 * the answer and the proposer gets the reward
 * - if the answer is disputed, the question is sent to the DVM (Data
 * Verification Mechanism) in which UMA token holders vote on who is right
 * There are four essential players in the above process:
 * 1. Requester: the account that is asking the oracle a question.
 * 2. Proposer: the account that submits an answer to the question.
 * 3. Disputer: the account (if any) that disagrees with the proposed answer.
 * 4. The DVM: a DAO that is the final arbiter of disputed proposals.
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
 * But what if Compound hasn't been hacked? Can't someone just respond "No" to
 * the trigger's query? Wouldn't that be the right answer and wouldn't it mean
 * the end of the query lifecycle? Yes. For this exact reason, we have enabled
 * callbacks (see the `priceProposed` function) which will revert in the event
 * that someone attempts to propose a negative answer to the question. We want
 * the queries to remain open indefinitely until there is a positive answer,
 * i.e. "Yes, there was a hack". **This should be communicated in the query text.**
 * In the event that a YES answer to a query is disputed and the DVM sides
 * with the disputer (i.e. a NO answer), we immediately re-submit the query to
 * the DVM through another callback (see `priceSettled`). In this way, our query
 * will always be open with the oracle. If/when the event that we are concerned
 * with happens the trigger will immediately be notified.
 */
interface IUMATrigger {
  /// @dev Emitted when a new set is added to the trigger's list of sets.
  event SetAdded(ISet set);

  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(MarketState indexed state);

  /// @notice The current trigger state. This should never return PAUSED.
  function state() external returns (MarketState);

  /// @notice Called by the Manager to add a newly created set to the trigger's list of sets.
  function addSet(ISet set) external;

  /// @notice The type of query that will be submitted to the oracle.
  function queryIdentifier() external view returns (bytes32);

  /// @notice The UMA contract used to lookup the UMA Optimistic Oracle.
  function oracleFinder() external view returns (address);

  /// @notice The query that is sent to the UMA Optimistic Oracle for evaluation.
  /// It should be phrased so that only a positive answer is appropriate, e.g.
  /// "Was protocol ABCD hacked on or after block number 42". Negative answers
  /// are disallowed so that queries can remain open in UMA until the events we
  /// care about happen, if ever.
  function query() external view returns (string memory);

  /// @notice The token used to pay the reward to users that propose answers to the query.
  function rewardToken() external view returns (address);

  /// @notice The amount of `rewardToken` that must be staked by a user wanting
  /// to propose or dispute an answer to the query. See UMA's price dispute
  /// workflow for more information. It's recommended that the bond amount be a
  /// significant value to deter addresses from proposing malicious, false, or
  /// otherwise self-interested answers to the query.
  function bondAmount() external view returns (uint256);

  /// @notice The window of time in seconds within which a proposed answer may
  /// be disputed. See UMA's "customLiveness" setting for more information. It's
  /// recommended that the dispute window be fairly long (12-24 hours), given
  /// the difficulty of assessing expected queries (e.g. "Was protocol ABCD
  /// hacked") and the amount of funds potentially at stake.
  function proposalDisputeWindow() external view returns (uint256);

  /// @notice The most recent timestamp that the query was submitted to the UMA oracle.
  function requestTimestamp() external view returns (uint256);

  /// @notice Whether or not this trigger will enter the TRIGGERED state the
  /// next time `runProgrammaticCheck` is called.
  function shouldTrigger() external view returns (bool);

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
  function priceProposed(bytes32 _identifier, uint256 _timestamp, bytes memory _ancillaryData) external;

  /// @notice UMA callback for settlement. This code is run when the protocol
  /// has confirmed an answer to the query.
  /// @dev This callback is kept intentionally lean, as we don't want to risk
  /// reverting and blocking settlement.
  /// @param _identifier price identifier being requested.
  /// @param _timestamp timestamp of the original query request.
  /// @param _ancillaryData ancillary data of the original query request.
  /// @param _answer the oracle's answer to the query.
  function priceSettled(bytes32 _identifier, uint256 _timestamp, bytes memory _ancillaryData, int256 _answer) external;

  /// @notice Toggles the trigger if the UMA oracle has confirmed a positive
  /// answer to the query.
  function runProgrammaticCheck() external returns (uint8);

  /// @notice The UMA Optimistic Oracle queried by this trigger.
  function getOracle() external view returns (address);

  /// @notice Returns the set address at the specified index in the trigger's list of sets.
  function sets(uint256) external view returns (address);

  /// @notice Returns all sets in the trigger's list of sets.
  function getSets() external view returns (address[] memory);

  /// @notice Returns the number of Sets that use this trigger in a market.
  function getSetsLength() external view returns (uint256);

  /// @notice Returns the address of the trigger's manager.
  function manager() external view returns (address);

  /// @notice The maximum amount of sets that can be added to this trigger.
  function MAX_SET_LENGTH() external view returns (uint256);

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger
  /// state.
  /// @notice UMA triggers are managed by the UMA decentralized voting system, so this always returns true.
  function acknowledged() external pure returns (bool);
}

struct TriggerMetadata {
  // The name that should be used for markets that use the trigger.
  string name;
  // Category of the trigger.
  string category;
  // A human-readable description of the trigger.
  string description;
  // The URI of a logo image to represent the trigger.
  string logoURI;
}

/**
 * @notice This is a utility contract to make it easy to deploy UMATriggers for
 * the Cozy protocol.
 * @dev Be sure to approve the trigger to spend the rewardAmount before calling
 * `deployTrigger`, otherwise the latter will revert. Funds need to be available
 * to the created trigger within its constructor so that it can submit its query
 * to the UMA oracle.
 */
interface IUMATriggerFactory {
  /// @dev Emitted when the factory deploys a trigger.
  /// @param trigger The address at which the trigger was deployed.
  /// @param triggerConfigId See the function of the same name in this contract.
  /// @param name The name that should be used for markets that use the trigger.
  /// @param category The category of the trigger.
  /// @param description A human-readable description of the trigger.
  /// @param logoURI The URI of a logo image to represent the trigger.
  /// For other attributes, see the docs for the params of `deployTrigger` in
  /// this contract.
  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed umaOracleFinder,
    string query,
    address indexed rewardToken,
    uint256 rewardAmount,
    address refundRecipient,
    uint256 bondAmount,
    uint256 proposalDisputeWindow,
    string name,
    string category,
    string description,
    string logoURI
  );

  /// @notice The manager of the Cozy protocol.
  function manager() external view returns (address);

  /// @notice The UMA contract used to lookup the UMA Optimistic Oracle.
  function oracleFinder() external view returns (FinderInterface);

  /// @notice Maps the triggerConfigId to the number of triggers created with those configs.
  function triggerCount(bytes32) external view returns (uint256);

  /// @notice Call this function to deploy a UMATrigger.
  /// @param _query The query that the trigger will send to the UMA Optimistic
  /// Oracle for evaluation.
  /// @param _rewardToken The token used to pay the reward to users that propose
  /// answers to the query.
  /// @param _rewardAmount The amount of rewardToken that will be paid as a
  /// reward to anyone who proposes an answer to the query.
  /// @param _refundRecipient Default address that will recieve any leftover
  /// rewards at UMA query settlement time.
  /// @param _bondAmount The amount of `rewardToken` that must be staked by a
  /// user wanting to propose or dispute an answer to the query. See UMA's price
  /// dispute workflow for more information. It's recommended that the bond
  /// amount be a significant value to deter addresses from proposing malicious,
  /// false, or otherwise self-interested answers to the query.
  /// @param _proposalDisputeWindow The window of time in seconds within which a
  /// proposed answer may be disputed. See UMA's "customLiveness" setting for
  /// more information. It's recommended that the dispute window be fairly long
  /// (12-24 hours), given the difficulty of assessing expected queries (e.g.
  /// "Was protocol ABCD hacked") and the amount of funds potentially at stake.
  /// @param _metadata See TriggerMetadata for more info.
  function deployTrigger(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow,
    TriggerMetadata memory _metadata
  ) external returns (IUMATrigger _trigger);

  /// @notice Call this function to determine the address at which a trigger
  /// with the supplied configuration would be deployed. See `deployTrigger` for
  /// more information on parameters and their meaning.
  function computeTriggerAddress(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow,
    uint256 _triggerCount
  ) external view returns (address _address);

  /// @notice Call this function to find triggers with the specified
  /// configurations that can be used for new markets in Sets. See
  /// `deployTrigger` for more information on parameters and their meaning.
  function findAvailableTrigger(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) external view returns (address);

  /// @notice Call this function to determine the identifier of the supplied
  /// trigger configuration. This identifier is used both to track the number of
  /// triggers deployed with this configuration (see `triggerCount`) and is
  /// emitted as a part of the TriggerDeployed event when triggers are deployed.
  /// @dev This function takes the rewardAmount as an input despite it not being
  /// an argument of the UMATrigger constructor nor it being held in storage by
  /// the trigger. This is done because the rewardAmount is something that
  /// deployers could reasonably differ on. Deployer A might deploy a trigger
  /// that is identical to what Deployer B wants in every way except the amount
  /// of rewardToken that is being offered, and it would still be reasonable for
  /// Deployer B to not want to re-use A's trigger for his own markets.
  function triggerConfigId(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) external view returns (bytes32);
}

/**
 * @notice This is a utility contract to make it easy to deploy UMATriggers for
 * the Cozy protocol.
 * @dev Be sure to approve the trigger to spend the rewardAmount before calling
 * `deployTrigger`, otherwise the latter will revert. Funds need to be available
 * to the created trigger within its constructor so that it can submit its query
 * to the UMA oracle.
 */
contract UMATriggerFactory {
  using SafeTransferLib for IERC20;

  /// @notice The manager of the Cozy protocol.
  IManager public immutable manager;

  /// @notice The UMA Optimistic Oracle.
  OptimisticOracleV2Interface public immutable oracle;

  /// @notice Maps the triggerConfigId to the number of triggers created with those configs.
  mapping(bytes32 => uint256) public triggerCount;

  /// @dev Emitted when the factory deploys a trigger.
  /// @param trigger The address at which the trigger was deployed.
  /// @param triggerConfigId See the function of the same name in this contract.
  /// @param name The name that should be used for markets that use the trigger.
  /// @param description A human-readable description of the trigger.
  /// @param logoURI The URI of a logo image to represent the trigger.
  /// For other attributes, see the docs for the params of `deployTrigger` in
  /// this contract.
  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed oracle,
    string query,
    address indexed rewardToken,
    uint256 rewardAmount,
    address refundRecipient,
    uint256 bondAmount,
    uint256 proposalDisputeWindow,
    string name,
    string category,
    string description,
    string logoURI
  );

  error TriggerAddressMismatch();

  constructor(IManager _manager, OptimisticOracleV2Interface _oracle) {
    manager = _manager;
    oracle = _oracle;
  }

  struct DeployTriggerVars {
    bytes32 configId;
    bytes32 salt;
    uint256 triggerCount;
    address triggerAddress;
    UMATrigger trigger;
  }

  /// @notice Call this function to deploy a UMATrigger.
  /// @param _query The query that the trigger will send to the UMA Optimistic
  /// Oracle for evaluation.
  /// @param _rewardToken The token used to pay the reward to users that propose
  /// answers to the query. The reward token must be approved by UMA governance.
  /// Approved tokens can be found with the UMA AddressWhitelist contract on each
  /// chain supported by UMA.
  /// @param _rewardAmount The amount of rewardToken that will be paid as a
  /// reward to anyone who proposes an answer to the query.
  /// @param _refundRecipient Default address that will recieve any leftover
  /// rewards at UMA query settlement time.
  /// @param _bondAmount The amount of `rewardToken` that must be staked by a
  /// user wanting to propose or dispute an answer to the query. See UMA's price
  /// dispute workflow for more information. It's recommended that the bond
  /// amount be a significant value to deter addresses from proposing malicious,
  /// false, or otherwise self-interested answers to the query.
  /// @param _proposalDisputeWindow The window of time in seconds within which a
  /// proposed answer may be disputed. See UMA's "customLiveness" setting for
  /// more information. It's recommended that the dispute window be fairly long
  /// (12-24 hours), given the difficulty of assessing expected queries (e.g.
  /// "Was protocol ABCD hacked") and the amount of funds potentially at stake.
  /// @param _metadata See TriggerMetadata for more info.
  function deployTrigger(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow,
    TriggerMetadata memory _metadata
  ) external returns (UMATrigger) {
    // We need to do this because of stack-too-deep errors; there are too many
    // inputs/internal-vars to this function otherwise.
    DeployTriggerVars memory _vars;

    _vars.configId =
      triggerConfigId(_query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow);

    _vars.triggerCount = triggerCount[_vars.configId]++;
    _vars.salt = _getSalt(_vars.triggerCount, _rewardAmount);

    _vars.triggerAddress = computeTriggerAddress(
      _query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow, _vars.triggerCount
    );

    _rewardToken.safeTransferFrom(msg.sender, _vars.triggerAddress, _rewardAmount);

    _vars.trigger = new UMATrigger{salt: _vars.salt}(
      manager,
      oracle,
      _query,
      _rewardToken,
      _refundRecipient,
      _bondAmount,
      _proposalDisputeWindow
    );

    if (address(_vars.trigger) != _vars.triggerAddress) revert TriggerAddressMismatch();

    emit TriggerDeployed(
      address(_vars.trigger),
      _vars.configId,
      address(oracle),
      _query,
      address(_rewardToken),
      _rewardAmount,
      _refundRecipient,
      _bondAmount,
      _proposalDisputeWindow,
      _metadata.name,
      _metadata.category,
      _metadata.description,
      _metadata.logoURI
    );

    return _vars.trigger;
  }

  /// @notice Call this function to determine the address at which a trigger
  /// with the supplied configuration would be deployed. See `deployTrigger` for
  /// more information on parameters and their meaning.
  function computeTriggerAddress(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow,
    uint256 _triggerCount
  ) public view returns (address _address) {
    bytes memory _triggerConstructorArgs =
      abi.encode(manager, oracle, _query, _rewardToken, _refundRecipient, _bondAmount, _proposalDisputeWindow);

    // https://eips.ethereum.org/EIPS/eip-1014
    bytes32 _bytecodeHash = keccak256(bytes.concat(type(UMATrigger).creationCode, _triggerConstructorArgs));

    bytes32 _salt = _getSalt(_triggerCount, _rewardAmount);
    bytes32 _data = keccak256(bytes.concat(bytes1(0xff), bytes20(address(this)), _salt, _bytecodeHash));
    _address = address(uint160(uint256(_data)));
  }

  /// @notice Call this function to find triggers with the specified
  /// configurations that can be used for new markets in Sets. See
  /// `deployTrigger` for more information on parameters and their meaning.
  function findAvailableTrigger(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) public view returns (address) {
    bytes32 _counterId =
      triggerConfigId(_query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow);
    uint256 _triggerCount = triggerCount[_counterId];

    for (uint256 i = 0; i < _triggerCount; i++) {
      address _computedAddr = computeTriggerAddress(
        _query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow, i
      );

      UMATrigger _trigger = UMATrigger(_computedAddr);
      if (_trigger.getSetsLength() < _trigger.MAX_SET_LENGTH()) return _computedAddr;
    }

    return address(0); // If none is found, return zero address.
  }

  /// @notice Call this function to determine the identifier of the supplied
  /// trigger configuration. This identifier is used both to track the number of
  /// triggers deployed with this configuration (see `triggerCount`) and is
  /// emitted as a part of the TriggerDeployed event when triggers are deployed.
  /// @dev This function takes the rewardAmount as an input despite it not being
  /// an argument of the UMATrigger constructor nor it being held in storage by
  /// the trigger. This is done because the rewardAmount is something that
  /// deployers could reasonably differ on. Deployer A might deploy a trigger
  /// that is identical to what Deployer B wants in every way except the amount
  /// of rewardToken that is being offered, and it would still be reasonable for
  /// Deployer B to not want to re-use A's trigger for his own markets.
  function triggerConfigId(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) public view returns (bytes32) {
    bytes memory _triggerConfigData = abi.encode(
      manager, oracle, _query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow
    );
    return keccak256(_triggerConfigData);
  }

  function _getSalt(uint256 _triggerCount, uint256 _rewardAmount) private pure returns (bytes32) {
    // We use the reward amount in the salt so that triggers that are the same
    // except for their reward amount will still be deployed to different
    // addresses and can be differentiated. A trigger deployment with the same
    // _rewardAmount and _triggerCount should be the same across chains.
    return keccak256(bytes.concat(bytes32(_triggerCount), bytes32(_rewardAmount)));
  }
}

