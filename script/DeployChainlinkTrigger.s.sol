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

    vm.broadcast();
    ChainlinkTrigger trigger = factory.deployTrigger(truthOracle, trackingOracle, priceTolerance, truthFrequencyTolerance, trackingFrequencyTolerance);
    console2.log("ChainlinkTrigger deployed", address(trigger));
  }
}
