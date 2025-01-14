// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Auction} from "../src/Auction.sol";
import {MockPool} from "./mocks/MockPool.sol";
import {BondToken} from "../src/BondToken.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Distributor} from "../src/Distributor.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract AuctionTest is Test {
  Auction auction;
  Token usdc;
  Token weth;

  address bidder = address(0x1);
  address house = address(0x2);
  address minter = address(0x3);
  address governance = address(0x4);
  address securityCouncil = address(0x5);

  address pool;

  function setUp() public {
    usdc = new Token("USDC", "USDC", false);
    weth = new Token("WETH", "WETH", false);
    
    pool = createPool(address(weth), address(usdc));
    useMockPool(pool);

    vm.startPrank(pool);
    auction = Auction(Utils.deploy(
      address(new Auction()),
      abi.encodeWithSelector(
        Auction.initialize.selector,
        address(usdc),
        address(weth),
        1000000000000,
        block.timestamp + 10 days,
        1000,
        house,
        110
      )
    ));
    vm.stopPrank();
  }

  function createPool(address reserve, address coupon) public returns (address) {
    vm.startPrank(governance);
    address deployer = address(new Deployer());
    address oracleFeeds = address(new OracleFeeds());

    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));

    PoolFactory poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize, 
      (governance, deployer, oracleFeeds, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
    )));

    PoolFactory.PoolParams memory params;
    params.fee = 0;
    params.reserveToken = reserve;
    params.sharesPerToken = 2500000;
    params.distributionPeriod = 90 days;
    params.couponToken = coupon;
    
    poolFactory.grantRole(poolFactory.GOV_ROLE(), governance);
    poolFactory.grantRole(poolFactory.POOL_ROLE(), governance);
    poolFactory.grantRole(poolFactory.SECURITY_COUNCIL_ROLE(), securityCouncil);
    
    Token(reserve).mint(governance, 500000000000000000000000000000);
    Token(reserve).approve(address(poolFactory), 500000000000000000000000000000);
    
    return poolFactory.createPool(params, 500000000000000000000000000000, 10000*10**18, 10000*10**18, "Bond ETH", "bondETH", "Leverage ETH", "levETH", false);
  }

  function useMockPool(address poolAddress) public {
    // Deploy the mock pool
    MockPool mockPool = new MockPool();

    // Use vm.etch to deploy the mock contract at the specific address
    vm.etch(poolAddress, address(mockPool).code);
  }

  function testConstructor() public view {
    assertEq(auction.buyCouponToken(), address(usdc));
    assertEq(auction.sellReserveToken(), address(weth));
    assertEq(auction.totalBuyCouponAmount(), 1000000000000);
    assertEq(auction.endTime(), block.timestamp + 10 days);
    assertEq(auction.beneficiary(), house);
  }


  function testPause() public {
    vm.startPrank(securityCouncil);
    auction.pause();
    
    vm.startPrank(bidder);
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    auction.bid(100 ether, 1000000000);

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    vm.warp(block.timestamp + 15 days);
    auction.endAuction();

    vm.startPrank(securityCouncil);
    auction.unpause();

    vm.warp(block.timestamp - 14 days);

    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);
    auction.bid(100 ether, 1000000000);

    assertEq(auction.bidCount(), 1);
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
    vm.prank(pool);
    auction.endAuction();

    assertEq(uint256(auction.state()), uint256(Auction.State.SUCCEEDED));
  }

  function testEndAuctionFailed() public {
    vm.warp(block.timestamp + 15 days);
    vm.prank(pool);
    auction.endAuction();

    assertEq(uint256(auction.state()), uint256(Auction.State.FAILED_UNDERSOLD));
  }

  function testEndAuctionFailedPoolSale() public {
    // Place a bid that would require too much of the reserve
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);
    auction.bid(480000000000 ether, 1000000000000); // 96% of pool's reserve
    vm.stopPrank();

    // End the auction
    vm.warp(block.timestamp + 15 days);
    vm.prank(pool);

    uint256 poolSaleLimitSlot = 6;
    vm.store(address(auction), bytes32(poolSaleLimitSlot), bytes32(uint256(95)));

    auction.endAuction();

    // Check that auction failed due to too much of the reserve being sold
    assertEq(uint256(auction.state()), uint256(Auction.State.FAILED_POOL_SALE_LIMIT));
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
    vm.prank(pool);
    auction.endAuction();

    uint256 initialBalance = weth.balanceOf(bidder);

    vm.prank(bidder);
    auction.claimBid(1);

    assertEq(weth.balanceOf(bidder), initialBalance + 100000000000000000000000000000);
  }

  function testPartialRefund() public {
    vm.startPrank(bidder);
    weth.mint(address(auction), 1000000000000 ether);
    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);
    auction.bid(100000000000 ether, 1000000000000);
    vm.stopPrank();

    uint256 initialBidderBalance = usdc.balanceOf(bidder);

    // New bidder
    vm.startPrank(address(0x55));
    uint256 newBidderBid = 1000000000;
    usdc.mint(address(0x55), newBidderBid);
    usdc.approve(address(auction), newBidderBid);
    // Higher bid, kicks out the first bid partially (1 slot)
    auction.bid(100 ether, newBidderBid);
    vm.stopPrank();

    // Check that the bidder received the partial refund
    assertEq(usdc.balanceOf(bidder), initialBidderBalance + newBidderBid);
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
    vm.prank(pool);
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
    vm.prank(pool);
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
    vm.prank(pool);
    auction.endAuction();

    vm.startPrank(bidder);
    auction.claimBid(1);

    vm.expectRevert(Auction.AlreadyClaimed.selector);
    auction.claimBid(1);
    vm.stopPrank();
  }

  function testClaimRefundSuccess() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);
    uint256 bidIndex = auction.bid(100 ether, 1000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(pool);
    auction.endAuction();

    uint256 initialBalance = usdc.balanceOf(bidder);

    vm.prank(bidder);
    auction.claimRefund(bidIndex);

    assertEq(usdc.balanceOf(bidder), initialBalance + 1000000000);
  }

  function testClaimRefundSuccessManyBidders() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);
    uint256 bidIndex = auction.bid(100 ether, 1000000000);
    vm.stopPrank();

    address bidder2 = address(0x55);
    vm.startPrank(bidder2);
    usdc.mint(bidder2, 1000 ether);
    usdc.approve(address(auction), 1000 ether);
    uint256 bidIndex2 = auction.bid(100 ether, 1000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(pool);
    auction.endAuction();

    uint256 initialBalance = usdc.balanceOf(bidder);
    vm.prank(bidder);
    auction.claimRefund(bidIndex);
    assertEq(usdc.balanceOf(bidder), initialBalance + 1000000000);

    uint256 initialBalanceBidder2 = usdc.balanceOf(bidder2);
    vm.prank(bidder2);
    auction.claimRefund(bidIndex2);
    assertEq(usdc.balanceOf(bidder2), initialBalanceBidder2 + 1000000000);
  }

  function testClaimRefundAuctionNotFailed() public {
    vm.startPrank(bidder);
    weth.mint(address(auction), 1000000000000 ether);
    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);
    uint256 bidIndex = auction.bid(100000000000 ether, 1000000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(pool);
    auction.endAuction();

    vm.expectRevert(Auction.AuctionFailed.selector);
    vm.prank(bidder);
    auction.claimRefund(bidIndex);
  }

  function testClaimRefundNothingToClaim() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);
    uint256 bidIndex = auction.bid(100 ether, 1000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(pool);
    auction.endAuction();

    vm.expectRevert(Auction.NothingToClaim.selector);
    vm.prank(address(0xdead));
    auction.claimRefund(bidIndex);
  }

  function testClaimRefundAlreadyClaimed() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);
    uint256 bidIndex = auction.bid(100 ether, 1000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(pool);
    auction.endAuction();

    vm.startPrank(bidder);
    auction.claimRefund(bidIndex);

    vm.expectRevert(Auction.AlreadyClaimed.selector);
    auction.claimRefund(bidIndex);
    vm.stopPrank();
  }

  function testClaimRefundAuctionNotEnded() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000 ether);
    usdc.approve(address(auction), 1000 ether);
    uint256 bidIndex = auction.bid(100 ether, 1000000000);
    vm.stopPrank();

    vm.expectRevert(Auction.AuctionStillOngoing.selector);
    vm.prank(bidder);
    auction.claimRefund(bidIndex);
  }

  function testWithdrawSuccess() public {
    vm.startPrank(bidder);
    usdc.mint(bidder, 1000000000000 ether);
    usdc.approve(address(auction), 1000000000000 ether);
    auction.bid(100000000000 ether, 1000000000000);
    vm.stopPrank();

    vm.warp(block.timestamp + 15 days);
    vm.prank(pool);

    uint256 initialBalance = usdc.balanceOf(house);
    
    auction.endAuction();
    assertEq(usdc.balanceOf(house), initialBalance + 1000000000000);
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

  function testRefundBidSuccessful() public {
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

    (address lowestBidder,,uint256 lowestSellCouponAmount,,,) = auction.bids(auction.lowestBidIndex());
    uint256 lowestBidderCouponBalance = usdc.balanceOf(lowestBidder);

    // Place a new high bid
    address highBidder = address(1001);
    uint256 highSellAmount = 1000000000 * 10; // this should take 10 slots

    vm.startPrank(highBidder);
    usdc.mint(highBidder, highSellAmount);
    usdc.approve(address(auction), highSellAmount);
    auction.bid(500, highSellAmount);
    vm.stopPrank();

    // Check that the lowest bidder received the refund
    assertEq(usdc.balanceOf(lowestBidder), lowestBidderCouponBalance + lowestSellCouponAmount);
  }

  function testPartialRefundUpdatesTotalReserves() public { 
    vm.startPrank(bidder);
    uint256 initialBidAmount = 1000000000000;
    usdc.mint(bidder, initialBidAmount);
    usdc.approve(address(auction), initialBidAmount);
    auction.bid(100 ether, initialBidAmount);
    vm.stopPrank();

    address user = address(1001);

    vm.startPrank(user);
    // initialBidAmount + newBidderBid - totalBuyCouponAmount = 5000 ether
    uint256 newBidderBid = 500000000000;
    usdc.mint(user, newBidderBid);
    usdc.approve(address(auction), newBidderBid);
    auction.bid(40 ether, newBidderBid);
    vm.stopPrank();
    
    (, uint256 amount1, , , ,) = auction.bids(1);
    (, uint256 amount2, , , ,) = auction.bids(2);

    assertEq(amount1 + amount2, auction.totalSellReserveAmount());
  }

  function testAuctionBidOverflow() public {
    address user1 = address(1001);
    vm.startPrank(governance);

    Pool(pool).setAuctionPeriod(10 days);
    vm.stopPrank();

    vm.warp(95 days);
    Pool(pool).startAuction();

    (uint256 currentPeriod,) = Pool(pool).bondToken().globalPool();
    address auctionAddress = Pool(pool).auctions(currentPeriod-1);
    Auction _auction = Auction(auctionAddress);

    Token usdcToken = Token(Pool(pool).couponToken());

    vm.startPrank(bidder);
    uint256 initialBidAmount = 25000000000000000000;
    usdcToken.mint(bidder, initialBidAmount);
    usdcToken.approve(auctionAddress, initialBidAmount);

    uint256 target_amount = type(uint256).max / initialBidAmount;

    vm.expectRevert(Auction.BidAmountTooHigh.selector);
    _auction.bid(target_amount, 25000000000000000000);
    vm.stopPrank();

    vm.startPrank(user1);
    uint256 newBidderBid = 25000000000000000000 * 2;
    usdcToken.mint(user1, newBidderBid);
    usdcToken.approve(auctionAddress, newBidderBid);

    _auction.bid(1 ether, newBidderBid);
    vm.stopPrank();
  }
}
