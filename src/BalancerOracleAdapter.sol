// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Decimals} from "./lib/Decimals.sol";
import {IERC20} from "@balancer/contracts/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {OracleReader} from "./OracleReader.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IBalancerV2WeightedPool} from "./lib/balancer/IBalancerV2WeightedPool.sol";
import {FixedPoint} from "./lib/balancer/FixedPoint.sol";

contract BalancerOracleAdapter is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable, AggregatorV3Interface, OracleReader {
  using Decimals for uint256;
  using FixedPoint for uint256;

  address public poolAddress;
  uint8 DECIMALS;

  error PriceTooLargeForIntConversion();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _poolAddress,
    uint8 _decimals,
    address _oracleFeeds
  ) initializer public {
    __OracleReader_init(_oracleFeeds);
    __ReentrancyGuard_init();
    __Pausable_init();
    poolAddress = _poolAddress;
    DECIMALS = _decimals;
  }

  function decimals() external view returns (uint8){
    return DECIMALS;
  }

  function description() external view returns (string memory){
    return "Balancer Pool Chainlink Adapter";
  }

  function version() external view returns (uint256){
    return 1;
  }

  function getRoundData(
    uint80 _roundId
  ) public view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
    IBalancerV2WeightedPool pool = IBalancerV2WeightedPool(poolAddress);
    (IERC20[] memory tokens, uint256[] memory balances,) = IVault(pool.getVault()).getPoolTokens(pool.getPoolId());
    //get weights
    uint256[] memory weights = pool.getNormalizedWeights();

    uint256[] memory prices = new uint256[](tokens.length);
    for(uint8 i = 0; i < tokens.length; i++) {
      getOraclePrice(address(tokens[i]), ETH);
    }

    uint256 fairUintETHPrice = _calculateFairUintPrice(prices, weights, pool.getInvariant(), pool.getActualSupply());
    uint256 fairUintUSDPrice = fairUintETHPrice * getOraclePrice(ETH, USD);

    if (fairUintUSDPrice > (2^256>>1)-1) {
      revert PriceTooLargeForIntConversion();
    }

    return (uint80(0), int256(fairUintUSDPrice), block.timestamp, block.timestamp, uint80(0));
  }

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
      return getRoundData(0);
    }
    
  function calculateFairUintPrice(uint256[] memory prices, uint256[] memory weights, uint256 invariant, uint256 totalBPTSupply) external view returns (uint256) {
    return _calculateFairUintPrice(prices, weights, invariant, totalBPTSupply);
  }

  function _calculateFairUintPrice(uint256[] memory prices, uint256[] memory weights, uint256 invariant, uint256 totalBPTSupply) internal view returns (uint256) {
    uint256 priceWeightPower = 1;
    for(uint8 i = 0; i < prices.length; i ++) {
      priceWeightPower *= (prices[i].divDown(weights[i])).powDown(weights[i]);
    }
    return (invariant * priceWeightPower / totalBPTSupply).toBaseUnit(DECIMALS);
  }
}