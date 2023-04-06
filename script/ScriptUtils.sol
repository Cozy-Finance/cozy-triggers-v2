// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "forge-std/Script.sol";

contract ScriptUtils is Script {
  using stdJson for string;

  string INPUT_FOLDER = "/script/input/";

  // Returns the json string for the specified filename from `INPUT_FOLDER`.
  function readInput(string memory _fileName) internal returns (string memory) {
    string memory _root = vm.projectRoot();
    string memory _chainInputFolder = string.concat(INPUT_FOLDER, vm.toString(block.chainid), "/");
    string memory _inputFile = string.concat(_fileName, ".json");
    string memory _inputPath = string.concat(_root, _chainInputFolder, _inputFile);
    return vm.readFile(_inputPath);
  }
}
