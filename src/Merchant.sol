// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Merchant is AccessControl, Pausable {
  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  struct LimitOrder {
    address sell;
    address buy;
    uint256 price;
    uint256 amount;
  }

  struct DayMarketData {
    uint256[10] weightedAverageHighs;
    uint256[10] weightedAverageLows;
    uint256[10] volumes;
  }

  mapping (address => DayMarketData) poolMarketData;
  mapping (address => uint256) accuredCoupons;

  error ZeroPrice();
  error NoVolumeInfo();
  error InconsistentMarketData();

  constructor() {
    _setRoleAdmin(GOV_ROLE, GOV_ROLE);
    _grantRole(GOV_ROLE, msg.sender);
  }

  // @todo: remove
  function mockMarket(address pool) public {
    DayMarketData memory dayMarketData;
    dayMarketData.weightedAverageHighs = [uint256(100), uint256(102), uint256(101), uint256(103), uint256(99), uint256(98), uint256(102), uint256(101), uint256(100), uint256(99)];
    dayMarketData.weightedAverageLows = [uint256(99), uint256(101), uint256(100), uint256(102), uint256(97), uint256(95), uint256(101), uint256(100), uint256(98), uint256(94)];
    dayMarketData.volumes = [uint256(1000), uint256(1200), uint256(1100), uint256(1300), uint256(1250), uint256(1350), uint256(1400), uint256(5000), uint256(200), uint256(3000)];
    
    poolMarketData[pool] = dayMarketData;
  }

  function placeOrders(address _pool) external {
    LimitOrder[] memory orders = getLimitOrders(_pool);

    uniswapMagic(orders);
  }

  function getLimitOrders(address _pool) public view returns(LimitOrder[] memory orders) {
    mockMarket(_pool);
    Pool pool = Pool(_pool);
    ERC20 reserveToken = ERC20(pool.reserveToken());
    ERC20 couponToken = ERC20(pool.couponToken());

    uint256 precision = pool.PRECISION();
    uint256 couponAmount = getCouponAmount(_pool);
    uint256 daysToPayment = getDaysToPayment(_pool);
    uint256 poolReserves = getPoolReserves(_pool);
    uint256 marketDepth = getCurrentMarketDepth(address(reserveToken), address(couponToken));
    uint256 currentPrice = getCurrentPrice(address(reserveToken), address(couponToken));
    require (currentPrice > 0, ZeroPrice());

    DayMarketData memory market = poolMarketData[_pool];
    (uint256 averageVolume, uint256 waHighs, uint256 waLows) = processMarketData(market);

    if (daysToPayment > 10 || couponAmount == 0) {
      return orders;
    }

    // It should not happen - something likely wrong
    assert(poolReserves * currentPrice <= couponAmount);

    if (daysToPayment > 5) {
      uint256 maxOrder = min((50000 * averageVolume / precision), 
                        min((200000 * current_market_depth) / precision,
                        min((100000 * couponAmount / (currentPrice * 1025000)) / precision, 
                        (poolReserves * 950000) / precision)));

      uint256 sellAmount = (maxOrder * 100000) / precision;
      if (currentPrice > waHighs || currentPrice < waLows) {
        sellAmount = (maxOrder * 200000) / precision;
      }
       
      for (uint256 i = 0; i < 5; i++) {
        orders.push(LimitOrder({
          buy: address(couponToken),
          sell: address(reserveToken),
          price: (currentPrice * (1010000 + (10000*i))) / precision,
          amount: sellAmount
        }));
      }
      return orders;
    }

    if (daysToPayment > 1) {
      uint256 maxOrder = min((50000 * averageVolume / precision), 
                        min((200000 * current_market_depth) / precision,
                        min((200000 * couponAmount / (currentPrice * 1025000)) / precision, 
                        (poolReserves * 950000) / precision)));

      uint256 sellAmount = (maxOrder * 200000) / precision;
       
      for (uint256 i = 0; i < 5; i++) {
        orders.push(LimitOrder({
          buy: address(couponToken),
          sell: address(reserveToken),
          price: (currentPrice * (10010000 + (10000*i))) / precision,
          amount: sellAmount
        }));
      }
      return orders;
    }

    if (daysToPayment > 0) {
      uint256 maxOrder = min((50000 * averageVolume / precision), 
                        min((200000 * current_market_depth) / precision,
                        min((1000000 * couponAmount / (currentPrice * 1025000)) / precision, 
                        (poolReserves * 950000) / precision)));

      uint256 sellAmount = (maxOrder * 200000) / precision;
       
      for (uint256 i = 0; i < 5; i++) {
        orders.push(LimitOrder({
          buy: address(couponToken),
          sell: address(reserveToken),
          price: (currentPrice * (10010000 + (10000*i))) / precision,
          amount: sellAmount
        }));
      }
      return orders;
    }

    // Sell what's left
    uint256 maxOrder = min((50000 * averageVolume / precision), 
                        min((200000 * current_market_depth) / precision,
                        min(couponAmount / currentPricen, 
                        (poolReserves * 950000) / precision)));
    
    orders.push(LimitOrder({
      buy: address(couponToken),
      sell: address(reserveToken),
      price: 0, // zero means market sell
      amount: maxOrder
    }));

    return orders;
  }

  function min(uint256 a, uint256 b) public pure returns (uint256) {
    return a < b ? a : b;
  }

  function processMarketData(DayMarketData memory market) private returns(uint256 averageVolume, uint256 waHighs, uint256 waLows) {
    uint256 len = market.volumes.length;
    
    require(len == market.weightedAverageHighs.length, InconsistentMarketData());
    require(len == market.weightedAverageLows.length, InconsistentMarketData());
    
    uint256 sumHighs;
    uint256 sumLows;
    uint256 sumVolumes;
    for (uint256 i = 0; i < len; i++) {
      sumHighs = sumHighs + market.weightedAverageHighs[i];
      sumLows = sumLows + market.weightedAverageLows[i];
      sumVolumes = sumVolumes + market.volumes[i];
    }
    require(sumVolumes > 0, NoVolumeInfo());
    
    averageVolume = sumVolumes / len;
    waLows = sumHighs / sumVolumes;
    waLows = sumLows / sumVolumes;
  }

  function getCurrentPrice(address token0, address token1) public view returns(uint256) {
    return 3000000000;
  }

  function getCurrentMarketDepth(address token0, address token1) public view returns(uint256) {
    return 20000;
  }

  function getDaysToPayment(address _pool) public view returns(uint8) {
    Pool pool = Pool(_pool);

    // @tood: reading storage twice, use memory
    if (pool.lastDistributionTime() + pool.distributionPeriod() < block.timestamp) {
      // @todo: what if last+period < timestamp? bad
      // this shouldn't happen, but what if it does?
      return 0;
    }
    
    return uint8((pool.lastDistributionTime() + pool.distributionPeriod() - block.timestamp) / 86400);
  }

  function getCouponAmount(address _pool) public view returns(uint256) {
    Pool pool = Pool(_pool);
    ERC20 couponToken = ERC20(pool.couponToken());
    ERC20 bondToken = ERC20(address(pool.dToken()));
    uint256 sharesPerToken = pool.sharesPerToken();

    return ((bondToken.totalSupply() * sharesPerToken) / pool.PRECISION()) - accuredCoupons[_pool];
  }

  function getPoolReserves(address _pool) public view returns(uint256) {
    Pool pool = Pool(_pool);
    ERC20 reserveToken = ERC20(pool.reserveToken());

    // @todo: Do we need the value in units, USD terms or coupon token terms?
    return reserveToken.balanceOf(_pool);
  }

  function pause() external onlyRole(GOV_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(GOV_ROLE) {
    _unpause();
  }
}
