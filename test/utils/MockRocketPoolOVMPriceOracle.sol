// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "src/interfaces/IRocketPoolOVMPriceOracle.sol";

contract MockRocketPoolOVMPriceOracle is IRocketPoolOVMPriceOracle {

  uint256 public rate;
  uint256 public lastUpdated;

  constructor(uint256 _rate, uint256 _lastUpdated) {
    rate = _rate;
    lastUpdated = _lastUpdated;
  }

  function TEST_HOOK_setRate(uint256 _newRate) public {
    rate = _newRate;
  }

  function TEST_HOOK_setLastUpdated(uint256 _newLastUpdated) public {
    lastUpdated = _newLastUpdated;
  }
}
