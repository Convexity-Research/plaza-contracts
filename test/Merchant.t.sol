// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Merchant} from "../src/Merchant.sol";
import {BondToken} from "../src/BondToken.sol";
import {Distributor} from "../src/Distributor.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {TokenDeployer} from "../src/utils/TokenDeployer.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {WETH9} from "./mocks/MockWeth.sol";
import {MockQuoterV2} from "./mocks/MockQuoterV2.sol";
import {MockSwapRouter} from "./mocks/MockSwapRouter.sol";
import {MockUniswapV3Pool} from "./mocks/MockUniswapV3Pool.sol";
import {MockUniswapV3Factory} from "./mocks/MockUniswapV3Factory.sol";

contract MerchantTest is Test {
	Merchant public merchant;
  address public quoter;
	Pool public pool;

  address public uniPool1;
  address public uniPool2;
  address public uniPool3;

	address public constant governance = address(0x1);
  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);
  address private constant WETH = 0x4200000000000000000000000000000000000006; // WETH address on Base

	function setUp() public {
		vm.startPrank(governance);

    Distributor distributor = Distributor(Utils.deploy(address(new Distributor()), abi.encodeCall(Distributor.initialize, (governance))));

    address tokenDeployer = address(new TokenDeployer());

    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));

    PoolFactory poolFactory = PoolFactory(
      Utils.deploy(address(new PoolFactory()), 
      abi.encodeCall(PoolFactory.initialize,
      (governance, tokenDeployer, address(distributor), ethPriceFeed, poolBeacon, bondBeacon, levBeacon)))
    );

    distributor.grantRole(distributor.POOL_FACTORY_ROLE(), address(poolFactory));

    uint256 reserveAmount = 1_000_000 ether;
    uint256 bondAmount = 25_000_000 ether;
    uint256 leverageAmount = 1_000_000 ether;
    uint256 sharesPerToken = 2_500_000;
    uint256 distributionPeriod = 1296000; // 15 days

    // This is to ensure reserve token address is lower (in hex) than coupon token address
    address deployedReserveToken = address(new Token("Wrapped ETH", "WETH", false));
    mockContract(deployedReserveToken.code, address(0x1210000000000000000000000000000000000000));
    copyStorage(deployedReserveToken, address(0x1210000000000000000000000000000000000000), 0, 10);

    PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
      fee: 0,
      sharesPerToken: sharesPerToken,
      reserveToken: address(0x1210000000000000000000000000000000000000),
      distributionPeriod: distributionPeriod,
      couponToken: address(new Token("Circle USD", "USDC", false))
    });

    // Mint reserve tokens
    Token(params.reserveToken).mint(governance, reserveAmount);
    Token(params.reserveToken).approve(address(poolFactory), reserveAmount);

    // Create pool and approve deposit amount
    pool = Pool(poolFactory.CreatePool(params, reserveAmount, bondAmount, leverageAmount));
    
    WETH9 weth = new WETH9();
    mockContract(address(weth).code, WETH);

    address router = address(new MockSwapRouter());
    quoter = address(new MockQuoterV2());

    MockUniswapV3Factory factory = new MockUniswapV3Factory();

    MockUniswapV3Pool poolInstance1 = new MockUniswapV3Pool();
    MockUniswapV3Pool poolInstance2 = new MockUniswapV3Pool();
    MockUniswapV3Pool poolInstance3 = new MockUniswapV3Pool();

    uniPool1 = factory.createPool(WETH, address(pool.reserveToken()), 100);
    uniPool2 = factory.createPool(WETH, address(pool.couponToken()), 100);
    uniPool3 = factory.createPool(address(pool.reserveToken()), address(pool.couponToken()), 100);

    mockContract(address(poolInstance1).code, uniPool1);
    mockContract(address(poolInstance2).code, uniPool2);
    mockContract(address(poolInstance3).code, uniPool3);

    MockUniswapV3Pool(uniPool1).setStorage(0);
    MockUniswapV3Pool(uniPool2).setStorage(0);
    MockUniswapV3Pool(uniPool3).setStorage(0);

    merchant = new Merchant(router, quoter, address(factory));

    // Inifinite approve to Merchant
    pool.approveMerchant(address(merchant));

    vm.stopPrank();
	}

  function copyStorage(address from, address to, uint256 startSlot, uint256 endSlot) public {
    for (uint256 slot = startSlot; slot <= endSlot; slot++) {
      bytes32 value = vm.load(from, bytes32(slot));
      vm.store(to, bytes32(slot), value);
    }
  }

  function mockContract(bytes memory bytecode, address destination) public {
    vm.etch(destination, bytecode);
  }

	function testNeedsNewOrders() public {
    // 15 days to distribution
		assertFalse(merchant.needsNewOrders(address(pool)));

		// Set up pool info to trigger pending orders
		vm.warp(block.timestamp + 6 days);

    // 9 days to distribution
		assertTrue(merchant.needsNewOrders(address(pool)));
	}

	function testUpdateLimitOrders() public {
		vm.expectRevert(Merchant.UpdateNotRequired.selector);
		merchant.updateOrders(address(pool));

		vm.warp(block.timestamp + 6 days);
		merchant.updateOrders(address(pool));

		// Check that orders were updated
		(, address sell, address buy, uint256 price, uint256 amount, uint256 minAmount, bool filled) = merchant.orders(address(pool));
		assertEq(sell, pool.reserveToken());
		assertEq(buy, pool.couponToken());
		assertTrue(price > 0);
		assertTrue(amount > 0);
		assertTrue(minAmount > 0);
		assertFalse(filled);
	}

	function testOrdersPriceReached() public {
		vm.warp(block.timestamp + 6 days);
		merchant.updateOrders(address(pool));

    // Mock price increase
    MockQuoterV2(quoter).setAmountOut(2000020000000000000000);
    MockUniswapV3Pool(uniPool3).setStorage(4206428064337469953968261);
		assertTrue(merchant.ordersPriceReached(address(pool)));

    // Reset amountOut
    MockQuoterV2(quoter).setAmountOut(0);
	}

	function testExecuteOrders() public {
		vm.warp(block.timestamp + 6 days);
		merchant.updateOrders(address(pool));

    // Mock price increase
    MockUniswapV3Pool(uniPool3).setStorage(4206428064337469953968261);
    MockQuoterV2(quoter).setAmountOut(2000020000000000000000);

		merchant.executeOrders(address(pool));

		// Check that orders were executed
		(,,,,,,bool filled) = merchant.orders(address(pool));
		assertTrue(filled);
    MockQuoterV2(quoter).setAmountOut(0);
	}

	function testGetLimitOrders() public {
    vm.warp(block.timestamp + 6 days);
		Merchant.Order memory order = merchant.getOrder(address(pool));
		assertEq(order.sell, pool.reserveToken());
		assertEq(order.buy, pool.couponToken());
		assertTrue(order.price > 0);
		assertTrue(order.amount > 0);
		assertTrue(order.minAmount > 0);
		assertFalse(order.filled);
	}

	function testGetPrice() public {
    MockUniswapV3Pool(uniPool3).setStorage(0);

    console.log("reserve smaller", pool.reserveToken() < pool.couponToken() ? "true" : "false");

		uint256 price = merchant.getPrice(pool.reserveToken(), pool.couponToken());
		assertEq(price, 2544396752);
	}

	function testGetDaysToPayment() view public {
		uint8 daysToPayment = merchant.getDaysToPayment(address(pool));
		assertEq(daysToPayment, 15);
	}

	function testGetRemainingCouponAmount() view public {
		uint256 couponAmount = merchant.getRemainingCouponAmount(address(pool));
		assertEq(couponAmount, 62500000000000000000000000000000);
	}

	function testGetPoolReserves() view public {
		uint256 reserves = merchant.getPoolReserves(address(pool));
		assertEq(reserves, 1000000000000000000000000);
	}

	function testGetLiquidity() view public {
		(,uint256 liquidity) = merchant.getLiquidityAmounts(pool.reserveToken(), pool.couponToken(), 50);
		assertEq(liquidity, 2960504478772);
	}

	function testPause() public {
		vm.prank(governance);
		merchant.pause();
		assertTrue(merchant.paused());
	}

	function testUnpause() public {
		vm.startPrank(governance);
		merchant.pause();
		merchant.unpause();
		vm.stopPrank();
		assertFalse(merchant.paused());
	}
}
