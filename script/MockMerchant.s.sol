// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {MockMerchant} from "../src/MockMerchant.sol";

contract MockMerchantScript is Script {
  address public constant ethPriceFeed = address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    
    new MockMerchant(ethPriceFeed);
    
    vm.stopBroadcast();
  }
}
