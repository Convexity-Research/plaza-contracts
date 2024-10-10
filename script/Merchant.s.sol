// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Merchant} from "../src/Merchant.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";

contract MerchantScript is Script {
  // Uniswap V3 Router - Base Mainnet
  // address private constant ROUTER = address(0x2626664c2603336E57B271c5C0b26F421741e481);
  
  // Uniswap V3 Router - Base Sepolia Testnet
  // address private constant ROUTER = address(0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4);
  
  // Aerodrome Quoter - Base Mainnet 
  address private constant FACTORY = address(0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A);
  address private constant ROUTER = address(0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5);
  address private constant QUOTER = address(0x254cF9E1E6e233aa1AC962CB9B05b2cfeAaE15b0);

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    Upgrades.deployUUPSProxy("Merchant.sol", abi.encodeCall(Merchant.initialize, (ROUTER, QUOTER, FACTORY)));
    vm.stopBroadcast();
  }
}
