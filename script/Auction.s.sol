// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Auction} from "../src/Auction.sol";

// @todo: remove - not meant for production - just for testing

contract AuctionScript is Script {
    Auction public auction;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        auction = new Auction(address(0), address(0), 100, block.timestamp + 10 days, 1000, address(0));

        vm.stopBroadcast();
    }
}
