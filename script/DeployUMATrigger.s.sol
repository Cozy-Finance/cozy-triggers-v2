// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/UMATriggerFactory.sol";

contract DeployUMATrigger is Script {
  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  UMATriggerFactory factory = UMATriggerFactory(0xa48666D91Ac494A3CCA96A3A4357d998d8619387);

  string query = "q: title: Hop Protocol, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in the Hop protocol on Ethereum Mainnet at any point after Ethereum Mainnet block number 114400? This will revert if a 'no' answer is proposed.";

  IERC20 rewardToken = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

  uint256 rewardAmount = 5e6;

  uint256 bondAmount = 5e6;

  uint256 proposalDisputeWindow = 1 hours;

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

    vm.broadcast();
    rewardToken.approve(address(factory), rewardAmount);

    vm.broadcast();
    UMATrigger trigger = factory.deployTrigger(query, rewardToken, rewardAmount, bondAmount, proposalDisputeWindow);
    console2.log("UMATrigger deployed", address(trigger));
  }
}
