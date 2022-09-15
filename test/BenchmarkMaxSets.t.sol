// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "test/utils/MinimalTrigger.sol";
import "test/utils/TriggerTestSetup.sol";

abstract contract MaxSetsBenchmarkTest is TriggerTestSetup {
  MinimalTrigger trigger;
  ISet[] sets;

  function setUpTrigger(uint256 _numSets) public {
    super.setUp();

    for (uint i = 0; i < _numSets; i++) {
      sets.push(set);
    }

    trigger = new MinimalTrigger(manager, sets);
    trigger.TEST_HOOK_acknowledge(true);
  }
}

contract MaxSetsBenchmarkTest1 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(1);
  }

  function test_Benchmark1() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest2 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(2);
  }

  function test_Benchmark2() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest3 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(3);
  }

  function test_Benchmark3() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest4 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(4);
  }

  function test_Benchmark4() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest5 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(5);
  }

  function test_Benchmark5() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest6 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(6);
  }

  function test_Benchmark6() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest7 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(7);
  }

  function test_Benchmark7() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest8 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(8);
  }

  function test_Benchmark8() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest9 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(9);
  }

  function test_Benchmark9() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest10 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(10);
  }

  function test_Benchmark10() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest11 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(11);
  }

  function test_Benchmark11() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest12 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(12);
  }

  function test_Benchmark12() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest13 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(13);
  }

  function test_Benchmark13() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest14 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(14);
  }

  function test_Benchmark14() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}


contract MaxSetsBenchmarkTest15 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(15);
  }

  function test_Benchmark15() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}


contract MaxSetsBenchmarkTest16 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(16);
  }

  function test_Benchmark16() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}


contract MaxSetsBenchmarkTest17 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(17);
  }

  function test_Benchmark17() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}


contract MaxSetsBenchmarkTest18 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(18);
  }

  function test_Benchmark18() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest19 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(19);
  }

  function test_Benchmark19() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest20 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(20);
  }

  function test_Benchmark20() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest21 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(21);
  }

  function test_Benchmark21() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest22 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(22);
  }

  function test_Benchmark22() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest23 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(23);
  }

  function test_Benchmark23() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest24 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(24);
  }

  function test_Benchmark24() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest25 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(25);
  }

  function test_Benchmark25() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest26 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(26);
  }

  function test_Benchmark26() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}


contract MaxSetsBenchmarkTest27 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(27);
  }

  function test_Benchmark27() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest28 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(28);
  }

  function test_Benchmark28() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest29 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(29);
  }

  function test_Benchmark29() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest30 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(30);
  }

  function test_Benchmark30() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest31 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(31);
  }

  function test_Benchmark31() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest32 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(32);
  }

  function test_Benchmark32() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest33 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(33);
  }

  function test_Benchmark33() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest34 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(34);
  }

  function test_Benchmark34() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest35 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(35);
  }

  function test_Benchmark35() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest36 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(36);
  }

  function test_Benchmark36() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest37 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(37);
  }

  function test_Benchmark37() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest38 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(38);
  }

  function test_Benchmark38() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}


contract MaxSetsBenchmarkTest39 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(39);
  }

  function test_Benchmark39() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}


contract MaxSetsBenchmarkTest40 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(40);
  }

  function test_Benchmark40() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest41 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(41);
  }

  function test_Benchmark41() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest42 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(42);
  }

  function test_Benchmark42() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest43 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(43);
  }

  function test_Benchmark43() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest44 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(44);
  }

  function test_Benchmark44() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest45 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(45);
  }

  function test_Benchmark45() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest46 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(46);
  }

  function test_Benchmark46() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest47 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(47);
  }

  function test_Benchmark47() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest48 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(48);
  }

  function test_Benchmark48() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest49 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(49);
  }

  function test_Benchmark49() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}

contract MaxSetsBenchmarkTest50 is MaxSetsBenchmarkTest {
  function setUp() public override {
    super.setUpTrigger(50);
  }

  function test_Benchmark50() public {
    trigger.TEST_HOOK_updateTriggerState(CState.TRIGGERED);
  }
}