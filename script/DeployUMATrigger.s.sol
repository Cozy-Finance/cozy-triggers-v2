// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/UMATriggerFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys an UMA trigger using an UMATriggerFactory.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployUMATrigger.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast transactions with etherscan verification.
  * forge script script/DeployUMATrigger.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployUMATrigger is Script {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  UMATriggerFactory factory = UMATriggerFactory(0x87A848fA89917988F4B9E4518CeBc82b9e998a4B);

  string query = "q: title: Was there a Uniswap v3 hack?, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in Uniswap v3 (https://uniswap.org/) at any point after Ethereum Mainnet block number 15397652? This will revert if a non-YES answer is proposed.";

  IERC20 rewardToken = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

  uint256 rewardAmount = 5e6;

  address refundRecipient = address(0x682bd405073dD248527E40184898eD45BB827527);

  // It's recommended that the bond be at least twice as high as the reward.
  uint256 bondAmount = 10e6;

  // A long dispute window is recommended.
  uint256 proposalDisputeWindow = 2 days;

  // The name of the trigger, as it should appear within the Cozy interface.
  string triggerName = "Uniswap v3 Protection";

  // A human-readable description of the intent of the trigger.
  string triggerDescription = "Protects against general hacks and exploits on Uniswap v3. If something goes wrong, the UMA community can vote to trigger this market.";

  string triggerLogoURI = "https://cryptologos.cc/logos/uniswap-uni-logo.svg?w=64&q=100";

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run() public {
    console2.log("Deploying UMATrigger...");
    console2.log("    umaTriggerFactory", address(factory));
    console2.log("    query", query);
    console2.log("    rewardToken", address(rewardToken));
    console2.log("    rewardAmount", rewardAmount);
    console2.log("    refundRecipient", refundRecipient);
    console2.log("    bondAmount", bondAmount);
    console2.log("    proposalDisputeWindow", proposalDisputeWindow);
    console2.log("    triggerName", triggerName);
    console2.log("    triggerDescription", triggerDescription);
    console2.log("    triggerLogoURI", triggerLogoURI);

    // Check to see if a trigger has already been deployed with your desired configs.
    address _availableTrigger = factory.findAvailableTrigger(
      query,
      rewardToken,
      rewardAmount,
      refundRecipient,
      bondAmount,
      proposalDisputeWindow
    );

    if (_availableTrigger == address(0)) {

      // There is no available trigger that has your desired configuration. We
      // will have to deploy a new one! First we approve the factory to transfer
      // the reward for us.
      vm.broadcast();
      rewardToken.approve(address(factory), rewardAmount);

      // Then we deploy the trigger.
      vm.broadcast();
      _availableTrigger = address(
        factory.deployTrigger(
          query,
          rewardToken,
          rewardAmount,
          refundRecipient,
          bondAmount,
          proposalDisputeWindow,
          triggerName,
          triggerDescription,
          triggerLogoURI
        )
      );
      console2.log("New trigger deployed!");

    } else {
      // A trigger exactly like the one you wanted already exists!
      // Since triggers can be re-used, there's no need to deploy a new one.
      console2.log("Found existing trigger with specified configs");
    }

    console2.log(
      "Your UMA trigger is available at this address:",
      _availableTrigger
    );
  }
}
