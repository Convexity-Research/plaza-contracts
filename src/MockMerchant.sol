// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {Decimals} from "./lib/Decimals.sol";
import {Token} from "../test/mocks/Token.sol";
import {OracleReader} from "./OracleReader.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockMerchant is OracleReader {
  using Decimals for uint256;

  constructor(address _ethPriceFeed) {
    __OracleReader_init(_ethPriceFeed);
  }

  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  function executeOrders(address _pool) external {
    require(getDaysToPayment(_pool) == 0, "Merchant: Payment period not over");
    Token couponToken = Token(Pool(_pool).couponToken());
    Token reserveToken = Token(Pool(_pool).reserveToken());
    
    uint8 oracleDecimals = getOracleDecimals(address(0), address(0));
    uint256 reservePrice = getOraclePrice(address(0), address(0)).normalizeAmount(oracleDecimals, couponToken.decimals());
    require(reservePrice > 0, "Merchant: Invalid reserve price");

    uint256 couponAmount = getCouponAmount(_pool);

    couponToken.mint(_pool, couponAmount);
    reserveToken.burn(_pool, couponAmount / reservePrice);
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
    uint256 accruedCoupons = IERC20(pool.couponToken()).balanceOf(_pool);

    return (pool.bondToken().totalSupply() * poolInfo.sharesPerToken) - accruedCoupons;
  }

  function getPoolReserves(address _pool) public view returns(uint256) {
    Pool pool = Pool(_pool);

    return IERC20(pool.reserveToken()).balanceOf(_pool);
  }
}
