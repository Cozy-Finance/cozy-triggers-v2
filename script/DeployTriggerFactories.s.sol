// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "uma-protocol/packages/core/contracts/oracle/interfaces/FinderInterface.sol";
import "script/ScriptUtils.sol";
import "src/ChainlinkTriggerFactory.sol";
import "src/UMATriggerFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys Cozy trigger factories.
  * Before executing, the input json file `script/input/<chain-id>/deploy-trigger-factories-<test or production>.json`
  * should be reviewed.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployTriggerFactories.s.sol \
  *   --sig "run(string)" "deploy-trigger-factories-<test or production>" \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast transactions with etherscan verification.
  * forge script script/DeployTriggerFactories.s.sol \
  *   --sig "run(string)" "deploy-trigger-factories-<test or production>" \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployTriggerFactories is ScriptUtils {
  using stdJson for string;

  // -----------------------------------
  // -------- Configured Inputs --------
  // -----------------------------------

  // -------- Cozy Contracts --------

  IManager manager;

  // -------- UMA Trigger Factory --------

  // The UMA oracle finder on Optimism https://github.com/UMAprotocol/protocol/blob/f011a6531fbd7c09d22aa46ef04828cf98f7f854/packages/core/networks/10.json
  FinderInterface umaOracleFinder;

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run(string memory _fileName) public {
    string memory _json = readInput(_fileName);

    manager = IManager(_json.readAddress(".manager"));
    umaOracleFinder = FinderInterface(_json.readAddress(".umaOracleFinder"));

    // Loosely validate manager interface by ensuring `owner()` doesn't revert.
    manager.owner();

    console2.log("Deploying ChainlinkTriggerFactory...");
    console2.log("    manager", address(manager));
    vm.broadcast();
    address factory = address(new ChainlinkTriggerFactory(manager));
    console2.log("ChainlinkTriggerFactory deployed", factory);

    console2.log("====================");

    OptimisticOracleV2Interface _umaOracle = OptimisticOracleV2Interface(
      umaOracleFinder.getImplementationAddress(bytes32("OptimisticOracleV2"))
    );

    console2.log("Deploying UMATriggerFactory...");
    console2.log("    manager", address(manager));
    console2.log("    umaOracle", address(_umaOracle));
    vm.broadcast();
    factory = address(new UMATriggerFactory(manager, _umaOracle));
    console2.log("UMATriggerFactory deployed", factory);

    console2.log("====================");
  }
}
