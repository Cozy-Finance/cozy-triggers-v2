// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/ChainlinkTriggerFactory.sol";
import "src/UMATriggerFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys Cozy trigger factories.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployTriggerFactories.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast transactions with etherscan verification.
  * forge script script/DeployTriggerFactories.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployTriggerFactories is Script {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  // -------- Cozy Contracts --------

  IManager manager = IManager(0x1f513585D8bB1F994b37F2aaAB3F8499E52ca534);

  // -------- UMA Trigger Factory --------

  // Using te UMA oracle finder on Optimism (https://github.com/UMAprotocol/protocol/blob/f011a6531fbd7c09d22aa46ef04828cf98f7f854/packages/core/networks/10.json),
  // you can obtain the OptimisticOracleV2 contract with Finder.getImplementationAddress(bytes32("OptimisticOracleV2")).
  OptimisticOracleV2Interface umaOracle = OptimisticOracleV2Interface(0x255483434aba5a75dc60c1391bB162BCd9DE2882);

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
    console2.log("    umaOracle", address(umaOracle));
    vm.broadcast();
    factory = address(new UMATriggerFactory(manager, umaOracle));
    console2.log("UMATriggerFactory deployed", factory);

    console2.log("====================");
  }
}
