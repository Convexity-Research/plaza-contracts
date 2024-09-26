// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "../src/Pool.sol";
import "./mocks/Token.sol";
import "forge-std/Test.sol";
import "../src/Merchant.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Distributor} from "../src/Distributor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TokenDeployer} from "../src/utils/TokenDeployer.sol";

contract MerchantTest is Test {
	Merchant public merchant;
	Pool public pool;
	Token public reserveToken;
	Token public couponToken;
	Token public dToken;
	Token public lToken;

	address public constant governance = address(0x1);
  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);

	function setUp() public {
		vm.startPrank(governance);

    Distributor distributor = Distributor(Utils.deploy(address(new Distributor()), abi.encodeCall(Distributor.initialize, (governance))));

    address tokenDeployer = address(new TokenDeployer());

    PoolFactory poolFactory = PoolFactory(
      Utils.deploy(address(new PoolFactory()), 
      abi.encodeCall(PoolFactory.initialize,
      (governance, tokenDeployer, address(distributor), ethPriceFeed)))
    );

    distributor.grantRole(distributor.POOL_FACTORY_ROLE(), address(poolFactory));

    uint256 reserveAmount = 1_000_000 ether;
    uint256 bondAmount = 25_000_000 ether;
    uint256 leverageAmount = 1_000_000 ether;
    uint256 sharesPerToken = 2_500_000;
    uint256 distributionPeriod = 7776000;

    PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
      fee: 0,
      sharesPerToken: sharesPerToken,
      reserveToken: address(new Token("Wrapped ETH", "WETH")),
      distributionPeriod: distributionPeriod,
      couponToken: address(new Token("Circle USD", "USDC"))
    });

    // Mint reserve tokens
    Token(params.reserveToken).mint(governance, reserveAmount);
    Token(params.reserveToken).approve(address(poolFactory), reserveAmount);

    // Create pool and approve deposit amount
    pool = Pool(poolFactory.CreatePool(params, reserveAmount, bondAmount, leverageAmount));
    
    merchant = new Merchant(address(0x0), address(0x0), address(0x0));
    vm.stopPrank();
	}

	// function testHasPendingOrders() public {
	// 	assertFalse(merchant.hasPendingOrders(address(pool)));

	// 	// Set up pool info to trigger pending orders
	// 	vm.warp(block.timestamp + 13 hours);

	// 	assertTrue(merchant.hasPendingOrders(address(pool)));
	// }

	// function testUpdateLimitOrders() public {
	// 	vm.expectRevert(Merchant.UpdateNotRequired.selector);
	// 	merchant.updateLimitOrders(address(pool));

	// 	vm.warp(block.timestamp + 13 hours);
	// 	merchant.updateLimitOrders(address(pool));

	// 	// Check that orders were updated
	// 	(address sell, address buy, uint256 price, uint256 amount, bool filled) = merchant.orders(address(pool), 0);
	// 	assertEq(sell, address(reserveToken));
	// 	assertEq(buy, address(couponToken));
	// 	assertTrue(price > 0);
	// 	assertTrue(amount > 0);
	// 	assertFalse(filled);
	// }

	// function testOrdersPriceReached() public {
	// 	vm.warp(block.timestamp + 13 hours);
	// 	merchant.updateLimitOrders(address(pool));

	// 	assertTrue(merchant.ordersPriceReached(address(pool)));
	// }

	// function testExecuteOrders() public {
	// 	vm.warp(block.timestamp + 13 hours);
	// 	merchant.updateLimitOrders(address(pool));

	// 	merchant.executeOrders(address(pool));

	// 	// Check that orders were executed
	// 	(,,,, bool filled) = merchant.orders(address(pool), 0);
	// 	assertTrue(filled);
	// }

	// function testGetLimitOrders() public {
	// 	Merchant.LimitOrder[] memory orders = merchant.getLimitOrders(address(pool));
	// 	assertEq(orders.length, 5);
	// }

	// function testGetCurrentPrice() public {
	// 	uint256 price = merchant.getCurrentPrice(address(reserveToken), address(couponToken));
	// 	assertEq(price, 3000000000);
	// }

	function testGetDaysToPayment() view public {
		uint8 daysToPayment = merchant.getDaysToPayment(address(pool));
		assertEq(daysToPayment, 90);
	}

	function testGetRemainingCouponAmount() view public {
		uint256 couponAmount = merchant.getRemainingCouponAmount(address(pool));
		assertEq(couponAmount, 62500000000000000000000000000000);
	}

	function testGetPoolReserves() view public {
		uint256 reserves = merchant.getPoolReserves(address(pool));
		assertEq(reserves, 1000000000000000000000000);
	}

	// function testGetLiquidity() view public {
	// 	uint256 liquidity = merchant.getLiquidity(address(reserveToken), address(couponToken));
	// 	assertEq(liquidity, 1000000000000000000000000000000);
	// }

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
