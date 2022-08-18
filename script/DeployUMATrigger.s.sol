// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/UMATriggerFactory.sol";

contract DeployUMATrigger is Script {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  UMATriggerFactory factory = UMATriggerFactory(0xa48666D91Ac494A3CCA96A3A4357d998d8619387);

  string query = "q: title: Was there a Hop Protocol hack?, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in the Hop protocol (https://app.hop.exchange) on Ethereum Mainnet at any point after Ethereum Mainnet block number 114400? This will revert if a non-YES answer is proposed.";

  IERC20 rewardToken = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

  uint256 rewardAmount = 5e6;

  // It's recommended that the bond be at least twice as high as the reward.
  uint256 bondAmount = 10e6;

  // A long dispute window is recommended.
  uint256 proposalDisputeWindow = 2 days;

  // The name of the trigger, as it should appear within the Cozy interface.
  string triggerName = "Hop hack trigger";

  // A human-readable description of the intent of the trigger.
  string triggerDescription = "A trigger that toggles if the Hop protocol is hacked";

  string triggerLogoURI = "https://twitter.com/HopProtocol/photo";

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run() public {
    console2.log("Deploying UMATrigger...");
    console2.log("    umaTriggerFactory", address(factory));
    console2.log("    query", query);
    console2.log("    rewardToken", address(rewardToken));
    console2.log("    rewardAmount", rewardAmount);
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
      bondAmount,
      proposalDisputeWindow
    );

    if (_availableTrigger == address(0)) {

      // There is no available trigger that has your desired configuration. We will
      // have to deploy a new one! First we approve the factory to transfer the
      // reward for us.
      vm.broadcast();
      rewardToken.approve(address(factory), rewardAmount);

      // Then we deploy the trigger.
      vm.broadcast();
      _availableTrigger = address(
        factory.deployTrigger(
          query,
          rewardToken,
          rewardAmount,
          bondAmount,
          proposalDisputeWindow,
          UMATriggerFactory.TriggerMetadata(
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
      console2.log("Found existing trigger with specified configs");
    }

    console2.log(
      "Your UMA trigger is available at this address:",
      _availableTrigger
    );
  }
}
