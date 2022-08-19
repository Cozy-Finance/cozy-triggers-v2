// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/ChainlinkTriggerFactory.sol";
import "test/utils/MockChainlinkOracle.sol";

contract DeployChainlinkPegTrigger is Script {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  ChainlinkTriggerFactory factory = ChainlinkTriggerFactory(0x1eB3f4a379e7BfAf57331FC9BCb5b4763122E48B);

  int256 pegPrice = 1e8;
  uint8 decimals = 8;

  AggregatorV3Interface trackingOracle = AggregatorV3Interface(0x82f6491eF3bb1467C1cb283cDC7Df18B2B9b968E);

  uint256 priceTolerance = 5000; // 50%
  uint256 frequencyTolerance = 12 hours;

  // The name of the trigger, as it should appear within the Cozy interface.
  string triggerName = "Peg Protection Trigger";

  // A human-readable description of the intent of the trigger.
  string triggerDescription = "A trigger that toggles if the asset depegs";

  string triggerLogoURI = "https://s2.coinmarketcap.com/static/img/coins/64x64/8085.png";

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
