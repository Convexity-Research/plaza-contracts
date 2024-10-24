// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/BalancerOracleAdapter.sol";
import {Decimals} from "../src/lib/Decimals.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {FixedPoint} from "../src/lib/balancer/FixedPoint.sol";


contract BalancerOracleAdapterTest is Test, BalancerOracleAdapter {
  using Decimals for uint256;
  using FixedPoint for uint256;
  BalancerOracleAdapter private adapter;
  ERC1967Proxy private proxy;
  address private poolAddr = address(0x1);
  address private oracleFeed = address(0x2);
  address private deployer = address(0x3);
  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    // vm.startPrank(deployer);
    // // Deploy and initialize BondToken
    // BalancerOracleAdapter implementation = BalancerOracleAdapter(oracleFeeds);

    // // Deploy the proxy and initialize the contract through the proxy
    // proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(implementation.initialize, (poolAddress, 18, oracleFeeds)));

    // // Attach the BondToken interface to the deployed proxy
    // adapter = BalancerOracleAdapter(address(proxy));
    // vm.stopPrank();
  }

  function testPrices() public {
    uint256[] memory prices = new uint256[](2);
    prices[0] = 3009270000000000000000;
    prices[1] = 151850000000000000000;
    uint256[] memory weights = new uint256[](2);
    weights[0] = 200000000000000000;
    weights[1] = 800000000000000000;
    uint256 invariant = 376668723340106111392035;
    uint256 totalBPTSupply = 747200595087878845066224;

    console.log(_calculateFairUintPrice(prices, weights, invariant, totalBPTSupply));
  }
}