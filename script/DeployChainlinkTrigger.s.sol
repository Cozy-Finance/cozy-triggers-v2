// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/ChainlinkTriggerFactory.sol";

contract DeployChainlinkTrigger is Script {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  ChainlinkTriggerFactory factory = ChainlinkTriggerFactory(0x1eB3f4a379e7BfAf57331FC9BCb5b4763122E48B);

  AggregatorV3Interface truthOracle = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5); // https://data.chain.link/optimism/mainnet/crypto-usd/eth-usd
  AggregatorV3Interface trackingOracle = AggregatorV3Interface(0x41878779a388585509657CE5Fb95a80050502186); // https://data.chain.link/optimism/mainnet/crypto-usd/steth-usd

  uint256 priceTolerance = 5000;
  uint256 truthFrequencyTolerance = 1201;
  uint256 trackingFrequencyTolerance = 86401;

  // The name of the trigger, as it should appear within the Cozy interface.
  string triggerName = "stETH/ETH Trigger";

  // A human-readable description of the intent of the trigger.
  string triggerDescription = "A trigger that toggles if stETH depegs from ETH";

  string triggerLogoURI = "https://s2.coinmarketcap.com/static/img/coins/64x64/8085.png";

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run() public {
    console2.log("Deploying ChainlinkTrigger...");
    console2.log("    chainlinkTriggerFactory", address(factory));
    console2.log("    truthOracle", address(truthOracle));
    console2.log("    trackingOracle", address(trackingOracle));
    console2.log("    priceTolerance", priceTolerance);
    console2.log("    truthFrequencyTolerance", truthFrequencyTolerance);
    console2.log("    trackingFrequencyTolerance", trackingFrequencyTolerance);

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
      vm.broadcast();
      _availableTrigger = address(
        factory.deployTrigger(
          truthOracle,
          trackingOracle,
          priceTolerance,
          truthFrequencyTolerance,
          trackingFrequencyTolerance,
          ChainlinkTriggerFactory.TriggerMetadata(
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
