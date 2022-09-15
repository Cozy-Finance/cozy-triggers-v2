// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "script/ScriptUtils.s.sol";
import "uma-protocol/packages/core/contracts/oracle/interfaces/FinderInterface.sol";
import "src/ChainlinkTriggerFactory.sol";
import "src/UMATriggerFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys Cozy trigger factories.
  * The private key of an EOA that will be used for transactions in this script must be set in .env.
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
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployTriggerFactories is ScriptUtils {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  // -------- Cozy Contracts --------

  IManager manager = IManager(0xc073F373F207a77759fb2184b1CFE1DDd4598D65);

  // -------- UMA Trigger Factory --------

  // The UMA oracle finder on Optimism https://github.com/UMAprotocol/protocol/blob/f011a6531fbd7c09d22aa46ef04828cf98f7f854/packages/core/networks/10.json
  FinderInterface umaOracleFinder = FinderInterface(0x278d6b1aA37d09769E519f05FcC5923161A8536D);

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run() public {
    super.loadDeployerKey();

    console2.log("Deploying ChainlinkTriggerFactory...");
    console2.log("    manager", address(manager));
    vm.broadcast(privateKey);
    address factory = address(new ChainlinkTriggerFactory(manager));
    console2.log("ChainlinkTriggerFactory deployed", factory);

    console2.log("====================");

    OptimisticOracleV2Interface _umaOracle = OptimisticOracleV2Interface(
      umaOracleFinder.getImplementationAddress(bytes32("OptimisticOracleV2"))
    );

    console2.log("Deploying UMATriggerFactory...");
    console2.log("    manager", address(manager));
    console2.log("    umaOracle", address(_umaOracle));
    vm.broadcast(privateKey);
    factory = address(new UMATriggerFactory(manager, _umaOracle));
    console2.log("UMATriggerFactory deployed", factory);

    console2.log("====================");
  }
}
