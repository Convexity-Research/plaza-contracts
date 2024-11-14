// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Router} from "../src/MockRouter.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";

contract MockRouterScript is Script {
  // Sepolia Base
  address public constant ethPriceFeed = address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);

  address public constant reserveToken = address(0x13e5FB0B6534BB22cBC59Fae339dbBE0Dc906871);
  address public constant USD = address(0);

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    
    OracleFeeds oracleFeeds = new OracleFeeds();
    oracleFeeds.setPriceFeed(reserveToken, USD, ethPriceFeed, 1 days);

    new Router(oracleFeeds);
    vm.stopBroadcast();
  }
}
