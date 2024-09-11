// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Router} from "../src/MockRouter.sol";

contract MockRouterScript is Script {
  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    new Router();
    vm.stopBroadcast();
  }
}
