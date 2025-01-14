// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Utils} from "../src/lib/Utils.sol";
import {Decimals} from "../src/lib/Decimals.sol";
import {BondOracleAdapter} from "../src/BondOracleAdapter.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ICLPool} from "../src/lib/concentrated-liquidity/ICLPool.sol";
import {ICLFactory} from "../src/lib/concentrated-liquidity/ICLFactory.sol";
import {ICLPoolDerivedState} from "../src/lib/concentrated-liquidity/ICLPoolDerivedState.sol";

contract BondOracleAdapterTest is Test {
  using Decimals for uint256;
  
  BondOracleAdapter private adapter;
  address private bondToken = address(0x1);
  address private liquidityToken = address(0x2);
  address private dexFactory = address(0x3);
  address private dexPool = address(0x4);
  address private deployer = address(0x5);
  uint32 private twapInterval = 1800; // 30 minutes

  function setUp() public {
    vm.startPrank(deployer);

    // Mock IERC20 decimals calls
    vm.mockCall(
      bondToken,
      abi.encodeWithSelector(ERC20.decimals.selector),
      abi.encode(uint8(18))
    );

    // Mock IERC20 symbol calls for description
    vm.mockCall(
      bondToken,
      abi.encodeWithSelector(ERC20.symbol.selector),
      abi.encode("BOND")
    );
    vm.mockCall(
      liquidityToken,
      abi.encodeWithSelector(ERC20.symbol.selector),
      abi.encode("ETH")
    );

    // Mock factory getPool call
    vm.mockCall(
      dexFactory,
      abi.encodeWithSelector(ICLFactory.getPool.selector, bondToken, liquidityToken, 1),
      abi.encode(dexPool)
    );

    // Mock factory tickSpacingToFee call
    vm.mockCall(
      dexFactory,
      abi.encodeWithSignature("tickSpacingToFee(int24)", 1),
      abi.encode(uint24(100))
    );

    // Deploy and initialize BondOracleAdapter
    adapter = BondOracleAdapter(Utils.deploy(
      address(new BondOracleAdapter()),
      abi.encodeCall(BondOracleAdapter.initialize, (
        bondToken,
        liquidityToken,
        twapInterval,
        dexFactory,
        deployer
      ))
    ));

    vm.stopPrank();
  }

  function testLatestRoundData() public {
    // Mock observe call on pool
    int56[] memory tickCumulatives = new int56[](2);
    tickCumulatives[0] = 100000; // tick at t-30min
    tickCumulatives[1] = 200000; // tick at t-0
    uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
    
    vm.mockCall(
      dexPool,
      abi.encodeWithSelector(ICLPoolDerivedState.observe.selector),
      abi.encode(tickCumulatives, secondsPerLiquidityCumulativeX128s)
    );

    // Get latest round data
    (,int256 answer,,,) = adapter.latestRoundData();

    // Verify the returned values
    assertEq(answer, 79665096027561846390902814542);
    console.log(answer);
  }

  function testDescription() public view {
    string memory desc = adapter.description();
    assertEq(desc, "BOND/ETH Oracle Price");
  }

  function testVersion() public view {
    assertEq(adapter.version(), 1);
  }

  function testDecimals() public view {
    assertEq(adapter.decimals(), 18);
  }
}
