// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Auction} from "../src/Auction.sol";
import {Token} from "../test/mocks/Token.sol";

import {GasMeter} from "../test/utils/GasMeter.sol";

// @todo: remove - not meant for production - just for testing

contract AuctionScript is Script, GasMeter {
    Auction public auction;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));


        address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));

        Token usdc = new Token("USDC", "USDC", false);
        Token weth = new Token("WETH", "WETH", false);
        usdc.mint(deployerAddress, 1000000000000 ether);
        auction = new Auction(address(usdc), address(weth), 1000000000000, block.timestamp + 1 days, 1000, deployerAddress);

        usdc.approve(address(auction), type(uint256).max);

        uint256 usdcBid;
        uint256 ethBid;

        usdcBid = 1000000000;
        ethBid = 1000;

        for (uint256 i = 0; i < 999; i++) {
          auction.bid(ethBid, usdcBid);
        }

        gasMeterStart();
        auction.bid(ethBid, usdcBid * 2);
        uint256 gas = gasMeterStop();
        console.log("Gas used:", gas);

        vm.stopBroadcast();
    }
}
