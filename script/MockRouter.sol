// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Router} from "../src/MockRouter.sol";

contract MockRouterScript is Script {
  // Sepolia Base
  address public constant ethPriceFeed = address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    new Router(ethPriceFeed);
    vm.stopBroadcast();
  }
}
