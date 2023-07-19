// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "solmate/utils/FixedPointMathLib.sol";

import "src/abstract/BaseTrigger.sol";
import "src/interfaces/IRocketPoolOVMPriceOracle.sol";

/**
 * @notice A trigger contract that takes two addresses: a Chainlink oracle and a Rocket Pool OVM oracle.
 * This trigger ensures the Chainlink oracle is always above the given price tolerance with respect to the
 * Rocket Pool OVM oracle; the delta in prices can be equal to but not greater than the price tolerance.
 * @dev Rocket Pool OVM oracles are specific to Optimism. Thus, this trigger should only be used on Optimism.
 */
contract RocketPoolEthTrigger is BaseTrigger {
  using FixedPointMathLib for uint256;

  uint256 internal constant WAD_DECIMALS = 18;
  uint256 internal constant ZOC = 1e4;

  /// @notice The market rate Chainlink oracle, assumed to be correct.
  AggregatorV3Interface public immutable chainlinkOracle;

  /// @notice The Rocket Pool OVM oracle, reporting the exchange rate from Rocket Pool on L1.
  IRocketPoolOVMPriceOracle public immutable rocketPoolOracle;

  /// @notice The maximum amount greater that the rocketPoolOracle price is than the chainlinkOracle price that is
  /// allowed, expressed as a zoc.
  /// For example, a 0.2e4 priceTolerance would mean the rocketPoolOracle price is
  /// allowed to deviate from the chainlinkOracle price by up to +20%, but no more.
  /// Note that if the chainlinkOracle returns a price of 0, we treat the priceTolerance
  /// as having been exceeded, no matter what price the rocketPoolOracle returns.
  uint256 public immutable priceTolerance;

  /// @notice The maximum amount of time we allow to elapse before the Chainlink oracle's price is deemed stale.
  uint256 public immutable chainlinkFrequencyTolerance;

  /// @notice The maximum amount of time we allow to elapse before the Rocket Pool oracle's price is deemed stale.
  uint256 public immutable rocketPoolFrequencyTolerance;

  /// @dev Thrown when the Chainlink oracle's decimals does not equal 18 to match the Rocket Pool oracle.
  error InvalidDecimals();

  /// @dev Thrown when the `oracle`s price is negative.
  error InvalidPrice();

  /// @dev Thrown when the `priceTolerance` is greater than or equal to `ZOC`.
  error InvalidPriceTolerance();

  /// @dev Thrown when the `oracle`s price timestamp is greater than the block's timestamp.
  error InvalidTimestamp();

  /// @dev Thrown when the `oracle`s last update is more than `frequencyTolerance` seconds ago.
  error StaleOraclePrice();

  /// @param _manager Address of the Cozy protocol manager.
  /// @param _chainlinkOracle The canonical Chainlink oracle, assumed to be correct.
  /// @param _rocketPoolOracle The oracle reporting the Rocket Pool exchange rate, which we expect to diverge.
  /// @param _priceTolerance The maximum percent delta between oracle prices that is allowed, as a zoc.
  /// @param _chainlinkFrequencyTolerance The maximum amount of time we allow to elapse before the Chainlink oracle's price is
  /// deemed stale.
  /// @param _rocketPoolFrequencyTolerance The maximum amount of time we allow to elapse before the Rocket Pool oracle's
  /// price is deemed stale.
  constructor(
    IManager _manager,
    AggregatorV3Interface _chainlinkOracle,
    IRocketPoolOVMPriceOracle _rocketPoolOracle,
    uint256 _priceTolerance,
    uint256 _chainlinkFrequencyTolerance,
    uint256 _rocketPoolFrequencyTolerance
  ) BaseTrigger(_manager) {
    if (_priceTolerance >= ZOC) revert InvalidPriceTolerance();
    chainlinkOracle = _chainlinkOracle;
    rocketPoolOracle = _rocketPoolOracle;
    priceTolerance = _priceTolerance;
    chainlinkFrequencyTolerance = _chainlinkFrequencyTolerance;
    rocketPoolFrequencyTolerance = _rocketPoolFrequencyTolerance;

    if (chainlinkOracle.decimals() != WAD_DECIMALS) revert InvalidDecimals();

    runProgrammaticCheck();
  }

  /// @notice Compares the oracle's price to the reference oracle and toggles the trigger if required.
  /// @dev This method executes the `programmaticCheck()` and makes the
  /// required state changes both in the trigger and the sets.
  function runProgrammaticCheck() public returns (MarketState) {
    // Rather than revert if not active, we simply return the state and exit.
    // Both behaviors are acceptable, but returning is friendlier to the caller
    // as they don't need to handle a revert and can simply parse the
    // transaction's logs to know if the call resulted in a state change.
    if (state != MarketState.ACTIVE) return state;
    if (programmaticCheck()) return _updateTriggerState(MarketState.TRIGGERED);
    return state;
  }

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger
  /// state.
  /// @notice Chainlink triggers are programmatic, so this always returns true.
  function acknowledged() public pure override returns (bool) {
    return true;
  }

  /// @dev Executes logic to programmatically determine if the trigger should be toggled.
  function programmaticCheck() internal view returns (bool) {
    (, int256 _chainlinkPriceInt,, uint256 _chainlinkUpdatedAt,) = chainlinkOracle.latestRoundData();
    if (_chainlinkUpdatedAt > block.timestamp) revert InvalidTimestamp();
    if (block.timestamp - _chainlinkUpdatedAt > chainlinkFrequencyTolerance) revert StaleOraclePrice();
    if (_chainlinkPriceInt < 0) revert InvalidPrice();
    uint256 _chainlinkPrice = uint256(_chainlinkPriceInt);

    uint256 _rocketPoolPrice = rocketPoolOracle.rate();
    uint256 _rocketPoolUpdatedAt = rocketPoolOracle.lastUpdated();
    if (_rocketPoolUpdatedAt > block.timestamp) revert InvalidTimestamp();
    // If things work as expected, the only delay should be from waiting for transaction inclusion in blocks every 5760 L1 blocks.
    // If something goes wrong with Rocket Pool oracles, it might be delayed hours or days until software or nodes can be fixed.
    if (block.timestamp - _rocketPoolUpdatedAt > rocketPoolFrequencyTolerance) revert StaleOraclePrice();

    // We only perform a check if the Rocket Pool oracle price is greater than the Chainlink oracle price.
    if (_rocketPoolPrice > _chainlinkPrice) {
      uint256 _priceDelta = _rocketPoolPrice - _chainlinkPrice;

      // We round up when calculating the delta percentage to accommodate for precision loss to
      // ensure that the state becomes triggered when the delta is greater than the price tolerance.
      // When the delta is less than or exactly equal to the price tolerance, the resulting rounded
      // up value will not be greater than the price tolerance, as expected.
      return _chainlinkPrice > 0 ? _priceDelta.mulDivUp(ZOC, _chainlinkPrice) > priceTolerance : true;
    }

    return false;
  }
}
