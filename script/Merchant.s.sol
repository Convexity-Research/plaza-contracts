// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Merchant} from "../src/Merchant.sol";

contract MerchantScript is Script {
  // Uniswap V3 Router - Base Mainnet
  // address private constant ROUTER = address(0x2626664c2603336E57B271c5C0b26F421741e481);
  
  // Uniswap V3 Router - Base Sepolia Testnet
  address private constant ROUTER = address(0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4);

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    new Merchant(ROUTER);
    vm.stopBroadcast();
  }
}
