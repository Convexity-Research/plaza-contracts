// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {Trader} from "./Trader.sol";
import {Decimals} from "./lib/Decimals.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// @todo: make it upgradable
contract Merchant is AccessControl, Pausable, Trader {
  using Decimals for uint256;

  uint256 private constant PRECISION = 10000;
  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  struct LimitOrder {
    address sell;
    address buy;
    uint256 price;
    uint256 amount;
    uint256 minAmount;
    bool filled;
  }

  mapping (address => LimitOrder[]) public orders;
  mapping (address => uint256) public ordersTimestamp;

  // Pool -> Period -> Has Stopped Selling
  mapping (address => mapping(uint256 => bool)) private hasStoppedSelling;

  event StoppedSelling(address pool);

  error ZeroPrice();
  error UpdateNotRequired();
  error NoOrdersToExecute();

  constructor(address _router, address _quoter, address _dexFactory) Trader(_router, _quoter, _dexFactory) {
    // @todo: update access control to copy Pool mechanism
    _setRoleAdmin(GOV_ROLE, GOV_ROLE);
    _grantRole(GOV_ROLE, msg.sender);
  }
  
  // this will be called by automation to check if there are any pending orders
  function hasPendingOrders(address _pool) public /*view*/ returns(bool) {
    if (ordersTimestamp[_pool] == 0) {
      return getLimitOrders(_pool).length > 0;
    }

    if (ordersTimestamp[_pool] + 12 hours <= block.timestamp) {
      return getLimitOrders(_pool).length > 0;
    }

    return false;
  }

  function updateLimitOrders(address _pool) external whenNotPaused() {
    // If 12 hours have not passed, revert
    if (ordersTimestamp[_pool] + 12 hours > block.timestamp) {
      revert UpdateNotRequired();
    }

    LimitOrder[] memory limitOrders = getLimitOrders(_pool);
    // If there are no orders to update, revert
    if (limitOrders.length == 0) {
      revert UpdateNotRequired();
    }

    orders[_pool] = limitOrders;
    ordersTimestamp[_pool] = block.timestamp;
  }

  function ordersPriceReached(address _pool) public view returns(bool) {
    LimitOrder[] memory limitOrders = orders[_pool];

    uint256 currentPrice = getPrice(Pool(_pool).reserveToken(), Pool(_pool).couponToken());
    for (uint256 i = 0; i < limitOrders.length; i++) {
      if (limitOrders[i].buy == address(0) || limitOrders[i].filled) {
        continue;
      }

      // if price is 0, it means it's a market order
      if (limitOrders[i].price == 0) {
        return true;
      }

      if (limitOrders[i].price <= currentPrice) {
        return true;
      }
    }

    return false;
  }

  function executeOrders(address _pool) external whenNotPaused() {
    if (!ordersPriceReached(_pool)) {
      revert NoOrdersToExecute();
    }

    address couponToken = Pool(_pool).couponToken();

    // @todo: duplicated checks from ordersPriceReached - refactor if gas becomes a problem
    LimitOrder[] memory limitOrders = orders[_pool];
    uint256 currentPrice = getPrice(Pool(_pool).reserveToken(), couponToken);
    uint256 poolReserves = getPoolReserves(_pool);

    for (uint256 i = 0; i < limitOrders.length; i++) {
      if (limitOrders[i].buy == address(0) || limitOrders[i].filled) {
        continue;
      }

      // if price is 0, it means it's a market order
      if (limitOrders[i].price == 0) {
        limitOrders[i].price = currentPrice;
        limitOrders[i].minAmount = (currentPrice * limitOrders[i].amount * 995) / 1000; // 0.5% less than order.price
      }

      if (limitOrders[i].price <= currentPrice) {
        uint256 amountOut = quote(limitOrders[i].sell, limitOrders[i].buy, limitOrders[i].amount);
        uint256 accruedCoupons = ERC20(couponToken).balanceOf(_pool);

        // This block implements a safety check to prevent over-selling of the pool's assets.
        // It ensures that the total coupon tokens bought (accruedCoupons) plus the expected
        // coupon tokens from this order (amountOut) does not exceed a certain threshold
        // relative to the remaining reserve tokens in the pool.
        // The threshold is dynamically calculated based on the current price of reserve token.
        // If this threshold is reached, it triggers a hard stop to prevent further selling.
        //
        // Calculation breakdown:
        // - (poolReserves - limitOrders[i].amount) represents the expected remaining reserve
        //   tokens after this order
        // - currentPrice is the current price of reserve tokens in coupon tokens
        // - The multiplier (19 in this case) represents the maximum allowed ratio of coupon
        //   tokens to reserve tokens (95% sell / 5% keep)
        if (accruedCoupons + amountOut > 19 * (poolReserves - limitOrders[i].amount) * currentPrice) {
          setHardStop(_pool);
          return;
        }

        swap(_pool, limitOrders[i]);
        limitOrders[i].filled = true;
      }
    }

    // Update storage
    orders[_pool] = limitOrders;
  }

  function getLimitOrders(address _pool) public returns(LimitOrder[] memory limitOrders) {
    Pool pool = Pool(_pool);
    Pool.PoolInfo memory poolInfo = Pool(_pool).getPoolInfo();

    // Hard stop
    if (hasStoppedSelling[_pool][poolInfo.currentPeriod]) {
      return limitOrders;
    }

    ERC20 reserveToken = ERC20(pool.reserveToken());
    ERC20 couponToken = ERC20(pool.couponToken());

    uint256 remainingCouponAmount = getRemainingCouponAmount(_pool);
    uint256 daysToPayment = getDaysToPayment(_pool);
    uint256 poolReserves = getPoolReserves(_pool);
    uint256 currentPrice = getPrice(address(reserveToken), address(couponToken));
    (,uint256 liquidity) = getLiquidityAmounts(address(reserveToken), address(couponToken), 50);

    require (currentPrice > 0, ZeroPrice());

    if (daysToPayment > 10 || remainingCouponAmount == 0) {
      return limitOrders;
    }

    // Ensure pool reserves is greater than coupon amount
    if (poolReserves * currentPrice <= remainingCouponAmount) {
      setHardStop(_pool);
      return limitOrders;
    }

    limitOrders = new LimitOrder[](5);
    uint256 maxOrder = 0;
    uint256 sellAmount = 0;
    uint256 price = 0;
    uint256 minAmount = 0;
    uint256[10] memory values;

    if (daysToPayment > 5) {
      
      values[0] = (250 * liquidity / PRECISION);
      values[1] = (1000 * remainingCouponAmount / (currentPrice * 10250)) / PRECISION;
      values[2] = (poolReserves * 9500) / PRECISION;

      maxOrder = min(values, 3);

      sellAmount = (maxOrder * 2000) / PRECISION;
      
      for (uint256 i = 1; i <= 5; i++) {
        price = (currentPrice * (PRECISION + (200*i))) / PRECISION;
        minAmount = (price * sellAmount * 995) / 1000; // 0.5% less than order.price

        limitOrders[i-1] = LimitOrder({
          buy: address(couponToken),
          sell: address(reserveToken),
          price: price,
          minAmount: minAmount,
          amount: sellAmount,
          filled: false
        });
      }
      return limitOrders;
    }

    if (daysToPayment > 1) {
      values[0] = (500 * liquidity / PRECISION);
      values[1] = (2000 * remainingCouponAmount / (currentPrice * 10250)) / PRECISION;
      values[2] = (poolReserves * 9500) / PRECISION;

      maxOrder = min(values, 3);

      sellAmount = (maxOrder * 2000) / PRECISION;
       
      for (uint256 i = 1; i <= 5; i++) {
        price = (currentPrice * (PRECISION + (200*i))) / PRECISION;
        minAmount = (price * sellAmount * 995) / 1000; // 0.5% less than order.price

        limitOrders[i-1] = LimitOrder({
          buy: address(couponToken),
          sell: address(reserveToken),
          price: price,
          amount: sellAmount,
          minAmount: minAmount,
          filled: false
        });
      }
      return limitOrders;
    }

    if (daysToPayment > 0) {
      values[0] = (500 * liquidity / PRECISION);
      values[1] = (remainingCouponAmount / (currentPrice * 10250)) / PRECISION;
      values[2] = (poolReserves * 9500) / PRECISION;

      maxOrder = min(values, 3);

      sellAmount = (maxOrder * 200000) / PRECISION;
       
      for (uint256 i = 1; i <= 5; i++) {
        price = (currentPrice * (PRECISION + (200*i))) / PRECISION;
        minAmount = (price * sellAmount * 995) / 1000; // 0.5% less than order.price

        limitOrders[i-1] = LimitOrder({
          buy: address(couponToken),
          sell: address(reserveToken),
          price: price,
          amount: sellAmount,
          minAmount: minAmount,
          filled: false
        });
      }
      return limitOrders;
    }

    // Sell what's left
    values[0] = (1000 * liquidity / PRECISION);
    values[1] = (remainingCouponAmount / currentPrice);
    values[2] = (poolReserves * 9500) / PRECISION;

    maxOrder = min(values, 3);
    
    limitOrders[0] = LimitOrder({
      buy: address(couponToken),
      sell: address(reserveToken),
      price: 0, // zero means market sell
      amount: maxOrder,
      minAmount: 0,
      filled: false
    });

    return limitOrders;
  }
  
  function sellCouponExcess(uint256 couponExcess) external {
    Pool pool = Pool(msg.sender);
    ERC20 reserveToken = ERC20(address(pool.reserveToken()));
    ERC20 couponToken = ERC20(address(pool.couponToken()));
    
    // @todo: update to safeDecimals when merged
    uint8 reserveDecimals = reserveToken.decimals();
    uint8 couponDecimals = couponToken.decimals();
    
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
    
    swap(msg.sender, LimitOrder({
      buy: address(reserveToken),
      sell: address(couponToken),
      price: 0, // not needed, market sell
      amount: couponExcess,
      minAmount: adjustedMinAmount,
      filled: false
    }));
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
    uint256 accruedCoupons = ERC20(pool.couponToken()).balanceOf(_pool);

    return (pool.bondToken().totalSupply() * poolInfo.sharesPerToken) - accruedCoupons;
  }

  function getPoolReserves(address _pool) public view returns(uint256) {
    Pool pool = Pool(_pool);
    ERC20 reserveToken = ERC20(pool.reserveToken());

    return reserveToken.balanceOf(_pool);
  }

  function setHardStop(address _pool) private {
    Pool.PoolInfo memory poolInfo = Pool(_pool).getPoolInfo();
    hasStoppedSelling[_pool][poolInfo.currentPeriod] = true;

    // remove all orders
    orders[_pool] = new LimitOrder[](0);

    emit StoppedSelling(_pool);
  }

  function pause() external onlyRole(GOV_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(GOV_ROLE) {
    _unpause();
  }
}
