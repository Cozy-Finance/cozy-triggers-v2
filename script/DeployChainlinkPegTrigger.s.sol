// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/ChainlinkTriggerFactory.sol";
import "test/utils/MockChainlinkOracle.sol";

contract DeployChainlinkPegTrigger is Script {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  ChainlinkTriggerFactory factory = ChainlinkTriggerFactory(address(0x1eB3f4a379e7BfAf57331FC9BCb5b4763122E48B));

  int256 pegPrice = 1e8;
  uint8 decimals = 8;

  AggregatorV3Interface trackingOracle = AggregatorV3Interface(address(0x82f6491eF3bb1467C1cb283cDC7Df18B2B9b968E));

  uint256 priceTolerance = 5000; // 50%
  uint256 frequencyTolerance = 12 hours;

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

    vm.broadcast();
    ChainlinkTrigger trigger = factory.deployTrigger(pegPrice, decimals, trackingOracle, priceTolerance, frequencyTolerance);
    console2.log("ChainlinkTrigger deployed", address(trigger));
  }
}
