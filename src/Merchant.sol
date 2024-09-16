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
    bool filled;
  }

  mapping (address => LimitOrder[]) public orders;
  mapping (address => uint256) public ordersTimestamp;

  // Pool -> Period -> Has Stopped Selling
  mapping (address => mapping(uint256 => bool)) private hasStoppedSelling;

  error ZeroPrice();
  error UpdateNotRequired();
  error NoOrdersToExecute();

  constructor(address _router, address _quoter, address _factory) Trader(_router, _quoter, _factory) {
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

  function updateLimitOrders(address _pool) external {
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

  function ordersPriceReached(address _pool) public /*view*/ returns(bool) {
    LimitOrder[] memory limitOrders = orders[_pool];

    uint256 currentPrice = getCurrentPrice(Pool(_pool).reserveToken(), Pool(_pool).couponToken());
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

  function executeOrders(address _pool) external {
    if (!ordersPriceReached(_pool)) {
      revert NoOrdersToExecute();
    }

    // @todo: duplicated checks from ordersPriceReached - refactor if gas becomes a problem
    LimitOrder[] memory limitOrders = orders[_pool];
    uint256 currentPrice = getCurrentPrice(Pool(_pool).reserveToken(), Pool(_pool).couponToken());
    uint256 poolReserves = getPoolReserves(_pool);

    // 94% of the pool liquidity
    uint256 minLiquidity = (currentPrice * poolReserves * 94) / 100;

    for (uint256 i = 0; i < limitOrders.length; i++) {
      if (limitOrders[i].buy == address(0) || limitOrders[i].filled) {
        continue;
      }

      // if price is 0, it means it's a market order
      if (limitOrders[i].price == 0) {
        limitOrders[i].price = currentPrice;

        swap(_pool, limitOrders[i]);
        limitOrders[i].filled = true;
      }

      if (limitOrders[i].price <= currentPrice) {
        swap(_pool, limitOrders[i]);
        limitOrders[i].filled = true;
      }

      if (minLiquidity <= limitOrders[i].amount) {
        Pool.PoolInfo memory poolInfo = Pool(_pool).getPoolInfo();
        hasStoppedSelling[_pool][poolInfo.currentPeriod] = true;

        // remove all orders
        orders[_pool] = new LimitOrder[](0);

        return;
      }
    }

    // Update storage
    orders[_pool] = limitOrders;
  }

  function getLimitOrders(address _pool) public /*view*/ returns(LimitOrder[] memory limitOrders) {
    Pool pool = Pool(_pool);
    Pool.PoolInfo memory poolInfo = Pool(_pool).getPoolInfo();
    
    // Hard stop if 95% of the liquidity is sold
    if (hasStoppedSelling[_pool][poolInfo.currentPeriod]) {
      return limitOrders;
    }

    ERC20 reserveToken = ERC20(pool.reserveToken());
    ERC20 couponToken = ERC20(pool.couponToken());

    uint256 couponAmount = getCouponAmount(_pool);
    uint256 daysToPayment = getDaysToPayment(_pool);
    uint256 poolReserves = getPoolReserves(_pool);
    uint256 currentPrice = getCurrentPrice(address(reserveToken), address(couponToken));
    uint256 liquidity = getLiquidity(address(reserveToken), address(couponToken));
    require (currentPrice > 0, ZeroPrice());

    if (daysToPayment > 10 || couponAmount == 0) {
      return limitOrders;
    }

    // It should not happen - something likely wrong
    // @todo: should we do anything else here?
    assert(poolReserves * currentPrice <= couponAmount);

    limitOrders = new LimitOrder[](5);
    uint256 maxOrder = 0;
    uint256 sellAmount = 0;

    if (daysToPayment > 5) {
      maxOrder = min((250 * liquidity / PRECISION),
                  min((1000 * couponAmount / (currentPrice * 10250)) / PRECISION, 
                  (poolReserves * 9500) / PRECISION));

      sellAmount = (maxOrder * 2000) / PRECISION;
       
      for (uint256 i = 1; i <= 5; i++) {
        limitOrders[i-1] = LimitOrder({
          buy: address(couponToken),
          sell: address(reserveToken),
          price: (currentPrice * (PRECISION + (200*i))) / PRECISION,
          amount: sellAmount,
          filled: false
        });
      }
      return limitOrders;
    }

    if (daysToPayment > 1) {
      maxOrder = min((500 * liquidity / PRECISION),
                  min((2000 * couponAmount / (currentPrice * 10250)) / PRECISION, 
                  (poolReserves * 9500) / PRECISION));

      sellAmount = (maxOrder * 2000) / PRECISION;
       
      for (uint256 i = 1; i <= 5; i++) {
        limitOrders[i-1] = LimitOrder({
          buy: address(couponToken),
          sell: address(reserveToken),
          price: (currentPrice * (PRECISION + (100*i))) / PRECISION,
          amount: sellAmount,
          filled: false
        });
      }
      return limitOrders;
    }

    if (daysToPayment > 0) {
      maxOrder = min((500 * liquidity / PRECISION),
                  min((couponAmount / (currentPrice * 10250)) / PRECISION, 
                  (poolReserves * 9500) / PRECISION));

      sellAmount = (maxOrder * 200000) / PRECISION;
       
      for (uint256 i = 1; i <= 5; i++) {
        limitOrders[i-1] = LimitOrder({
          buy: address(couponToken),
          sell: address(reserveToken),
          price: (currentPrice * (PRECISION + (10*i))) / PRECISION,
          amount: sellAmount,
          filled: false
        });
      }
      return limitOrders;
    }

    // Sell what's left
    maxOrder = min((1000 * liquidity / PRECISION),
                min((couponAmount / currentPrice),
                (poolReserves * 9500) / PRECISION));
    
    limitOrders[0] = LimitOrder({
      buy: address(couponToken),
      sell: address(reserveToken),
      price: 0, // zero means market sell
      amount: maxOrder,
      filled: false
    });

    return limitOrders;
  }

  function min(uint256 a, uint256 b) public pure returns (uint256) {
    return a < b ? a : b;
  }

  function getCurrentPrice(address token0, address token1) public returns(uint256) {
    return quote(token0, token1, 1 ether);
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

  function getCouponAmount(address _pool) public view returns(uint256) {
    Pool pool = Pool(_pool);

    Pool.PoolInfo memory poolInfo = pool.getPoolInfo();
    uint256 accuredCoupons = ERC20(pool.couponToken()).balanceOf(_pool);

    return (pool.dToken().totalSupply() * poolInfo.sharesPerToken) - accuredCoupons;
  }

  function getPoolReserves(address _pool) public view returns(uint256) {
    Pool pool = Pool(_pool);
    ERC20 reserveToken = ERC20(pool.reserveToken());

    return reserveToken.balanceOf(_pool);
  }

  function pause() external onlyRole(GOV_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(GOV_ROLE) {
    _unpause();
  }
}
