// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {Auction} from "../src/Auction.sol";
import {Token} from "../test/mocks/Token.sol";

contract AuctionTest is Test {
  Auction auction;
  Token usdc;
  Token weth;

  address bidder = address(0x1);
  address house = address(0x2);

  function setUp() public {
    usdc = new Token("USDC", "USDC", false);
    weth = new Token("WETH", "WETH", false);

    vm.startPrank(house);
    auction = new Auction(address(usdc), address(weth), 1000000000000, block.timestamp + 10 days, 1000, house);
    vm.stopPrank();
  }

  function testConstructor() public view {
    assertEq(auction.buyToken(), address(usdc));
    assertEq(auction.sellToken(), address(weth));
    assertEq(auction.totalBuyAmount(), 1000000000000);
    assertEq(auction.endTime(), block.timestamp + 10 days);
    assertEq(auction.beneficiary(), house);
  }

  function testBidSuccess() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);

    auction.bid(100 ether, 1000000000);

    assertEq(auction.bidCount(), 1);
    (address bidderAddress, uint256 buyAmount, uint256 sellAmount,,,bool claimed) = auction.bids(1);
    assertEq(bidderAddress, bidder);
    assertEq(buyAmount, 100 ether);
    assertEq(sellAmount, 1000000000);
    assertEq(claimed, false);

    vm.stopPrank();
  }

  function testBidInvalidSellAmount() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);

    vm.expectRevert(Auction.InvalidSellAmount.selector);
    auction.bid(100 ether, 0);

    vm.expectRevert(Auction.InvalidSellAmount.selector);
    auction.bid(100 ether, 1000000000001);

    vm.stopPrank();
  }

  function testBidAmountTooLow() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);

    vm.expectRevert(Auction.BidAmountTooLow.selector);
    auction.bid(0, 1000000000);

    vm.stopPrank();
  }

  function testBidAuctionEnded() public {
    vm.warp(block.timestamp + 15 days);
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);

    vm.expectRevert(Auction.AuctionHasEnded.selector);
    auction.bid(100 ether, 1000000000);

    vm.stopPrank();
  }

  function testEndAuctionSuccess() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);
    auction.bid(100000000000 ether, 1000000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(house);
    auction.endAuction();

    assertEq(uint256(auction.state()), uint256(Auction.State.SUCCEEDED));
  }

  function testEndAuctionFailed() public {
    vm.warp(block.timestamp + 15 days);
    vm.prank(house);
    auction.endAuction();

    assertEq(uint256(auction.state()), uint256(Auction.State.FAILED));
  }

  function testEndAuctionStillOngoing() public {
    vm.expectRevert(Auction.AuctionStillOngoing.selector);
    auction.endAuction();
  }

  function testClaimBidSuccess() public {
    vm.startPrank(bidder);
    weth.mint(address(auction), 1000000000000 ether);
    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);
    auction.bid(100000000000 ether, 1000000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(house);
    auction.endAuction();

    uint256 initialBalance = weth.balanceOf(bidder);

    vm.prank(bidder);
    auction.claimBid(1);

    assertEq(weth.balanceOf(bidder), initialBalance + 1000000000000);
  }

  function testClaimBidAuctionNotEnded() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);
    auction.bid(100 ether, 1000000000);

    vm.expectRevert(Auction.AuctionStillOngoing.selector);
    auction.claimBid(0);

    vm.stopPrank();
  }

  function testClaimBidAuctionFailed() public {
    vm.warp(block.timestamp + 15 days);
    vm.prank(house);
    auction.endAuction();

    vm.expectRevert(Auction.AuctionFailed.selector);
    auction.claimBid(0);
  }

  function testClaimBidNothingToClaim() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);
    auction.bid(100000000000 ether, 1000000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(house);
    auction.endAuction();

    vm.expectRevert(Auction.NothingToClaim.selector);
    vm.prank(address(0xdead));
    auction.claimBid(0);
  }

  function testClaimBidAlreadyClaimed() public {
    vm.startPrank(bidder);
    weth.mint(address(auction), 1000000000000 ether);
    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);
    auction.bid(100000000000 ether, 1000000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(house);
    auction.endAuction();

    vm.startPrank(bidder);
    auction.claimBid(1);

    vm.expectRevert(Auction.AlreadyClaimed.selector);
    auction.claimBid(1);
    vm.stopPrank();
  }

  function testWithdrawSuccess() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);
    auction.bid(100000000000 ether, 1000000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(house);
    auction.endAuction();

    uint256 initialBalance = usdc.balanceOf(house);

    vm.prank(house);
    auction.withdraw();

    assertEq(usdc.balanceOf(house), initialBalance + 100000000000 ether);
  }

  function testWithdrawAuctionNotEnded() public {
    vm.expectRevert(Auction.AuctionStillOngoing.selector);
    auction.withdraw();
  }

  function testWithdrawAuctionFailed() public {
    vm.warp(block.timestamp + 15 days);
    vm.prank(house);
    auction.endAuction();

    vm.expectRevert(Auction.AuctionFailed.selector);
    auction.withdraw();
  }

  function testMultipleBidsWithNewHighBid() public {
    uint256 initialBidAmount = 1000;
    uint256 initialSellAmount = 1000000000;

    // Create 1000 bids
    for (uint256 i = 0; i < 1000; i++) {
      address newBidder = address(uint160(i + 1));
      vm.startPrank(newBidder);
      usdc.mint(newBidder, initialSellAmount);
      usdc.approve(address(auction), initialSellAmount);
      auction.bid(initialBidAmount, initialSellAmount);
      vm.stopPrank();
    }

    // Check initial state
    assertEq(auction.bidCount(), 1000, "bid count 1");
    assertEq(auction.highestBidIndex(), 1, "highest bid index 1");
    assertEq(auction.lowestBidIndex(), 1000, "lowest bid index 1");

    // Place a new high bid
    address highBidder = address(1001);
    uint256 highBidAmount = 500;
    uint256 highSellAmount = 1000000000;

    vm.startPrank(highBidder);
    usdc.mint(highBidder, highSellAmount);
    usdc.approve(address(auction), highSellAmount);
    auction.bid(highBidAmount, highSellAmount);
    vm.stopPrank();

    // Check updated state
    assertEq(auction.bidCount(), 1000, "bid count 2");
    assertEq(auction.highestBidIndex(), 1001, "highest bid index 2");
    
    // The lowest bid should have been kicked out
    (, uint256 lowestBuyAmount,,,,) = auction.bids(auction.lowestBidIndex());
    assertGt(lowestBuyAmount, highBidAmount, "lowest buy amount 2");

    // Verify the new high bid
    (address highestBidder, uint256 highestBuyAmount, uint256 highestSellAmount,,,) = auction.bids(auction.highestBidIndex());
    assertEq(highestBidder, highBidder, "highest bidder");
    assertEq(highestBuyAmount, highBidAmount, "highest buy amount");
    assertEq(highestSellAmount, highSellAmount, "highest sell amount");
  }

  function testRemoveManyBids() public {
    uint256 initialBidAmount = 1000;
    uint256 initialSellAmount = 1000000000;

    // Create 1000 bids
    for (uint256 i = 0; i < 1000; i++) {
      address newBidder = address(uint160(i + 1));
      vm.startPrank(newBidder);
      usdc.mint(newBidder, initialSellAmount);
      usdc.approve(address(auction), initialSellAmount);
      auction.bid(initialBidAmount, initialSellAmount);
      vm.stopPrank();
    }

    // Check initial state
    assertEq(auction.bidCount(), 1000, "bid count 1");
    assertEq(auction.highestBidIndex(), 1, "highest bid index 1");
    assertEq(auction.lowestBidIndex(), 1000, "lowest bid index 1");

    // Place a new high bid
    address highBidder = address(1001);
    uint256 highBidAmount = 500;
    uint256 highSellAmount = 1000000000 * 10; // this should take 10 slots

    vm.startPrank(highBidder);
    usdc.mint(highBidder, highSellAmount);
    usdc.approve(address(auction), highSellAmount);
    auction.bid(highBidAmount, highSellAmount);
    vm.stopPrank();

    // Check updated state
    assertEq(auction.bidCount(), 991, "bid count 2");
    assertEq(auction.highestBidIndex(), 1001, "highest bid index 2");
    
    // The lowest bid should have been kicked out
    (, uint256 lowestBuyAmount,,,,) = auction.bids(auction.lowestBidIndex());
    assertGt(lowestBuyAmount, highBidAmount, "lowest buy amount 2");

    // Verify the new high bid
    (address highestBidder, uint256 highestBuyAmount, uint256 highestSellAmount,,,) = auction.bids(auction.highestBidIndex());
    assertEq(highestBidder, highBidder, "highest bidder");
    assertEq(highestBuyAmount, highBidAmount, "highest buy amount");
    assertEq(highestSellAmount, highSellAmount, "highest sell amount");
  }
}
