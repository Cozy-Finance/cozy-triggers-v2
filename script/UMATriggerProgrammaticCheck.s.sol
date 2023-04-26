// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.16;

// import "script/ScriptUtils.sol";
// import "src/UMATrigger.sol";
// import "cozy-v2-interfaces/interfaces/ICozyLens.sol";
// import "cozy-v2-interfaces/interfaces/ISet.sol";
// import "cozy-v2-interfaces/interfaces/ITrigger.sol";

// contract UMATriggerProgrammaticCheck is ScriptUtils {
//   using stdJson for string;

//   // -----------------------------------
//   // -------- Configured Inputs --------
//   // -----------------------------------

//   // -------- Cozy Contracts --------

//   ICozyLens lens = ICozyLens(0x890ACDa47659778b61119898d6ECeC45877bCAc6);
//   UMATrigger trigger = UMATrigger(0xF40C3EF015B699cc70088c35efA2cC96aF5F8554);
//   ISet set = ISet(0xcC5C3F319Aae7a70236Bb53226c2D44e627e4A9a);

//   // ---------------------------
//   // -------- Execution --------
//   // ---------------------------

//   function run() public {
//     OptimisticOracleV2Interface oracle_ = trigger.oracle();

//     ICState.CState oldSetState_ = lens.getSetState(set);
//     console2.log("Old set state", uint8(oldSetState_));

//     ICState.CState oldMarketState_ = lens.getMarketState(set, address(trigger));
//     console2.log("Old market state", uint8(oldMarketState_));

//     vm.broadcast();
//     ICState.CState newState_ = trigger.runProgrammaticCheck();
//     console2.log("new trigger state", uint8(newState_));

//     ICState.CState newSetState_ = lens.getSetState(set);
//     console2.log("New set state", uint8(newSetState_));

//     ICState.CState newMarketState_ = lens.getMarketState(set, address(trigger));
//     console2.log("new market state", uint8(newMarketState_));

//   }
// }
