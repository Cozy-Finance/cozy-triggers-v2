pragma solidity 0.8.15;

import "forge-std/Script.sol";

contract ScriptUtils is Script {

  string constant PRIVATE_KEY = "PRIVATE_KEY";

  // The private key in your .env used for script transactions, assigned in run().
  uint256 privateKey;

  function loadDeployerKey() internal {
    privateKey = vm.envUint(PRIVATE_KEY);
    console2.log("Account used for transactions", vm.addr(privateKey));
    console2.log("====================");
  }
}