// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {Utils} from "../src/lib/Utils.sol";
import {Auction} from "../src/Auction.sol";
import {Token} from "../test/mocks/Token.sol";

// @todo: remove - not meant for production - just for testing

contract AuctionScript is Script {
    Auction public auction;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));


        address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));

        Token usdc = new Token("USDC", "USDC", false);
        Token weth = new Token("WETH", "WETH", false);
        usdc.mint(deployerAddress, 1000000000000 ether);
        auction = Auction(Utils.deploy(
            address(new Auction()),
            abi.encodeWithSelector(
                Auction.initialize.selector,
                address(usdc),
                address(weth),
                1000000000000,
                block.timestamp + 1 days,
                1000,
                deployerAddress,
                100
            )
        ));

        usdc.approve(address(auction), type(uint256).max);

        uint256 usdcBid;
        uint256 ethBid;

        usdcBid = 1000000000;
        ethBid = 1000;

        for (uint256 i = 0; i < 999; i++) {
          auction.bid(ethBid, usdcBid);
        }

        auction.bid(ethBid, usdcBid * 2);

        vm.stopBroadcast();
    }
}
