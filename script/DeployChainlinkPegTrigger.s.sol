// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/ChainlinkTriggerFactory.sol";
import "test/utils/MockChainlinkOracle.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys a Chainlink peg trigger using a ChainlinkTriggerFactory.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployChainlinkPegTrigger.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast transactions with etherscan verification.
  * forge script script/DeployChainlinkPegTrigger.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployChainlinkPegTrigger is Script {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  ChainlinkTriggerFactory factory = ChainlinkTriggerFactory(0xCd5a264CC34dAc1CB44Afcd41D8dA357fF37B864);

  int256 pegPrice = 1e8;
  uint8 decimals = 8;

  AggregatorV3Interface trackingOracle = AggregatorV3Interface(0xECef79E109e997bCA29c1c0897ec9d7b03647F5E);

  uint256 priceTolerance = 5000; // 50%
  uint256 frequencyTolerance = 24 hours;

  // The name of the trigger, as it should appear within the Cozy interface.
  string triggerName = "USDT Peg Protection";

  // A human-readable description of the intent of the trigger.
  string triggerDescription = "A trigger that toggles if the Chainlink USDT / USD oracle on Optimism diverges from $1.00 USD by more than 50%.";

  string triggerLogoURI = "https://s2.coinmarketcap.com/static/img/coins/64x64/825.png";

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run() public {
    console2.log("Deploying ChainlinkTrigger...");
    console2.log("    chainlinkTriggerFactory", address(factory));
    console2.log("    pegPrice", uint256(pegPrice));
    console2.log("    decimals", decimals);
    console2.log("    trackingOracle", address(trackingOracle));
    console2.log("    priceTolerance", priceTolerance);
    console2.log("    frequencyTolerance", frequencyTolerance);
    console2.log("    triggerName", triggerName);
    console2.log("    triggerDescription", triggerDescription);
    console2.log("    triggerLogoURI", triggerLogoURI);

    // First we attempt to deploy the fixed price truth oracle.
    vm.broadcast();
    AggregatorV3Interface _truthOracle = factory.deployFixedPriceAggregator(
      pegPrice,
      decimals
    );

    // Check to see if a trigger has already been deployed with the desired configs.
    address _availableTrigger = factory.findAvailableTrigger(
      _truthOracle,
      trackingOracle,
      priceTolerance,
      0, // The truth oracle frequency tolerance used by the factory.
      frequencyTolerance
    );

    if (_availableTrigger == address(0)) {
      // There is no available trigger that has your desired configuration. We
      // will have to deploy a new one!
      vm.broadcast();
      _availableTrigger = address(
        factory.deployTrigger(
          pegPrice,
          decimals,
          trackingOracle,
          priceTolerance,
          frequencyTolerance,
          ChainlinkTriggerFactory.TriggerMetadata(
            triggerName,
            triggerDescription,
            triggerLogoURI
          )
        )
      );
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
