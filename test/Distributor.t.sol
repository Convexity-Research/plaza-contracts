// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Auction} from "../src/Auction.sol";
import {Utils} from "../src/lib/Utils.sol";
import {BondToken} from "../src/BondToken.sol";
import {Distributor} from "../src/Distributor.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DistributorTest is Test {
  Distributor public distributor;
  Pool public _pool;
  PoolFactory.PoolParams private params;
  PoolFactory public poolFactory;

  address public user = address(0x1);
  address public sharesTokenOwner = address(0x2);
  address private deployer = address(0x3);
  address private governance = address(0x4);
  address private securityCouncil = address(0x5);
  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);

  function setUp() public {
    vm.startPrank(deployer);

    // Deployer deploy
    address contractDeployer = address(new Deployer());

    // Pool, Bond & Leverage Beacon deploy
    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));

    // PoolFactory deploy
    poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize, 
      (governance, contractDeployer, ethPriceFeed, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
    )));

    vm.stopPrank();

    vm.startPrank(governance);

    params.fee = 0;
    params.sharesPerToken = 50*10**6;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH", false));
    params.distributionPeriod = 0;
    params.couponToken = address(new Token("Circle USD", "USDC", false));
    
    vm.stopPrank(); 
    vm.startPrank(governance);
    poolFactory.grantRole(poolFactory.POOL_ROLE(), governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000000000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    _pool = Pool(poolFactory.createPool(params, 10000000000, 10000*10**18, 10000*10**18, "", "", "", "", false));
    distributor = Distributor(poolFactory.distributors(address(_pool)));
    poolFactory.grantRole(poolFactory.SECURITY_COUNCIL_ROLE(), securityCouncil);

    _pool.bondToken().grantRole(_pool.bondToken().DISTRIBUTOR_ROLE(), governance);
    _pool.bondToken().grantRole(_pool.bondToken().DISTRIBUTOR_ROLE(), address(distributor));
  }

  function fakeSucceededAuction(address poolAddress, uint256 period) public {
    address auction = Utils.deploy(address(new Auction()), abi.encodeWithSelector(Auction.initialize.selector, params.couponToken, params.reserveToken, 1000000000000, block.timestamp + 10 days, 1000, address(0), 95));

    uint256 auctionSlot = 11;
    bytes32 auctionPeriodSlot = keccak256(abi.encode(period, auctionSlot));
    vm.store(address(poolAddress), auctionPeriodSlot, bytes32(uint256(uint160(auction))));

    uint256 stateSlot = 6;
    vm.store(auction, bytes32(stateSlot), bytes32(uint256(1)));
  }

  function testPause() public {
    uint256 amountToDistribute = 10000000;
    Token couponToken = Token(_pool.couponToken());
    couponToken.mint(address(distributor), amountToDistribute);

    vm.startPrank(securityCouncil);
    distributor.pause();

    vm.startPrank(address(_pool));
    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    distributor.allocate(amountToDistribute);

    vm.startPrank(securityCouncil);
    distributor.unpause();

    vm.startPrank(address(_pool));
    distributor.allocate(amountToDistribute);
    uint256 storedAmountToDistribute = distributor.couponAmountToDistribute();
    assertEq(storedAmountToDistribute, amountToDistribute);
  }

  function testClaimShares() public {
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user, 1*10**18);
    sharesToken.mint(address(_pool), 50*(1+10000)*10**18);
    vm.stopPrank();

    vm.startPrank(governance);
    fakeSucceededAuction(address(_pool), 0);

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("state()"),
      abi.encode(uint256(1))
    );

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("totalBuyCouponAmount()"),
      abi.encode(uint256(50*(1+10000)*10**18))
    );

    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    _pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);

    _pool.distribute();
    vm.stopPrank();

    vm.startPrank(user);

    vm.expectEmit(true, true, true, true);
    emit Distributor.ClaimedShares(user, 1, 50*10**18);

    distributor.claim();
    assertEq(sharesToken.balanceOf(user), 50*10**18);
    vm.stopPrank();
  }

  function testClaimSharesCheckPoolInfo() public {
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user, 1*10**18);
    sharesToken.mint(address(_pool), 50*(1+10000)*10**18);
    vm.stopPrank();

    vm.startPrank(governance);
    fakeSucceededAuction(address(_pool), 0);

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("state()"),
      abi.encode(uint256(1))
    );

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("totalBuyCouponAmount()"),
      abi.encode(uint256(50*(1+10000)*10**18))
    );

    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    _pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);

    _pool.distribute();
    vm.stopPrank();

    vm.startPrank(user);

    vm.expectEmit(true, true, true, true);
    emit Distributor.ClaimedShares(user, 1, 50*10**18);

    uint256 couponAmountToDistributePreClaim = distributor.couponAmountToDistribute();
    distributor.claim();
    uint256 couponAmountToDistribute = distributor.couponAmountToDistribute();

    assertEq(couponAmountToDistribute + 50*10**18, couponAmountToDistributePreClaim);
    assertEq(sharesToken.balanceOf(user), 50*10**18);
    vm.stopPrank();
  }

  function testAllBondHoldersCanClaim() public {
    address user1 = address(0x61);
    address user2 = address(0x62);
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user1, 1*10**18);
    _pool.bondToken().mint(user2, 1*10**18);

    sharesToken.mint(address(_pool), 500100000000000000000000);
    vm.stopPrank();

    vm.startPrank(governance);
    fakeSucceededAuction(address(_pool), 0);

    vm.mockCall(
        address(0),
        abi.encodeWithSignature("state()"),
        abi.encode(uint256(1))
    );

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("totalBuyCouponAmount()"),
      abi.encode(uint256(500100000000000000000000))
    );

    vm.warp(block.timestamp + params.distributionPeriod);
    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    _pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);
    _pool.distribute();
    vm.stopPrank();

    vm.startPrank(user1);
    distributor.claim();
    assertEq(sharesToken.balanceOf(user1), 50 * 10**18);
    vm.stopPrank();

    vm.startPrank(user2);
    distributor.claim();
    assertEq(sharesToken.balanceOf(user2), 50 * 10**18);
    vm.stopPrank();
  }

  function testClaimSharesDifferentDecimals() public {
    vm.startPrank(governance);

    PoolFactory.PoolParams memory poolParams = PoolFactory.PoolParams({
      fee: 0,
      feeBeneficiary: address(0x1),
      sharesPerToken: 50*10**6,
      reserveToken: address(new Token("Wrapped ETH", "WETH", false)),
      distributionPeriod: 0,
      couponToken: address(new Token("Circle USD", "USDC", false))
    });

    uint8 couponDecimals = 6;
    Token sharesToken = Token(poolParams.couponToken);
    sharesToken.setDecimals(couponDecimals);

    Token rToken = Token(poolParams.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000000000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool pool = Pool(poolFactory.createPool(poolParams, 10000000000, 10000*10**18, 10000*10**18, "", "", "", "", false));
    distributor = Distributor(poolFactory.distributors(address(pool)));

    vm.stopPrank();

    vm.startPrank(address(pool));
    pool.bondToken().mint(user, 1*10**18);
    
    sharesToken.mint(address(pool), 50*(1+10000)*10**6);
    vm.stopPrank();

    vm.startPrank(governance);
    fakeSucceededAuction(address(pool), 0);

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("state()"),
      abi.encode(uint256(1))
    );

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("totalBuyCouponAmount()"),
      abi.encode(uint256(50*(1+10000)*10**6))
    );

    vm.stopPrank();
    vm.startPrank(address(distributor));
    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);

    vm.stopPrank();

    vm.startPrank(governance);
    pool.distribute();
    vm.stopPrank();

    vm.startPrank(user);

    vm.expectEmit(true, true, true, true);
    emit Distributor.ClaimedShares(user, 1, 50*10**6);

    distributor.claim();
    assertEq(sharesToken.balanceOf(user), 50*10**6);
    
    vm.stopPrank();
  }

  function testClaimNonExistentPool() public {
    vm.startPrank(governance);
    // Mint reserve tokens
    Token(params.reserveToken).mint(governance, 10000000000);
    Token(params.reserveToken).approve(address(poolFactory), 10000000000);

    params.couponToken = address(0);
    _pool = Pool(poolFactory.createPool(params, 10000000000, 10000*10**18, 10000*10**18, "", "", "", "", false));
    distributor = Distributor(poolFactory.distributors(address(_pool)));
    vm.stopPrank();

    vm.startPrank(user);
    vm.expectRevert(Distributor.UnsupportedPool.selector);
    distributor.claim();
    vm.stopPrank();
  }

  function testClaimAfterMultiplePeriods() public {
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user, 1000*10**18);
    uint256 coupons = params.sharesPerToken * 1000 + params.sharesPerToken * 10000 / 10**_pool.bondToken().SHARES_DECIMALS();
    sharesToken.mint(address(_pool), 3 * coupons * 10**sharesToken.decimals()); //instantiate value + minted value right above
    vm.stopPrank();

    vm.startPrank(governance);
    fakeSucceededAuction(address(_pool), 0);
    fakeSucceededAuction(address(_pool), 1);
    fakeSucceededAuction(address(_pool), 2);

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("state()"),
      abi.encode(uint256(1))
    );

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("totalBuyCouponAmount()"),
      abi.encode(coupons * 10**sharesToken.decimals())
    );

    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    _pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);
    _pool.distribute();

    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    _pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);
    _pool.distribute();

    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    _pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);
    _pool.distribute();
    vm.stopPrank();

    vm.startPrank(user);

    distributor.claim();
    vm.stopPrank();

    assertEq(sharesToken.balanceOf(user), 3 * (50 * 1000) * 10**sharesToken.decimals());
  }

  function testClaimNotEnoughSharesToDistribute() public {
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user, 1*10**18);
    // Mint enough shares but don't allocate them
    sharesToken.mint(address(distributor), 50*10**sharesToken.decimals());
    vm.stopPrank();

    //this would never happen in production
    vm.startPrank(governance);
    _pool.bondToken().increaseIndexedAssetPeriod(1);
    vm.stopPrank();

    vm.startPrank(user);
    vm.expectRevert(Distributor.NotEnoughSharesToDistribute.selector);
    distributor.claim();
    vm.stopPrank();
  }

  function testClaimNotEnoughDistributorBalance() public {
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user, 1000*10**18);
    // Mint shares but transfer them away from the distributor
    sharesToken.mint(address(distributor), 50*10**18);
    vm.stopPrank();

    vm.startPrank(address(distributor));
    sharesToken.transfer(address(0x1), 50*10**18);
    vm.stopPrank();

    //this would never happen in production
    vm.startPrank(governance);
    _pool.bondToken().increaseIndexedAssetPeriod(1);
    vm.stopPrank();

    vm.startPrank(user);
    vm.expectRevert(Distributor.NotEnoughSharesBalance.selector);
    distributor.claim();
    vm.stopPrank();
  }

  function testAllocateCallerNotPool() public {
    vm.startPrank(user);
    vm.expectRevert(Distributor.CallerIsNotPool.selector);
    distributor.allocate(100);
    vm.stopPrank();
  }

  function testAllocateNotEnoughCouponBalance() public {
    uint256 allocateAmount = 100*10**18;

    vm.startPrank(address(_pool));
    vm.expectRevert(Distributor.NotEnoughCouponBalance.selector);
    distributor.allocate(allocateAmount);
    vm.stopPrank();
  }
}
