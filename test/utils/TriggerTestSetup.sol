// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "src/interfaces/IBaseTrigger.sol";

// import {IBaseTrigger} from "src/interfaces/IBaseTrigger.sol";
import {ICostModel} from "src/interfaces/ICostModel.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
// import {IManager} from "src/interfaces/IManager.sol";
// import {ISet} from "src/interfaces/ISet.sol";
// import {ITrigger} from "src/interfaces/ITrigger.sol";
import {SetConfig} from "src/structs/Configs.sol";
import {MarketState} from "src/structs/StateEnums.sol";

contract TriggerTestSetup is Test {
  using stdStorage for StdStorage;

  bytes32 constant salt = bytes32(uint256(1234)); // Arbitrary default salt value.

  address localOwner;
  address localPauser;

  IManager manager;
  ISet set;
  ISet set2;
  ICostModel costModel;
  IERC20 asset;
  SetConfig setConfig;

  /// @dev Emitted when a new set is added to the trigger's list of sets.
  event SetAdded(ISet set);

  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(MarketState indexed state);

  function setUp() public virtual {
    // Create addresses.
    asset = IERC20(makeAddr("asset"));
    costModel = ICostModel(makeAddr("costModel"));
    localOwner = makeAddr("localOwner");
    localPauser = makeAddr("localPauser");
    manager = IManager(makeAddr("manager"));
    set = ISet(makeAddr("set"));
    set2 = ISet(makeAddr("set2"));

    // Mock responses.
    // By default, all sets exist.
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IManager.isSet.selector),
      abi.encode(true) // Set exists and is approved for backstop, config update time and deadline are zero.
    );
  }

  // -----------------------------------
  // -------- Cheatcode Helpers --------
  // -----------------------------------


  // Helper methods.
  function updateTriggerState(ITrigger _trigger, MarketState _val) public {
    stdstore.target(address(_trigger)).sig("state()").checked_write(uint256(_val));
    assertEq(_trigger.state(), _val);
  }

  // ---------------------------------------
  // -------- Additional Assertions --------
  // ---------------------------------------

  function assertEq(IManager a, IManager b) internal {
    assertEq(address(a), address(b));
  }

  function assertEq(AggregatorV3Interface a, AggregatorV3Interface b) internal {
    assertEq(address(a), address(b));
  }

  function assertEq(MarketState a, MarketState b) internal {
    if (a != b) {
      emit log("Error: a == b not satisfied [MarketState]");
      emit log_named_uint("  Expected", uint256(b));
      emit log_named_uint("    Actual", uint256(a));
      fail();
    }
  }

  function assertNotEq(uint256 a, uint256 b) internal {
    if (a == b) {
      emit log("Error: a != b not satisfied [uint256]");
      emit log_named_uint("    Both values", a);
      fail();
    }
  }

  function assertNotEq(address a, address b) internal {
    if (a == b) {
      emit log("Error: a != b not satisfied [address]");
      emit log_named_address("    Both values", a);
      fail();
    }
  }

  function assertNotEq(ITrigger a, ITrigger b) internal {
    if (a == b) {
      emit log("Error: a != b not satisfied [ITrigger]");
      emit log_named_address("    Both values", address(a));
      fail();
    }
  }

  function assertNotEq(AggregatorV3Interface a, AggregatorV3Interface b) internal {
    if (a == b) {
      emit log("Error: a != b not satisfied [AggregatorV3Interface]");
      emit log_named_address("    Both values", address(a));
      fail();
    }
  }
}
