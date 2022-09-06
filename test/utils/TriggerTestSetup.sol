// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "cozy-v2-interfaces/interfaces/IBaseTrigger.sol";

contract TriggerTestSetup is Test, IConfig, ICState {
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
  event TriggerStateUpdated(CState indexed state);

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
      abi.encodeWithSelector(IManager.sets.selector),
      abi.encode(true, true, 0, 0) // Set exists and is approved for backstop, config update time and deadline are zero.
    );
  }

  // -----------------------------------
  // -------- Cheatcode Helpers --------
  // -----------------------------------


  // Helper methods.
  function updateTriggerState(ITrigger _trigger, ICState.CState _val) public {
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

  function assertEq(ICState.CState a, ICState.CState b) internal {
    if (a != b) {
      emit log("Error: a == b not satisfied [ICState.CState]");
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
