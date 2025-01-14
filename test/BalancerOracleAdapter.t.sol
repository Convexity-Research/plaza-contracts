// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Utils} from "../src/lib/Utils.sol";
import {Decimals} from "../src/lib/Decimals.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";
import {FixedPoint} from "../src/lib/balancer/FixedPoint.sol";
import {BalancerOracleAdapter} from "../src/BalancerOracleAdapter.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IBalancerV2WeightedPool} from "../src/lib/balancer/IBalancerV2WeightedPool.sol";
import {IERC20} from "@balancer/contracts/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract BalancerOracleAdapterTest is Test, BalancerOracleAdapter {
  using Decimals for uint256;
  using FixedPoint for uint256;
  BalancerOracleAdapter private adapter;

  address private poolAddr = address(0x1);
  address private oracleFeed;
  address private ethPriceFeed = address(0x18);
  address private deployer = address(0x3);

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);
    oracleFeed = address(new OracleFeeds());

    // Deploy and initialize BondToken
    adapter = BalancerOracleAdapter(Utils.deploy(
      address(new BalancerOracleAdapter()),
      abi.encodeCall(BalancerOracleAdapter.initialize, (poolAddr, 18, oracleFeed, deployer))
    ));

    OracleFeeds(oracleFeed).setPriceFeed(adapter.ETH(), adapter.USD(), ethPriceFeed, 1 days);
    OracleFeeds(oracleFeed).setPriceFeed(address(0x5), adapter.ETH(), ethPriceFeed, 1 days);
    OracleFeeds(oracleFeed).setPriceFeed(address(0x6), adapter.ETH(), ethPriceFeed, 1 days);
    OracleFeeds(oracleFeed).setPriceFeed(address(0x5), adapter.USD(), ethPriceFeed, 1 days);
    OracleFeeds(oracleFeed).setPriceFeed(address(0x6), adapter.USD(), ethPriceFeed, 1 days);
    vm.stopPrank();
  }

  function testOwner() public view {
    assertEq(adapter.owner(), deployer);
  }

  function testLatestRoundData() public {
    // Mock required external calls
    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getVault.selector),
      abi.encode(address(0x4))
    );

    vm.mockCall(
      address(0x4),
      abi.encodeWithSelector(IVault.manageUserBalance.selector),
      bytes("")
    );

    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getPoolId.selector),
      abi.encode(bytes32(0))
    );

    // Mock getPoolTokens call
    IERC20[] memory tokens = new IERC20[](2);
    tokens[0] = IERC20(address(0x5));
    tokens[1] = IERC20(address(0x6));
    vm.mockCall(
      address(0x4),
      abi.encodeWithSelector(IVault.getPoolTokens.selector),
      abi.encode(tokens, new uint256[](2), block.timestamp)
    );

    // Mock getNormalizedWeights call
    uint256[] memory weights = new uint256[](2);
    weights[0] = 500000000000000000; // 0.5
    weights[1] = 500000000000000000; // 0.5
    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getNormalizedWeights.selector),
      abi.encode(weights)
    );

    // Mock latestRoundData call for oracle feed
    vm.mockCall(
      ethPriceFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(uint80(0), int256(100 ether), uint256(0), block.timestamp, uint80(0))
    );

    // Mock decimals call
    vm.mockCall(
      ethPriceFeed,
      abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
      abi.encode(uint8(18))
    );

    // Mock getInvariant and getActualSupply
    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getInvariant.selector),
      abi.encode(1000000000000000000)
    );

    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getActualSupply.selector),
      abi.encode(1000000000000000000)
    );

    // Get latest round data
    (,int256 answer,,,) = adapter.latestRoundData();
    assertEq(answer, 199999999999995999641);
  }

  function testLatestRoundDataRealData() public {
    // Mock required external calls
    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getVault.selector),
      abi.encode(address(0x4))
    );

    vm.mockCall(
      address(0x4),
      abi.encodeWithSelector(IVault.manageUserBalance.selector),
      bytes("")
    );

    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getPoolId.selector),
      abi.encode(bytes32(0))
    );

    // Mock getPoolTokens call
    IERC20[] memory tokens = new IERC20[](2);
    tokens[0] = IERC20(address(0x5));
    tokens[1] = IERC20(address(0x6));
    vm.mockCall(
      address(0x4),
      abi.encodeWithSelector(IVault.getPoolTokens.selector),
      abi.encode(tokens, new uint256[](2), block.timestamp)
    );

    // Mock getNormalizedWeights call
    uint256[] memory weights = new uint256[](2);
    weights[0] = 800000000000000000; // 0.8
    weights[1] = 200000000000000000; // 0.2
    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getNormalizedWeights.selector),
      abi.encode(weights)
    );

    // Mock latestRoundData call for oracle feed
    vm.mockCall(
      ethPriceFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(uint80(0), int256(348539000000), uint256(0), block.timestamp, uint80(0))
    );

    // Mock decimals call
    vm.mockCall(
      ethPriceFeed,
      abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
      abi.encode(uint8(18))
    );

    // Mock getInvariant and getActualSupply
    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getInvariant.selector),
      abi.encode(1000000000000000000)
    );

    vm.mockCall(
      poolAddr,
      abi.encodeWithSelector(IBalancerV2WeightedPool.getActualSupply.selector),
      abi.encode(1000000000000000000)
    );

    // Get latest round data
    (,int256 answer,,,) = adapter.latestRoundData();
    assertEq(answer, 574874959640);
  }

  function testCalculateFairUintPrice() public pure {
    uint256[] memory prices = new uint256[](2);
    prices[0] = 3009270000000000000000;
    prices[1] = 151850000000000000000;
    uint256[] memory weights = new uint256[](2);
    weights[0] = 200000000000000000;
    weights[1] = 800000000000000000;
    uint256 invariant = 376668723340106111392035;
    uint256 totalBPTSupply = 747200595087878845066224;

    uint256 price = _calculateFairUintPrice(prices, weights, invariant, totalBPTSupply);
    assertTrue(price > 0);
  }
}
