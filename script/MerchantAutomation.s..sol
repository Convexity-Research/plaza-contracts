// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MerchantAutomation} from "../src/MerchantAutomation.sol";

contract MerchantAutomationScript is Script {

  // Base Mainnet
  address private constant MERCHANT = address(0xA5380Dc90b6a229E6613E7f383eDF59281f1f97c);
  address private constant POOL_FACTORY = address(0x2EEf81CB6c1B21b1aeBeB134825465A2e2CA55bF);

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    new MerchantAutomation(MERCHANT, POOL_FACTORY);
    vm.stopBroadcast();
  }
}
