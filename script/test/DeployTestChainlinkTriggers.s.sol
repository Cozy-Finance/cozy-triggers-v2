// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
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
  * forge script script/DeployTestChainlinkTriggers.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast transactions with etherscan verification.
  * forge script script/DeployTestChainlinkTriggers.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployTestChainlinkTriggers is Script {
  struct ChainlinkMetadata {
    // The canonical oracle, assumed to be correct.
    AggregatorV3Interface truthOracle;
    // The oracle we expect to diverge.
    AggregatorV3Interface trackingOracle;
    // The maximum percent delta between oracle prices that is allowed, as a wad.
    uint256 priceTolerance;
    // The maximum amount of time we allow to elapse before the truth oracle's price is deemed stale.
    uint256 truthFrequencyTolerance;
    // The maximum amount of time we allow to elapse before the tracking oracle's price is deemed stale.
    uint256 trackingFrequencyTolerance;
    // The name of the trigger, as it should appear within the Cozy interface.
    string name;
    // A human-readable description of the intent of the trigger.
    string description;
    // Logo uri that describes the trigger, as it should appear within the Cozy user interface.
    string logoURI;
  }

  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  ChainlinkTriggerFactory factory = ChainlinkTriggerFactory(0xe1e132Dc16A5eDFe60671a2128122a81Aa19970C);

  function run() public {
    ChainlinkMetadata[] memory _metadata = new ChainlinkMetadata[](1);
    _metadata[0] = ChainlinkMetadata({
      truthOracle: AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5), // https://data.chain.link/optimism/mainnet/crypto-usd/eth-usd
      trackingOracle: AggregatorV3Interface(0x41878779a388585509657CE5Fb95a80050502186), // https://data.chain.link/optimism/mainnet/crypto-usd/steth-usd
      priceTolerance: 5000,
      truthFrequencyTolerance: 1200,
      trackingFrequencyTolerance: 86400,
      name: "stETH Depeg Protection",
      description: "Protects against the de-pegging of stETH to ETH on Lido.",
      logoURI: "https://s2.coinmarketcap.com/static/img/coins/64x64/8085.png"
    });

    // ---------------------------
    // -------- Execution --------
    // ---------------------------

    for (uint i = 0; i < _metadata.length; i++) {
      _deployTrigger(_metadata[i]);
    }
  }

  function _deployTrigger(ChainlinkMetadata memory _metadata) internal {
    console2.log("Deploying ChainlinkTrigger...");
    console2.log("    chainlinkTriggerFactory", address(factory));
    console2.log("    truthOracle", address(_metadata.truthOracle));
    console2.log("    trackingOracle", address(_metadata.trackingOracle));
    console2.log("    priceTolerance", _metadata.priceTolerance);
    console2.log("    truthFrequencyTolerance", _metadata.truthFrequencyTolerance);
    console2.log("    trackingFrequencyTolerance", _metadata.trackingFrequencyTolerance);
    console2.log("    triggerName", _metadata.name);
    console2.log("    triggerDescription", _metadata.description);
    console2.log("    triggerLogoURI", _metadata.logoURI);

    // Check to see if a trigger has already been deployed with the desired configs.
    address _availableTrigger = factory.findAvailableTrigger(
      _metadata.truthOracle,
      _metadata.trackingOracle,
      _metadata.priceTolerance,
      _metadata.truthFrequencyTolerance,
      _metadata.trackingFrequencyTolerance
    );

    if (_availableTrigger == address(0)) {
      // There is no available trigger that has your desired configuration. We
      // will have to deploy a new one!
      vm.broadcast();
      _availableTrigger = address(
        factory.deployTrigger(
          _metadata.truthOracle,
          _metadata.trackingOracle,
          _metadata.priceTolerance,
          _metadata.truthFrequencyTolerance,
          _metadata.trackingFrequencyTolerance,
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
      console2.log("Found existing trigger with specified configs.");
    }
    console2.log("========");
  }
}
