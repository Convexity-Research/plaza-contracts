// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {GasMeter} from "./utils/GasMeter.sol";
import {Auction} from "../src/Auction.sol";

import {Token} from "../test/mocks/Token.sol";

contract AuctionTest is Test, GasMeter {
  Auction auction;
  Token usdc;
  Token weth;

  address bidder = address(0x1);
  address house = address(0x2);
  uint256 salt = 134;

  function generateRandomBetween(uint256 min, uint256 max) public returns (uint256) {
    require(max > min, "Max must be greater than min");

    // Increment salt to ensure randomness on multiple calls within the same transaction
    salt += 1;

    // Generate a random number based on entropy and limit it to the range [min, max]
    uint256 randomValue = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, salt)));

    // Scale the random value to the desired range and return
    return (randomValue % (max - min + 1)) + min;
  }

  function setUp() public {
    usdc = new Token("USDC", "USDC", false);
    weth = new Token("WETH", "WETH", false);

    vm.startPrank(house);
    auction = new Auction(address(usdc), address(weth), 1000000000000, block.timestamp + 10 days, 1000, house);
    vm.stopPrank();
  }

  function testBid() public {
    vm.startPrank(bidder);

    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);

    weth.mint(address(auction), 1000000000000 ether);

    uint256 gas;
    uint256 usdcBid;
    uint256 ethBid;

    for (uint256 i = 0; i < 1000; i++) {
      gasMeterStart();
      usdcBid = /*generateRandomBetween(1, 10) * */1000000000;
      ethBid = generateRandomBetween(1, 10000);
      auction.bid(ethBid, usdcBid);
      gas = gasMeterStop();
      console.log(usdcBid, ethBid, gas, gas * 3 * 2400 / 10**7);
    }

    gasMeterStart();
    auction.bid(10000 * 2, 1000000000);
    gas = gasMeterStop();
    console.log("Gas used (last bid) - low:", gas);

    gasMeterStart();
    auction.bid(1, 1000000000);
    gas = gasMeterStop();
    console.log("Gas used (last bid) - high:", gas);

    // gasMeterStart();
    // auction.bid(generateRandomBetween(1, 10000), generateRandomBetween(1, 10000));
    // gas = gasMeterStop();
    // console.log("Gas used last bid:", gas);

    vm.stopPrank();

    vm.startPrank(house);

    vm.warp(block.timestamp + 10 days);

    gasMeterStart();
    auction.endAuction();
    gas = gasMeterStop();
    console.log("Gas used end auction:", gas, gas * 3 * 2400 / 10**7);
    vm.stopPrank();
  }
}
