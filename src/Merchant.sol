// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {Trader} from "./Trader.sol";
import {Decimals} from "./lib/Decimals.sol";
import {ERC20Extensions} from "./lib/ERC20Extensions.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// @todo: make it upgradable
contract Merchant is AccessControl, Pausable, Trader {
  using Decimals for uint256;
  using ERC20Extensions for IERC20;

  uint256 private constant PRECISION = 10000;
  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  enum OrderType {
    LIMIT,
    MARKET
  }

  struct Order {
    OrderType orderType;
    address sell;
    address buy;
    uint256 price;
    uint256 amount;
    uint256 minAmount;
    bool filled;
  }

  mapping (address => Order) public orders;
  mapping (address => uint256) public ordersTimestamp;

  // Pool -> Period -> Has Stopped Selling
  mapping (address => mapping(uint256 => bool)) private hasStoppedSelling;

  event StoppedSelling(address pool);
  event OrderPlaced(address pool, OrderType orderType, address sell, address buy, uint256 amount, uint256 price);
  event OrderExecuted(address pool, OrderType orderType, address sell, address buy, uint256 amount, uint256 price);

  error ZeroPrice();
  error UpdateNotRequired();
  error NoOrdersToExecute();

  constructor(address _router, address _quoter, address _dexFactory) Trader(_router, _quoter, _dexFactory) {
    // @todo: update access control to copy Pool mechanism
    _setRoleAdmin(GOV_ROLE, GOV_ROLE);
    _grantRole(GOV_ROLE, msg.sender);
  }
  
  // this will be called by automation to check if there are any pending orders
  function needsNewOrders(address _pool) public /*view*/ returns(bool) {
    if (ordersTimestamp[_pool] == 0) {
      return getOrder(_pool).sell != address(0);
    }

    if (ordersTimestamp[_pool] + 12 hours <= block.timestamp) {
      return getOrder(_pool).sell != address(0);
    }

    return false;
  }

  function updateOrders(address _pool) external whenNotPaused() {
    // If 12 hours have not passed, revert
    if (ordersTimestamp[_pool] + 12 hours > block.timestamp) {
      revert UpdateNotRequired();
    }

    Order memory order = getOrder(_pool);
    // If there are no orders to update, revert
    if (order.sell == address(0)) {
      revert UpdateNotRequired();
    }

    orders[_pool] = order;
    ordersTimestamp[_pool] = block.timestamp;

    emit OrderPlaced(_pool, order.orderType, order.sell, order.buy, order.amount, order.price);
  }

  function ordersPriceReached(address _pool) public returns(bool) {
    Order memory order = orders[_pool];

    uint256 orderPrice = quoteBasedPrice(order.sell, order.buy, order.amount);
    if (order.buy == address(0) || order.filled) {
      return false;
    }

    return order.orderType == OrderType.MARKET || order.price <= orderPrice;
  }

  function executeOrders(address _pool) external whenNotPaused() {
    if (!ordersPriceReached(_pool)) {
      revert NoOrdersToExecute();
    }

    address couponToken = Pool(_pool).couponToken();

    Order memory order = orders[_pool];
    uint256 currentPrice = quoteBasedPrice(Pool(_pool).reserveToken(), couponToken, order.amount);
    uint256 poolReserves = getPoolReserves(_pool);

    // if price is 0, it means it's a market order
    if (order.orderType == OrderType.MARKET) {
      order.price = currentPrice;
      order.minAmount = (currentPrice * order.amount * 995) / 1000; // 0.5% less than order.price
    }

    uint256 amountOut = quote(order.sell, order.buy, order.amount);
    uint256 accruedCoupons = IERC20(couponToken).balanceOf(_pool);

    // This block implements a safety check to prevent over-selling of the pool's assets.
    // It ensures that the total coupon tokens bought (accruedCoupons) plus the expected
    // coupon tokens from this order (amountOut) does not exceed a certain threshold
    // relative to the remaining reserve tokens in the pool.
    // The threshold is dynamically calculated based on the current price of reserve token.
    // If this threshold is reached, it triggers a hard stop to prevent further selling.
    //
    // Calculation breakdown:
    // - (poolReserves - order.amount) represents the expected remaining reserve
    //   tokens after this order
    // - currentPrice is the current price of reserve tokens in coupon tokens
    // - The multiplier (19 in this case) represents the maximum allowed ratio of coupon
    //   tokens to reserve tokens (95% sell / 5% keep)
    if (accruedCoupons + amountOut > 19 * (poolReserves - order.amount) * currentPrice) {
      setHardStop(_pool);
      return;
    }

    swap(_pool, order);
    order.filled = true;

    // reset orders timestamp
    ordersTimestamp[_pool] = 0;

    // Update storage
    orders[_pool] = order;

    emit OrderExecuted(_pool, order.orderType, order.sell, order.buy, order.amount, order.price);
  }

  function getOrder(address _pool) public returns(Order memory order) {
    Pool pool = Pool(_pool);
    Pool.PoolInfo memory poolInfo = Pool(_pool).getPoolInfo();

    // Hard stop
    if (hasStoppedSelling[_pool][poolInfo.currentPeriod]) {
      return order;
    }

    address reserveToken = pool.reserveToken();
    address couponToken = pool.couponToken();

    uint256 remainingCouponAmount = getRemainingCouponAmount(_pool);
    uint256 daysToPayment = getDaysToPayment(_pool);
    uint256 poolReserves = getPoolReserves(_pool);

    // price of reserveToken in couponToken/
    uint256 currentPrice = getPrice(reserveToken, couponToken);
    (,uint256 liquidity) = getLiquidityAmounts(reserveToken, couponToken, 100);

    require (currentPrice > 0, ZeroPrice());

    if (daysToPayment > 10 || remainingCouponAmount == 0) {
      return order;
    }

    // Ensure pool reserves is greater than coupon amount
    if (poolReserves * currentPrice <= remainingCouponAmount) {
      setHardStop(_pool);
        return order;
    }

    uint256 maxOrder = 0;
    uint256 sellAmount = 0;
    uint256 price = 0;
    uint256 minAmount = 0;
    uint256[10] memory potentialOrderSizes;

    if (daysToPayment > 5) {
      
      // 2.5% of liquidity
      potentialOrderSizes[0] = (250 * liquidity / PRECISION);
      // 10% of remainingCouponAmount / 102.5% of currentPrice
      potentialOrderSizes[1] = (1000 * remainingCouponAmount / (currentPrice * 10250)) / PRECISION;
      // 95% of poolReserves
      potentialOrderSizes[2] = (poolReserves * 9500) / PRECISION;

      maxOrder = min(potentialOrderSizes, 3);

      // 20% of maxOrder
      sellAmount = (maxOrder * 2000) / PRECISION;
      
      // 102% of currentPrice
      price = (currentPrice * (PRECISION + 200)) / PRECISION;

      // 99.5% of tokens to receive
      minAmount = (price * sellAmount * 995) / 1000; // 0.5% less than order.price

      return Order({
        orderType: OrderType.LIMIT,
        buy: address(couponToken),
        sell: address(reserveToken),
        price: price,
        minAmount: minAmount,
        amount: sellAmount,
        filled: false
      });
    }

    if (daysToPayment > 1) {
      // 5% of liquidity
      potentialOrderSizes[0] = (500 * liquidity / PRECISION);
      // 20% of remainingCouponAmount / 102.5% of currentPrice
      potentialOrderSizes[1] = (2000 * remainingCouponAmount / (currentPrice * 10250)) / PRECISION;
      // 95% of poolReserves
      potentialOrderSizes[2] = (poolReserves * 9500) / PRECISION;

      maxOrder = min(potentialOrderSizes, 3);

      // 20% of maxOrder
      sellAmount = (maxOrder * 2000) / PRECISION;
      
      // 102% of currentPrice
      price = (currentPrice * (PRECISION + 200)) / PRECISION;
      
      // 99.5% of tokens to receive
      minAmount = (price * sellAmount * 995) / 1000; // 0.5% less than order.price

      return Order({
        orderType: OrderType.LIMIT,
        buy: address(couponToken),
        sell: address(reserveToken),
        price: price,
        amount: sellAmount,
        minAmount: minAmount,
        filled: false
      });
    }

    if (daysToPayment > 0) {
      // 10% of liquidity
      potentialOrderSizes[0] = (1000 * liquidity / PRECISION);
      // 100% of remainingCouponAmount / 102.5% of currentPrice
      potentialOrderSizes[1] = (10000 * remainingCouponAmount / (currentPrice * 10250)) / PRECISION;
      // 95% of poolReserves
      potentialOrderSizes[2] = (poolReserves * 9500) / PRECISION;

      maxOrder = min(potentialOrderSizes, 3);

      sellAmount = (maxOrder * 2000) / PRECISION;
      
      return Order({
        orderType: OrderType.LIMIT,
        buy: address(couponToken),
        sell: address(reserveToken),
        price: price,
        amount: sellAmount,
        minAmount: minAmount,
        filled: false
      });
    }

    // Sell what's left
    // 10% of liquidity
    potentialOrderSizes[0] = (1000 * liquidity / PRECISION);
    potentialOrderSizes[1] = (remainingCouponAmount / currentPrice);
    // 95% of poolReserves
    potentialOrderSizes[2] = (poolReserves * 9500) / PRECISION;
    
    return Order({
      orderType: OrderType.MARKET,
      buy: address(couponToken),
      sell: address(reserveToken),
      price: 0,
      amount: min(potentialOrderSizes, 3),
      minAmount: 0,
      filled: false
    });
  }
  
  function sellCouponExcess(uint256 couponExcess) external {
    Pool pool = Pool(msg.sender);
    IERC20 reserveToken = IERC20(pool.reserveToken());
    IERC20 couponToken = IERC20(pool.couponToken());
    
    // @todo: update to safeDecimals when merged
    uint8 reserveDecimals = reserveToken.safeDecimals();
    uint8 couponDecimals = couponToken.safeDecimals();
    
    // Get the current price from Uniswap V3 router's quote method
    // currentPrice: amount of couponToken per 1e18 units of reserveToken
    uint256 currentPrice = getPrice(address(reserveToken), address(couponToken));
    if (currentPrice == 0) { return; }
    
    // Normalize couponExcess to 18 decimals (if not already)
    uint256 normalizedCouponExcess = couponExcess.normalizeAmount(couponDecimals, 18);

    // Calculate the exchange rate: R = 1e18 / currentPrice
    uint256 exchangeRate = (1e18 * 1e18) / currentPrice; // scaled by 1e18

    // Calculate minAmount in 18 decimals
    uint256 minAmount = (normalizedCouponExcess * exchangeRate) / 1e18; // Now minAmount is scaled to 18 decimals

    // Adjust minAmount to reserveToken decimals
    uint256 adjustedMinAmount = minAmount.normalizeAmount(18, reserveDecimals);
    
    Order memory order = Order({
      orderType: OrderType.MARKET,
      buy: address(reserveToken),
      sell: address(couponToken),
      price: 0, // not needed, market sell
      amount: couponExcess,
      minAmount: adjustedMinAmount,
      filled: false
    });

    emit OrderPlaced(msg.sender, order.orderType, order.sell, order.buy, order.amount, order.price);
    swap(msg.sender, order);
    emit OrderExecuted(msg.sender, order.orderType, order.sell, order.buy, order.amount, order.price);
  }
  
  function min(uint256[10] memory values, uint8 length) public pure returns (uint256) {
    uint256 m = values[0];
    for (uint256 i = 1; i < length; i++) {
      if (values[i] < m) {
        m = values[i];
      }
    }
    return m;
  }
  
  function getDaysToPayment(address _pool) public view returns(uint8) {
    Pool pool = Pool(_pool);
    Pool.PoolInfo memory poolInfo = pool.getPoolInfo();

    // @todo: reading storage twice, use memory
    if (poolInfo.lastDistribution + poolInfo.distributionPeriod < block.timestamp) {
      // @todo: what if last+period < timestamp? bad
      // this shouldn't happen, but what if it does?
      return 0;
    }
    
    return uint8((poolInfo.lastDistribution + poolInfo.distributionPeriod - block.timestamp) / 86400);
  }

  function getRemainingCouponAmount(address _pool) public view returns(uint256) {
    Pool pool = Pool(_pool);

    Pool.PoolInfo memory poolInfo = pool.getPoolInfo();
    uint256 accruedCoupons = IERC20(pool.couponToken()).balanceOf(_pool);

    return (pool.bondToken().totalSupply() * poolInfo.sharesPerToken) - accruedCoupons;
  }

  function getPoolReserves(address _pool) public view returns(uint256) {
    Pool pool = Pool(_pool);
    IERC20 reserveToken = IERC20(pool.reserveToken());

    return reserveToken.balanceOf(_pool);
  }

  function setHardStop(address _pool) private {
    Pool.PoolInfo memory poolInfo = Pool(_pool).getPoolInfo();
    hasStoppedSelling[_pool][poolInfo.currentPeriod] = true;

    // remove all orders
    delete orders[_pool];

    emit StoppedSelling(_pool);
  }

  function pause() external onlyRole(GOV_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(GOV_ROLE) {
    _unpause();
  }
}
