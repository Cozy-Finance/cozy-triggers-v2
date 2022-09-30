// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "script/ScriptUtils.sol";
import "src/UMATriggerFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys UMA triggers for testing using an UMATriggerFactory.
  * Before executing, the input json file `script/input/<chain-id>/deploy-uma-triggers-<test or production>.json`
  * should be reviewed.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployUMATriggers.s.sol \
  *   --sig "run(string)" "deploy-uma-triggers-<test or production>" \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast transactions with etherscan verification.
  * forge script script/DeployUMATriggers.s.sol \
  *   --sig "run(string)" "deploy-uma-triggers-<test or production>" \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployUmaTriggers is ScriptUtils {
  using stdJson for string;

  // -----------------------------------
  // -------- Configured Inputs --------
  // -----------------------------------

  // Note: The attributes in this struct must be in alphabetical order due to `parseJson` limitations.
  struct UMAMetadata {
    // It's recommended that the bond be at least twice as high as the reward.
    uint256 bondAmount;
    // A human-readable description of the intent of the trigger, as it should appear within the Cozy user interface.
    string description;
    // Logo uri that describes the trigger, as it should appear within the Cozy user interface.
    string logoURI;
    // The name of the trigger, as it should appear within the Cozy user interface.
    string name;
    // A long dispute window is recommended.
    uint256 proposalDisputeWindow;
    // The query submitted to the UMA Optimistic Oracle.
    string query;
    // The recipient of any leftover reward tokens if they exist after the UMA query is settled.
    address refundRecipient;
    // The amount of reward tokens to pay to users that propose answers to the query.
    uint256 rewardAmount;
    // The token used to pay the reward to users that propose answers to the query. The reward token must be approved
    // by UMA governance. Approved tokens can be found with the UMA AddressWhitelist contract on each chain supported by UMA.
    CozyIERC20 rewardToken;
  }

  UMATriggerFactory factory;

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run(string memory _fileName) public {
    string memory _json = readInput(_fileName);

    factory = UMATriggerFactory(_json.readAddress(".umaTriggerFactory"));
    // Loosely validate factory interface by ensuring `oracle()` doesn't revert.
    factory.oracle();

    UMAMetadata[] memory _metadata = abi.decode(_json.parseRaw(".metadata"), (UMAMetadata[]));

    for (uint i = 0; i < _metadata.length; i++) {
      _deployTrigger(_metadata[i]);
    }
  }

  function _deployTrigger(UMAMetadata memory _metadata) internal {
    console2.log("Deploying UMATrigger...");
    console2.log("    umaTriggerFactory", address(factory));
    console2.log("    query", _metadata.query);
    console2.log("    rewardToken", address(_metadata.rewardToken));
    console2.log("    rewardAmount", _metadata.rewardAmount);
    console2.log("    refundRecipient", _metadata.refundRecipient);
    console2.log("    bondAmount", _metadata.bondAmount);
    console2.log("    proposalDisputeWindow", _metadata.proposalDisputeWindow);
    console2.log("    triggerName", _metadata.name);
    console2.log("    triggerDescription", _metadata.description);
    console2.log("    triggerLogoURI", _metadata.logoURI);

    // Loosely validate reward token interface by ensuring `totalSupply()` doesn't revert.
    _metadata.rewardToken.totalSupply();

    // Check to see if a trigger has already been deployed with your desired configs.
    address _availableTrigger = factory.findAvailableTrigger(
      _metadata.query,
      _metadata.rewardToken,
      _metadata.rewardAmount,
      _metadata.refundRecipient,
      _metadata.bondAmount,
      _metadata.proposalDisputeWindow
    );

    if (_availableTrigger == address(0)) {

      // There is no available trigger that has your desired configuration. We
      // will have to deploy a new one! First we approve the factory to transfer
      // the reward for us.
      vm.broadcast();
      _metadata.rewardToken.approve(address(factory), _metadata.rewardAmount);

      // Then we deploy the trigger.
      vm.broadcast();
      _availableTrigger = address(
        factory.deployTrigger(
          _metadata.query,
          _metadata.rewardToken,
          _metadata.rewardAmount,
          _metadata.refundRecipient,
          _metadata.bondAmount,
          _metadata.proposalDisputeWindow,
          _metadata.name,
          _metadata.description,
          _metadata.logoURI
        )
      );
      console2.log(
        "UMATrigger deployed",
        _availableTrigger
      );
    } else {
      // A trigger exactly like the one you wanted already exists!
      // Since triggers can be re-used, there's no need to deploy a new one.
      console2.log("Found existing trigger with specified configs", _availableTrigger);
    }
    console2.log("========");
  }
}
