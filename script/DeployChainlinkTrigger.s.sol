// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "script/ScriptUtils.s.sol";
import "src/ChainlinkTriggerFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys a Chainlink trigger using a ChainlinkTriggerFactory.
  * The private key of an EOA that will be used for transactions in this script must be set in .env.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployChainlinkTrigger.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast transactions with etherscan verification.
  * forge script script/DeployChainlinkTrigger.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployChainlinkTrigger is ScriptUtils {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  ChainlinkTriggerFactory factory = ChainlinkTriggerFactory(0x52acaC2C49CCEC6BE4A762811C62A1208248db33);

  AggregatorV3Interface truthOracle = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5); // https://data.chain.link/optimism/mainnet/crypto-usd/eth-usd
  AggregatorV3Interface trackingOracle = AggregatorV3Interface(0x41878779a388585509657CE5Fb95a80050502186); // https://data.chain.link/optimism/mainnet/crypto-usd/steth-usd

  uint256 priceTolerance = 5000;
  uint256 truthFrequencyTolerance = 1200;
  uint256 trackingFrequencyTolerance = 86400;

  // The name of the trigger, as it should appear within the Cozy interface.
  string triggerName = "stETH Depeg Protection";

  // A human-readable description of the intent of the trigger.
  string triggerDescription = "Protects against the de-pegging of stETH to ETH on Lido.";

  string triggerLogoURI = "https://s2.coinmarketcap.com/static/img/coins/64x64/8085.png";

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run() public {
    super.loadDeployerKey();

    console2.log("Deploying ChainlinkTrigger...");
    console2.log("    chainlinkTriggerFactory", address(factory));
    console2.log("    truthOracle", address(truthOracle));
    console2.log("    trackingOracle", address(trackingOracle));
    console2.log("    priceTolerance", priceTolerance);
    console2.log("    truthFrequencyTolerance", truthFrequencyTolerance);
    console2.log("    trackingFrequencyTolerance", trackingFrequencyTolerance);
    console2.log("    triggerName", triggerName);
    console2.log("    triggerDescription", triggerDescription);
    console2.log("    triggerLogoURI", triggerLogoURI);

    // Check to see if a trigger has already been deployed with the desired configs.
    address _availableTrigger = factory.findAvailableTrigger(
      truthOracle,
      trackingOracle,
      priceTolerance,
      truthFrequencyTolerance,
      trackingFrequencyTolerance
    );

    if (_availableTrigger == address(0)) {
      // There is no available trigger that has your desired configuration. We
      // will have to deploy a new one!
      vm.broadcast(privateKey);
      _availableTrigger = address(
        factory.deployTrigger(
          truthOracle,
          trackingOracle,
          priceTolerance,
          truthFrequencyTolerance,
          trackingFrequencyTolerance,
          IChainlinkTriggerFactory.TriggerMetadata(
            triggerName,
            triggerDescription,
            triggerLogoURI
          )
        )
      );
      console2.log("New trigger deployed!");
    } else {
      // A trigger exactly like the one you wanted already exists!
      // Since triggers can be re-used, there's no need to deploy a new one.
      console2.log("Found existing trigger with specified configs.");
    }

    console2.log(
      "Your ChainlinkTrigger is available at this address:",
      _availableTrigger
    );
  }
}
