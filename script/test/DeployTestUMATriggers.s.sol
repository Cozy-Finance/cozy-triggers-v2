// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "src/UMATriggerFactory.sol";

/**
  * @notice Purpose: Local deploy, testing, and production.
  *
  * This script deploys UMA triggers for testing using an UMATriggerFactory.
  *
  * To run this script:
  *
  * ```sh
  * # Start anvil, forking from the current state of the desired chain.
  * anvil --fork-url $OPTIMISM_RPC_URL
  *
  * # In a separate terminal, perform a dry run the script.
  * forge script script/DeployTestUMATriggers.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   -vvvv
  *
  * # Or, to broadcast transactions with etherscan verification.
  * forge script script/DeployTestUMATriggers.s.sol \
  *   --rpc-url "http://127.0.0.1:8545" \
  *   --private-key $OWNER_PRIVATE_KEY \
  *   --etherscan-api-key $ETHERSCAN_KEY \
  *   --verify \
  *   --broadcast \
  *   -vvvv
  * ```
 */
contract DeployTestUMATriggers is Script {
  struct UMAMetadata {
    // The query submitted to the UMA Optimistic Oracle
    string query;
    // The name of the trigger, as it should appear within the Cozy user interface.
    string name;
    // A human-readable description of the intent of the trigger, as it should appear within the Cozy user interface.
    string description;
    // Logo uri that describes the trigger, as it should appear within the Cozy user interface.
    string logoURI;
  }

  // -------------------------------
  // -------- Configuration --------
  // -------------------------------

  UMATriggerFactory factory = UMATriggerFactory(0xa9aac1c32d182Df034b35435Eef5861a427F097D);

  CozyIERC20 rewardToken = CozyIERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

  uint256 rewardAmount = 5e6;

  address refundRecipient = address(0x682bd405073dD248527E40184898eD45BB827527);

  // It's recommended that the bond be at least twice as high as the reward.
  uint256 bondAmount = 10e6;

  // A long dispute window is recommended.
  uint256 proposalDisputeWindow = 1 days;

  function run() public {
    UMAMetadata[] memory _metadata = new UMAMetadata[](5);
    _metadata[0] = UMAMetadata({
      query: "q: title: Is it September 13 2022 in New York City?, description: Is it September 13 2022 in New York City? This will revert if a non-YES answer is proposed.",
      name: "Mock UMA Trigger",
      description: "This is a mock UMA trigger.",
      logoURI: "https://cryptologos.cc/logos/uma-uma-logo.png?v=023"
    });
    _metadata[1] = UMAMetadata({
      query: "q: title: Was there a Uniswap v3 hack?, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in Uniswap v3 (https://uniswap.org/) at any point after Ethereum Mainnet block number 15397652? This will revert if a non-YES answer is proposed.",
      name: "Uniswap v3 Protection",
      description: "Protects against general hacks and exploits on Uniswap v3. If something goes wrong, the UMA community can vote to trigger this market.",
      logoURI: "https://cryptologos.cc/logos/uniswap-uni-logo.svg?w=64&q=100"
    });
    _metadata[2] = UMAMetadata({
      query: "q: title: Was there an Aave v3 hack?, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in Aave v3 (https://aave.com/) at any point after Ethereum Mainnet block number 15397652? This will revert if a non-YES answer is proposed.",
      name: "Aave v3 Protection",
      description: "Protects against general hacks and exploits on Aave v3. If something goes wrong, the UMA community can vote to trigger this market.",
      logoURI: "https://cryptologos.cc/logos/aave-aave-logo.png?w=64&q=100"
    });
    _metadata[3] = UMAMetadata({
      query: "q: title: Was there a Curve 3pool hack?, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in the Curve 3pool (https://curve.fi/) at any point after Ethereum Mainnet block number 15397652? This will revert if a non-YES answer is proposed.",
      name: "Curve 3pool Protection",
      description: " Protects against general hacks and exploits on the Curve 3pool. If something goes wrong, the UMA community can vote to trigger this market.",
      logoURI: "https://cryptologos.cc/logos/curve-dao-token-crv-logo.png?w=64&q=100"
    });
    _metadata[4] = UMAMetadata({
      query: "q: title: Was there a Hop bridge hack?, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in the Hop bridge (https://hop.exchange/) at any point after Ethereum Mainnet block number 15397652? This will revert if a non-YES answer is proposed.",
      name: "Hop Bridge Protection",
      description: "Bridges can be dangerous and this trigger protects against general hacks and exploits for the Hop bridge. If something goes wrong, the UMA community can vote to trigger this market.",
      logoURI: "https://dev-cozy-ui-v2.vercel.app/images/platforms/hop.jpeg?w=64&q=100"
    });

    // ---------------------------
    // -------- Execution --------
    // ---------------------------

    for (uint i = 0; i < _metadata.length; i++) {
      _deployTrigger(_metadata[i]);
    }
  }

  function _deployTrigger(UMAMetadata memory _metadata) internal {
    console2.log("Deploying UMATrigger...");
    console2.log("    umaTriggerFactory", address(factory));
    console2.log("    query", _metadata.query);
    console2.log("    rewardToken", address(rewardToken));
    console2.log("    rewardAmount", rewardAmount);
    console2.log("    refundRecipient", refundRecipient);
    console2.log("    bondAmount", bondAmount);
    console2.log("    proposalDisputeWindow", proposalDisputeWindow);
    console2.log("    triggerName", _metadata.name);
    console2.log("    triggerDescription", _metadata.description);
    console2.log("    triggerLogoURI", _metadata.logoURI);

    // Check to see if a trigger has already been deployed with your desired configs.
    address _availableTrigger = factory.findAvailableTrigger(
      _metadata.query,
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
          _metadata.query,
          rewardToken,
          rewardAmount,
          refundRecipient,
          bondAmount,
          proposalDisputeWindow,
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
      console2.log("Found existing trigger with specified configs");
    }
    console2.log("========");
  }
}
