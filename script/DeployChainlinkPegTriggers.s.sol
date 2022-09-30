// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "script/ScriptUtils.s.sol";
import "src/ChainlinkTriggerFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys Chainlink triggers for testing using a ChainlinkTriggerFactory.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployChainlinkPegTriggers.s.sol \
  *   --sig "run(string)" "deploy-chainlink-peg-triggers-<test or production>" \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast transactions with etherscan verification.
  * forge script script/DeployChainlinkPegTriggers.s.sol \
  *   --sig "run(string)" "deploy-chainlink-peg-triggers-<test or production>" \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployChainlinkPegTriggers is ScriptUtils {
  using stdJson for string;

  // -----------------------------------
  // -------- Configured Inputs --------
  // -----------------------------------

  // Note: The attributes in this struct must be in alphabetical order due to `parseJson` limitations.
  struct ChainlinkMetadata {
    // The amount of decimals used by the peg price and tracking oracle price.
    uint8 decimals;
    // A human-readable description of the intent of the trigger.
    string description;
    // The maximum amount of time we allow to elapse before the tracking oracle's price is deemed stale.
    uint256 frequencyTolerance;
    // Logo uri that describes the trigger, as it should appear within the Cozy user interface.
    string logoURI;
    // The name of the trigger, as it should appear within the Cozy interface.
    string name;
    // The peg price to compare the tracking oracle price to.
    int256 pegPrice;
    // The maximum percent delta between oracle prices that is allowed, as a wad.
    uint256 priceTolerance;
    // The oracle we expect to diverge.
    AggregatorV3Interface trackingOracle;
  }

  ChainlinkTriggerFactory factory;

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run(string memory _fileName) public {
    string memory _json = readInput(_fileName);

    factory = ChainlinkTriggerFactory(_json.readAddress(".chainlinkTriggerFactory"));
    // Loosely validate factory interface by ensuring `manager()` doesn't revert.
    factory.manager();

    ChainlinkMetadata[] memory _metadata = abi.decode(_json.parseRaw(".metadata"), (ChainlinkMetadata[]));

    for (uint i = 0; i < _metadata.length; i++) {
      _deployTrigger(_metadata[i]);
    }
  }

  function _deployTrigger(ChainlinkMetadata memory _metadata) internal {
    console2.log("Deploying ChainlinkTrigger...");
    console2.log("    chainlinkTriggerFactory", address(factory));
    console2.log("    pegPrice", uint256(_metadata.pegPrice));
    console2.log("    decimals", uint256(_metadata.decimals));
    console2.log("    trackingOracle", address(_metadata.trackingOracle));
    console2.log("    priceTolerance", _metadata.priceTolerance);
    console2.log("    frequencyTolerance", _metadata.frequencyTolerance);
    console2.log("    triggerName", _metadata.name);
    console2.log("    triggerDescription", _metadata.description);
    console2.log("    triggerLogoURI", _metadata.logoURI);

    // Loosely validate oracle interface by ensuring `description()` doesn't revert.
    _metadata.trackingOracle.description();

    AggregatorV3Interface _truthOracleAddress = AggregatorV3Interface(
      factory.computeFixedPriceAggregatorAddress(_metadata.pegPrice, _metadata.decimals)
    );

    // Check to see if a trigger has already been deployed with the desired configs.
    address _availableTrigger = factory.findAvailableTrigger(
      _truthOracleAddress,
      _metadata.trackingOracle,
      _metadata.priceTolerance,
      // For the truth FixedPriceAggregator peg oracle, we use a frequency
      // tolerance of 0 since it should always return block.timestamp as the
      // updatedAt timestamp.
      0,
      _metadata.frequencyTolerance
    );

    if (_availableTrigger == address(0)) {
      // There is no available trigger that has your desired configuration. We
      // will have to deploy a new one!
      vm.broadcast();
      _availableTrigger = address(
        factory.deployTrigger(
          _metadata.pegPrice,
          _metadata.decimals,
          _metadata.trackingOracle,
          _metadata.priceTolerance,
          _metadata.frequencyTolerance,
          IChainlinkTriggerFactory.TriggerMetadata(
            _metadata.name,
            _metadata.description,
            _metadata.logoURI
          )
        )
      );
      console2.log(
        "ChainlinkTrigger deployed",
        _availableTrigger
      );
    } else {
      // A trigger exactly like the one you wanted already exists!
      // Since triggers can be re-used, there's no need to deploy a new one.
      console2.log("Found existing trigger with specified configs.", _availableTrigger);
    }
    console2.log("========");
  }
}
