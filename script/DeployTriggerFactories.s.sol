// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/ChainlinkTriggerFactory.sol";
import "src/UMATriggerFactory.sol";

contract DeployTriggerFactories is Script {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  // -------- Cozy Contracts --------

  IManager manager = IManager(address(0));

  // -------- UMA Trigger Factory --------

  // The UMA oracle finder on Optimism https://github.com/UMAprotocol/protocol/blob/f011a6531fbd7c09d22aa46ef04828cf98f7f854/packages/core/networks/10.json
  FinderInterface oracleFinder = FinderInterface(0x278d6b1aA37d09769E519f05FcC5923161A8536D);

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run() public {
    console2.log("Deploying ChainlinkTriggerFactory...");
    console2.log("    manager", address(manager));
    vm.broadcast();
    address factory = address(new ChainlinkTriggerFactory(manager));
    console2.log("ChainlinkTriggerFactory deployed", factory);

    console2.log("====================");

    console2.log("Deploying UMATriggerFactory...");
    console2.log("    manager", address(manager));
    console2.log("    oracleFinder", address(oracleFinder));
    vm.broadcast();
    factory = address(new UMATriggerFactory(manager, oracleFinder));
    console2.log("UMATriggerFactory deployed", factory);

    console2.log("====================");
  }
}
