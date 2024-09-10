// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Distributor} from "../src/Distributor.sol";
import "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {BondToken} from "../src/BondToken.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";
import {TokenDeployer} from "../src/utils/TokenDeployer.sol";

contract PoolTest is Test {
  PoolFactory private poolFactory;
  PoolFactory.PoolParams private params;

  Distributor private distributor;

  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private user = address(0x4);
  address private user2 = address(0x5);

  struct CalcTestCase {
      Pool.TokenType assetType;
      uint256 inAmount;
      uint256 ethPrice;
      uint256 TotalUnderlyingAssets;
      uint256 DebtAssets;
      uint256 LeverageAssets;
      uint256 expectedCreate;
      uint256 expectedRedeem;
      uint256 expectedSwap;
  }

  CalcTestCase[] public calcTestCases;
  CalcTestCase[] public calcTestCases2;

  address private constant ETH_PRICE_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
  uint256 private constant CHAINLINK_DECIMAL_PRECISION = 10**8;
  uint8 private constant CHAINLINK_DECIMAL = 8;

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);

    address tokenDeployer = address(new TokenDeployer());
    distributor = Distributor(Utils.deploy(address(new Distributor()), abi.encodeCall(Distributor.initialize, (governance))));
    poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(PoolFactory.initialize, (governance,tokenDeployer, address(distributor)))));

    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH"));
    params.sharesPerToken = 50 * 10 ** 18;
    params.distributionPeriod = 0;
    params.couponToken = address(new Token("USDC", "USDC"));

    // Deploy the mock price feed
    MockPriceFeed mockPriceFeed = new MockPriceFeed();

    // Use vm.etch to deploy the mock contract at the specific address
    bytes memory bytecode = address(mockPriceFeed).code;
    vm.etch(ETH_PRICE_FEED, bytecode);

    // Set oracle price
    mockPriceFeed = MockPriceFeed(ETH_PRICE_FEED);
    mockPriceFeed.setMockPrice(3000 * int256(CHAINLINK_DECIMAL_PRECISION), uint8(CHAINLINK_DECIMAL));
    
    vm.stopPrank();

    vm.startPrank(governance);
    distributor.grantRole(distributor.POOL_FACTORY_ROLE(), address(poolFactory));
    vm.stopPrank();

    initializeTestCases();
    initializeTestCasesFixedEth();
  }

  function initializeTestCases() public {
    // Debt - Below Threshold
    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1000,
        ethPrice: 3000,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 31250,
        expectedRedeem: 32,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 80000,
        expectedRedeem: 50,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 46875,
        expectedRedeem: 48,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 500,
        ethPrice: 3500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 17500,
        expectedRedeem: 14,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 93750,
        expectedRedeem: 96,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 750,
        ethPrice: 4500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 33750,
        expectedRedeem: 16,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 60000,
        expectedRedeem: 24,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 800,
        ethPrice: 2600,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 25000,
        expectedRedeem: 25,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2200,
        ethPrice: 3300,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 72600,
        expectedRedeem: 66,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3500,
        ethPrice: 4200,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 147000,
        expectedRedeem: 83,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2900,
        ethPrice: 2700,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 90625,
        expectedRedeem: 92,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1800,
        ethPrice: 3800,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 68400,
        expectedRedeem: 47,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 100,
        ethPrice: 8000,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 8000,
        expectedRedeem: 1,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 600,
        ethPrice: 3200,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 19200,
        expectedRedeem: 18,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1600,
        ethPrice: 2900,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 50000,
        expectedRedeem: 51,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 140625,
        expectedRedeem: 144,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 300,
        ethPrice: 7000,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 21000,
        expectedRedeem: 4,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 5000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 156250,
        expectedRedeem: 160,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 400,
        ethPrice: 6500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 26000,
        expectedRedeem: 6,
        expectedSwap: 0
    }));

    // Debt - Above Threshold
    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1000,
        ethPrice: 3000,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 30000,
        expectedRedeem: 33,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 80000,
        expectedRedeem: 50,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 37500,
        expectedRedeem: 60,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 500,
        ethPrice: 3500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 17500,
        expectedRedeem: 14,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 45000,
        expectedRedeem: 200,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 750,
        ethPrice: 4500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 33750,
        expectedRedeem: 16,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 60000,
        expectedRedeem: 24,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 800,
        ethPrice: 2600,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 20800,
        expectedRedeem: 30,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2200,
        ethPrice: 3300,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 72600,
        expectedRedeem: 66,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3500,
        ethPrice: 4200,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 147000,
        expectedRedeem: 83,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2900,
        ethPrice: 2700,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 78300,
        expectedRedeem: 107,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1800,
        ethPrice: 3800,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 68400,
        expectedRedeem: 47,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 100,
        ethPrice: 8000,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 8000,
        expectedRedeem: 1,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 600,
        ethPrice: 3200,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 19200,
        expectedRedeem: 18,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1600,
        ethPrice: 2900,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 46400,
        expectedRedeem: 55,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 112500,
        expectedRedeem: 180,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 300,
        ethPrice: 7000,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 21000,
        expectedRedeem: 4,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 5000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 60000,
        expectedRedeem: 416,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 400,
        ethPrice: 6500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 26000,
        expectedRedeem: 6,
        expectedSwap: 0
    }));

    // Leverage - Below Threshold
    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1000,
        ethPrice: 3000,
        TotalUnderlyingAssets: 35000,
        DebtAssets: 2500000,
        LeverageAssets: 1320000,
        expectedCreate: 188571,
        expectedRedeem: 5,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 45000,
        DebtAssets: 2800000,
        LeverageAssets: 1600000,
        expectedCreate: 355555, // @todo: solidity 355555 - go 355556
        expectedRedeem: 11,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 50000,
        DebtAssets: 3200000,
        LeverageAssets: 1700000,
        expectedCreate: 255000,
        expectedRedeem: 8,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 500,
        ethPrice: 3500,
        TotalUnderlyingAssets: 32000,
        DebtAssets: 2100000,
        LeverageAssets: 1200000,
        expectedCreate: 93750,
        expectedRedeem: 2,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 68000,
        DebtAssets: 3500000,
        LeverageAssets: 1450000,
        expectedCreate: 319852, // @todo: solidity 319852 - go 319853
        expectedRedeem: 28,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 750,
        ethPrice: 4500,
        TotalUnderlyingAssets: 42000,
        DebtAssets: 2700000,
        LeverageAssets: 1800000,
        expectedCreate: 160714,
        expectedRedeem: 3,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 30000,
        DebtAssets: 2900000,
        LeverageAssets: 1350000,
        expectedCreate: 270000,
        expectedRedeem: 5,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 800,
        ethPrice: 2600,
        TotalUnderlyingAssets: 40000,
        DebtAssets: 3100000,
        LeverageAssets: 1500000,
        expectedCreate: 150000,
        expectedRedeem: 4,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2200,
        ethPrice: 3300,
        TotalUnderlyingAssets: 53000,
        DebtAssets: 2400000,
        LeverageAssets: 1250000,
        expectedCreate: 259433, // @todo: solidity 259433 - go 259434
        expectedRedeem: 18,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3500,
        ethPrice: 4200,
        TotalUnderlyingAssets: 48000,
        DebtAssets: 2700000,
        LeverageAssets: 1650000,
        expectedCreate: 601562,
        expectedRedeem: 20,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2900,
        ethPrice: 2700,
        TotalUnderlyingAssets: 45000,
        DebtAssets: 2900000,
        LeverageAssets: 1600000,
        expectedCreate: 515555, // @todo: solidity 515555 - go 515556
        expectedRedeem: 16,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1800,
        ethPrice: 3800,
        TotalUnderlyingAssets: 42000,
        DebtAssets: 3300000,
        LeverageAssets: 1400000,
        expectedCreate: 300000,
        expectedRedeem: 10,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 100,
        ethPrice: 8000,
        TotalUnderlyingAssets: 37000,
        DebtAssets: 3500000,
        LeverageAssets: 1500000,
        expectedCreate: 20270,
        expectedRedeem: 0,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 600,
        ethPrice: 3200,
        TotalUnderlyingAssets: 30000,
        DebtAssets: 2200000,
        LeverageAssets: 1000000,
        expectedCreate: 100000,
        expectedRedeem: 3,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1600,
        ethPrice: 2900,
        TotalUnderlyingAssets: 34000,
        DebtAssets: 3100000,
        LeverageAssets: 1800000,
        expectedCreate: 423529,
        expectedRedeem: 6,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 68000,
        DebtAssets: 2700000,
        LeverageAssets: 1200000,
        expectedCreate: 397058, // @todo: solidity 397058 - go 397059
        expectedRedeem: 50,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 300,
        ethPrice: 7000,
        TotalUnderlyingAssets: 30000,
        DebtAssets: 2900000,
        LeverageAssets: 1700000,
        expectedCreate: 85000,
        expectedRedeem: 1,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 58000,
        DebtAssets: 2600000,
        LeverageAssets: 1100000,
        expectedCreate: 474137, // @todo: solidity 474137 - go 474138
        expectedRedeem: 52,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 400,
        ethPrice: 6500,
        TotalUnderlyingAssets: 33000,
        DebtAssets: 2300000,
        LeverageAssets: 1400000,
        expectedCreate: 84848,
        expectedRedeem: 1,
        expectedSwap: 0
    }));

    // Leverage - Above Threshold
    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 3000,
        TotalUnderlyingAssets: 6000000,
        DebtAssets: 900000,
        LeverageAssets: 1400000,
        expectedCreate: 351, // @todo: solidity 351 - go 352
        expectedRedeem: 6396,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 7500000,
        DebtAssets: 900000,
        LeverageAssets: 1600000,
        expectedCreate: 427, // @todo: solidity 427 - go 428
        expectedRedeem: 9346,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3000,
        ethPrice: 2500,
        TotalUnderlyingAssets: 8000000,
        DebtAssets: 950000,
        LeverageAssets: 1700000,
        expectedCreate: 640, // @todo: solidity 640 - go 641
        expectedRedeem: 14049,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1000,
        ethPrice: 3500,
        TotalUnderlyingAssets: 9000000,
        DebtAssets: 1200000,
        LeverageAssets: 1200000,
        expectedCreate: 133, // @todo solidity 133 - go 134
        expectedRedeem: 7471,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2500,
        ethPrice: 4500,
        TotalUnderlyingAssets: 9500000,
        DebtAssets: 1300000,
        LeverageAssets: 1500000,
        expectedCreate: 395, // @todo solidity 395 - go 396
        expectedRedeem: 15785,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 10000000,
        DebtAssets: 1250000,
        LeverageAssets: 1450000,
        expectedCreate: 174,
        expectedRedeem: 8255,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1800,
        ethPrice: 5500,
        TotalUnderlyingAssets: 10500000,
        DebtAssets: 1350000,
        LeverageAssets: 1550000,
        expectedCreate: 266,
        expectedRedeem: 12164,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1600,
        ethPrice: 2700,
        TotalUnderlyingAssets: 7000000,
        DebtAssets: 850000,
        LeverageAssets: 1300000,
        expectedCreate: 298,
        expectedRedeem: 8576,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3000,
        ethPrice: 3400,
        TotalUnderlyingAssets: 8000000,
        DebtAssets: 950000,
        LeverageAssets: 1700000,
        expectedCreate: 639, // @todo: solidity 639 - go 640
        expectedRedeem: 14068,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5000,
        ethPrice: 150000,
        TotalUnderlyingAssets: 5000000000000,
        DebtAssets: 3000000000000,
        LeverageAssets: 1000000000000,
        expectedCreate: 1000,
        expectedRedeem: 24990,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1000,
        ethPrice: 2500,
        TotalUnderlyingAssets: 8000000,
        DebtAssets: 1000000,
        LeverageAssets: 1800000,
        expectedCreate: 226,
        expectedRedeem: 4422,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 4800,
        TotalUnderlyingAssets: 750000000000,
        DebtAssets: 300000000000,
        LeverageAssets: 50000000000,
        expectedCreate: 215,
        expectedRedeem: 47600,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 7000,
        ethPrice: 6000,
        TotalUnderlyingAssets: 3000000,
        DebtAssets: 1200000,
        LeverageAssets: 2000000,
        expectedCreate: 4697, // @todo: solidity 4697 - go 4698
        expectedRedeem: 10430,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 8500,
        ethPrice: 5000,
        TotalUnderlyingAssets: 20000000000,
        DebtAssets: 8000000000,
        LeverageAssets: 3000000000,
        expectedCreate: 1285,
        expectedRedeem: 56212,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2400,
        ethPrice: 7500,
        TotalUnderlyingAssets: 100000000000,
        DebtAssets: 30000000000,
        LeverageAssets: 5000000000,
        expectedCreate: 120,
        expectedRedeem: 47808,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4000,
        ethPrice: 2200,
        TotalUnderlyingAssets: 100000000,
        DebtAssets: 25000000,
        LeverageAssets: 5000000,
        expectedCreate: 202,
        expectedRedeem: 79090,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3700,
        ethPrice: 4500,
        TotalUnderlyingAssets: 1500000000000,
        DebtAssets: 400000000000,
        LeverageAssets: 200000000000,
        expectedCreate: 496,
        expectedRedeem: 27585,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 3000,
        TotalUnderlyingAssets: 2500000,
        DebtAssets: 1000000,
        LeverageAssets: 1500000,
        expectedCreate: 912,
        expectedRedeem: 2466,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2900,
        ethPrice: 12000,
        TotalUnderlyingAssets: 10000000000000,
        DebtAssets: 4000000000000,
        LeverageAssets: 2000000000000,
        expectedCreate: 581, // @todo: solidity 581 - go 582
        expectedRedeem: 14451,
        expectedSwap: 0
    }));

    // Random Values but Leverage Level = 1.2
    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5000,
        ethPrice: 7200,
        TotalUnderlyingAssets: 2880000000,
        DebtAssets: 172800000000,
        LeverageAssets: 1400000000,
        expectedCreate: 12152, // @todo: solidity 12152 - go 12153
        expectedRedeem: 2057,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1000,
        ethPrice: 3600,
        TotalUnderlyingAssets: 7200000,
        DebtAssets: 216000000,
        LeverageAssets: 1800000,
        expectedCreate: 37500,
        expectedRedeem: 26,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 4800,
        TotalUnderlyingAssets: 960000000,
        DebtAssets: 38400000000,
        LeverageAssets: 500000000,
        expectedCreate: 8333,
        expectedRedeem: 1228,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 7000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 144000000,
        DebtAssets: 1440000000,
        LeverageAssets: 2000000,
        expectedCreate: 87500,
        expectedRedeem: 560,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 8500,
        ethPrice: 9000,
        TotalUnderlyingAssets: 5400000000,
        DebtAssets: 405000000000,
        LeverageAssets: 3000000000,
        expectedCreate: 23611,
        expectedRedeem: 3060,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2400,
        ethPrice: 6000,
        TotalUnderlyingAssets: 360000000,
        DebtAssets: 18000000000,
        LeverageAssets: 500000000,
        expectedCreate: 150000,
        expectedRedeem: 38,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4000,
        ethPrice: 1800,
        TotalUnderlyingAssets: 432000000,
        DebtAssets: 6480000000,
        LeverageAssets: 5000000,
        expectedCreate: 231,
        expectedRedeem: 69120,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3700,
        ethPrice: 1500,
        TotalUnderlyingAssets: 54000000,
        DebtAssets: 675000000,
        LeverageAssets: 200000000,
        expectedCreate: 57812,
        expectedRedeem: 246,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 4800,
        TotalUnderlyingAssets: 720000000,
        DebtAssets: 28800000000,
        LeverageAssets: 500000000,
        expectedCreate: 5208,
        expectedRedeem: 432,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2900,
        ethPrice: 3000,
        TotalUnderlyingAssets: 900000000,
        DebtAssets: 22500000000,
        LeverageAssets: 4000000,
        expectedCreate: 90625,
        expectedRedeem: 92,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1200,
        ethPrice: 6000,
        TotalUnderlyingAssets: 1800000000,
        DebtAssets: 90000000000,
        LeverageAssets: 500000000,
        expectedCreate: 1666, // @todo: solidity 1666 - go 1667
        expectedRedeem: 864,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4500,
        ethPrice: 15000,
        TotalUnderlyingAssets: 18000000000,
        DebtAssets: 2250000000000,
        LeverageAssets: 1500000000,
        expectedCreate: 703125,
        expectedRedeem: 28,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5200,
        ethPrice: 2400,
        TotalUnderlyingAssets: 288000000,
        DebtAssets: 5760000000,
        LeverageAssets: 500000000,
        expectedCreate: 45138, // @todo: solidity 45138 - go 45139
        expectedRedeem: 599,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3000,
        ethPrice: 9000,
        TotalUnderlyingAssets: 5400000000,
        DebtAssets: 405000000000,
        LeverageAssets: 250000000,
        expectedCreate: 281250,
        expectedRedeem: 32,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 6000,
        ethPrice: 7200,
        TotalUnderlyingAssets: 4320000000,
        DebtAssets: 259200000000,
        LeverageAssets: 3000000000,
        expectedCreate: 20833,
        expectedRedeem: 1728,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 7000,
        ethPrice: 4800,
        TotalUnderlyingAssets: 1440000000,
        DebtAssets: 57600000000,
        LeverageAssets: 600000000,
        expectedCreate: 350000,
        expectedRedeem: 140,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 8000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 900000000,
        DebtAssets: 11250000000,
        LeverageAssets: 300000000,
        expectedCreate: 13333,
        expectedRedeem: 4800,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2500,
        ethPrice: 1200,
        TotalUnderlyingAssets: 36000000,
        DebtAssets: 360000000,
        LeverageAssets: 300000000,
        expectedCreate: 31250,
        expectedRedeem: 208,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 3600,
        TotalUnderlyingAssets: 108000000,
        DebtAssets: 3240000000,
        LeverageAssets: 5000000,
        expectedCreate: 740, // @todo: solidity 740 - go 741
        expectedRedeem: 13824,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4700,
        ethPrice: 6000,
        TotalUnderlyingAssets: 720000000,
        DebtAssets: 43200000000,
        LeverageAssets: 300000000,
        expectedCreate: 352500,
        expectedRedeem: 62,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 2400,
        TotalUnderlyingAssets: 288000000,
        DebtAssets: 5760000000,
        LeverageAssets: 2000000,
        expectedCreate: 52,
        expectedRedeem: 43200,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 5500,
        ethPrice: 15000,
        TotalUnderlyingAssets: 18000000000,
        DebtAssets: 2250000000000,
        LeverageAssets: 1500000000,
        expectedCreate: 859375,
        expectedRedeem: 35,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2700,
        ethPrice: 7200,
        TotalUnderlyingAssets: 432000000,
        DebtAssets: 25920000000,
        LeverageAssets: 100000000,
        expectedCreate: 3125,
        expectedRedeem: 2332,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4200,
        ethPrice: 9000,
        TotalUnderlyingAssets: 5400000000,
        DebtAssets: 405000000000,
        LeverageAssets: 200000000,
        expectedCreate: 393750,
        expectedRedeem: 44,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 4800,
        TotalUnderlyingAssets: 720000000,
        DebtAssets: 28800000000,
        LeverageAssets: 300000000,
        expectedCreate: 6666, // @todo: solidity 6666 - go 6667
        expectedRedeem: 1536,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 6800,
        ethPrice: 12000,
        TotalUnderlyingAssets: 14400000000,
        DebtAssets: 1440000000000,
        LeverageAssets: 500000000,
        expectedCreate: 850000,
        expectedRedeem: 54,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4500,
        ethPrice: 6000,
        TotalUnderlyingAssets: 720000000,
        DebtAssets: 43200000000,
        LeverageAssets: 300000000,
        expectedCreate: 9375,
        expectedRedeem: 2160,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 7800,
        ethPrice: 15000,
        TotalUnderlyingAssets: 18000000000,
        DebtAssets: 2250000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 1218750,
        expectedRedeem: 49,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5100,
        ethPrice: 3600,
        TotalUnderlyingAssets: 108000000,
        DebtAssets: 3240000000,
        LeverageAssets: 100000000,
        expectedCreate: 23611,
        expectedRedeem: 1101,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3100,
        ethPrice: 1200,
        TotalUnderlyingAssets: 288000000,
        DebtAssets: 2880000000,
        LeverageAssets: 500000000,
        expectedCreate: 38750,
        expectedRedeem: 248,
        expectedSwap: 0
    }));
  }

  // eth comes from Pool constant (3000)
  function initializeTestCasesFixedEth() public {
    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1000,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 31250,
        expectedRedeem: 32,
        expectedSwap: 160
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1250,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 37500,
        expectedRedeem: 41,
        expectedSwap: 0
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 500,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 32000,
        DebtAssets: 2100000,
        LeverageAssets: 1200000,
        expectedCreate: 93750,
        expectedRedeem: 2,
        expectedSwap: 164
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1600,
        ethPrice: 0,
        TotalUnderlyingAssets: 7000000,
        DebtAssets: 850000,
        LeverageAssets: 1300000,
        expectedCreate: 298,
        expectedRedeem: 8580,
        expectedSwap: 257400
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 960000000,
        DebtAssets: 38400000000,
        LeverageAssets: 500000000,
        expectedCreate: 8333,
        expectedRedeem: 1228,
        expectedSwap: 61400
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 7000,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 144000000,
        DebtAssets: 1440000000,
        LeverageAssets: 2000000,
        expectedCreate: 210000,
        expectedRedeem: 233,
        expectedSwap: 4
    }));
  }

  function testGetCreateAmount() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      Pool _pool = Pool(poolFactory.CreatePool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets));

      uint256 amount = _pool.getCreateAmount(
        calcTestCases[i].assetType, 
        calcTestCases[i].inAmount,
        calcTestCases[i].DebtAssets,
        calcTestCases[i].LeverageAssets,
        calcTestCases[i].TotalUnderlyingAssets,
        calcTestCases[i].ethPrice * CHAINLINK_DECIMAL_PRECISION,
        CHAINLINK_DECIMAL
      );
      assertEq(amount, calcTestCases[i].expectedCreate);

      // I can't set the ETH price will wait until we have oracles so I can mock
      // amount = _pool.simulateCreate(calcTestCases[i].assetType, calcTestCases[i].inAmount);
      // assertEq(amount, calcTestCases[i].expectedCreate);

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testGetCreateAmountZeroDebtSupply() public {
    Pool pool = new Pool();
    vm.expectRevert(Pool.ZeroDebtSupply.selector);
    pool.getCreateAmount(Pool.TokenType.DEBT, 10, 0, 100, 100, 3000, CHAINLINK_DECIMAL);
  }

  function testGetCreateAmountZeroLeverageSupply() public {
    Pool pool = new Pool();
    vm.expectRevert(Pool.ZeroLeverageSupply.selector);
    pool.getCreateAmount(Pool.TokenType.LEVERAGE, 10, 100000, 0, 10000, 30000000 * CHAINLINK_DECIMAL_PRECISION, CHAINLINK_DECIMAL);
  }

  function testCreate() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases2.length; i++) {
      if (calcTestCases2[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases2[i].TotalUnderlyingAssets + calcTestCases2[i].inAmount);
      rToken.approve(address(poolFactory), calcTestCases2[i].TotalUnderlyingAssets);

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.CreatePool(params, calcTestCases2[i].TotalUnderlyingAssets, calcTestCases2[i].DebtAssets, calcTestCases2[i].LeverageAssets));
      rToken.approve(address(_pool), calcTestCases2[i].inAmount);

      uint256 startBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 startReserveBalance = rToken.balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases2[i].assetType, calcTestCases2[i].inAmount, 0);
      assertEq(amount, calcTestCases2[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 endReserveBalance = rToken.balanceOf(governance);
      assertEq(calcTestCases2[i].inAmount, startReserveBalance-endReserveBalance);

      if (calcTestCases2[i].assetType == Pool.TokenType.DEBT) {
        assertEq(amount, endBondBalance-startBondBalance);
        assertEq(0, endLevBalance-startLevBalance);
      } else {
        assertEq(0, endBondBalance-startBondBalance);
        assertEq(amount, endLevBalance-startLevBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testCreateOnBehalfOf() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases2.length; i++) {
      if (calcTestCases2[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases2[i].TotalUnderlyingAssets + calcTestCases2[i].inAmount);
      rToken.approve(address(poolFactory), calcTestCases2[i].TotalUnderlyingAssets);

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.CreatePool(params, calcTestCases2[i].TotalUnderlyingAssets, calcTestCases2[i].DebtAssets, calcTestCases2[i].LeverageAssets));
      rToken.approve(address(_pool), calcTestCases2[i].inAmount);

      uint256 startBondBalance = BondToken(_pool.dToken()).balanceOf(user2);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(user2);
      uint256 startReserveBalance = rToken.balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases2[i].assetType, calcTestCases2[i].inAmount, 0, user2);
      assertEq(amount, calcTestCases2[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.dToken()).balanceOf(user2);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(user2);
      uint256 endReserveBalance = rToken.balanceOf(governance);
      assertEq(calcTestCases2[i].inAmount, startReserveBalance-endReserveBalance);

      if (calcTestCases2[i].assetType == Pool.TokenType.DEBT) {
        assertEq(amount, endBondBalance-startBondBalance);
        assertEq(0, endLevBalance-startLevBalance);
      } else {
        assertEq(0, endBondBalance-startBondBalance);
        assertEq(amount, endLevBalance-startLevBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testCreateMinAmountExactSuccess() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));
    rToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    uint256 amount = _pool.create(Pool.TokenType.DEBT, 1000, 30000);
    assertEq(amount, 30000);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testCreateMinAmountError() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));
    rToken.approve(address(_pool), 1000);

    // Call create and expect error
    vm.expectRevert(Pool.MinAmount.selector);
    _pool.create(Pool.TokenType.DEBT, 1000, 30001);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testGetRedeemAmount() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      Pool _pool = Pool(poolFactory.CreatePool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets));

      uint256 amount = _pool.getRedeemAmount(
        calcTestCases[i].assetType, 
        calcTestCases[i].inAmount, 
        calcTestCases[i].DebtAssets, 
        calcTestCases[i].LeverageAssets, 
        calcTestCases[i].TotalUnderlyingAssets, 
        calcTestCases[i].ethPrice * CHAINLINK_DECIMAL_PRECISION,
        CHAINLINK_DECIMAL
      );
      assertEq(amount, calcTestCases[i].expectedRedeem);

      // I can't set the ETH price will wait until we have oracles so I can mock
      // amount = _pool.simulateRedeem(calcTestCases[i].assetType, calcTestCases[i].inAmount);
      // assertEq(amount, calcTestCases[i].expectedRedeem);

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testRedeem() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases2.length; i++) {
      if (calcTestCases2[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases2[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases2[i].TotalUnderlyingAssets);

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.CreatePool(params, calcTestCases2[i].TotalUnderlyingAssets, calcTestCases2[i].DebtAssets, calcTestCases2[i].LeverageAssets));

      uint256 startBalance = rToken.balanceOf(governance);
      uint256 startBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.redeem(calcTestCases2[i].assetType, calcTestCases2[i].inAmount, 0);
      assertEq(amount, calcTestCases2[i].expectedRedeem);

      uint256 endBalance = rToken.balanceOf(governance);
      uint256 endBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      assertEq(amount, endBalance-startBalance);

      if (calcTestCases2[i].assetType == Pool.TokenType.DEBT) {
        assertEq(calcTestCases2[i].inAmount, startBondBalance-endBondBalance);
        assertEq(0, endLevBalance-startLevBalance);
      } else {
        assertEq(0, endBondBalance-startBondBalance);
        assertEq(calcTestCases2[i].inAmount, startLevBalance-endLevBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testRedeemOnBehalfOf() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases2.length; i++) {
      if (calcTestCases2[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases2[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases2[i].TotalUnderlyingAssets);

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.CreatePool(params, calcTestCases2[i].TotalUnderlyingAssets, calcTestCases2[i].DebtAssets, calcTestCases2[i].LeverageAssets));

      uint256 startBalance = rToken.balanceOf(user2);
      uint256 startBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.redeem(calcTestCases2[i].assetType, calcTestCases2[i].inAmount, 0, user2);
      assertEq(amount, calcTestCases2[i].expectedRedeem);

      uint256 endBalance = rToken.balanceOf(user2);
      uint256 endBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      assertEq(amount, endBalance-startBalance);

      if (calcTestCases2[i].assetType == Pool.TokenType.DEBT) {
        assertEq(calcTestCases2[i].inAmount, startBondBalance-endBondBalance);
        assertEq(0, endLevBalance-startLevBalance);
      } else {
        assertEq(0, endBondBalance-startBondBalance);
        assertEq(calcTestCases2[i].inAmount, startLevBalance-endLevBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(user2, rToken.balanceOf(user2));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testRedeemMinAmountExactSuccess() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));
    rToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    uint256 amount = _pool.redeem(Pool.TokenType.DEBT, 1000, 33);
    assertEq(amount, 33);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testRedeemMinAmountError() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));
    rToken.approve(address(_pool), 1000);

    // Call create and expect error
    vm.expectRevert(Pool.MinAmount.selector);
    _pool.redeem(Pool.TokenType.DEBT, 1000, 34);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testSwap() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases2.length; i++) {
      if (calcTestCases2[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases2[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases2[i].TotalUnderlyingAssets);

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.CreatePool(params, calcTestCases2[i].TotalUnderlyingAssets, calcTestCases2[i].DebtAssets, calcTestCases2[i].LeverageAssets));

      uint256 startBalance = rToken.balanceOf(governance);
      uint256 startBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.swap(calcTestCases2[i].assetType, calcTestCases2[i].inAmount, 0);
      assertEq(amount, calcTestCases2[i].expectedSwap);

      uint256 endBalance = rToken.balanceOf(governance);
      uint256 endBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      assertEq(0, startBalance-endBalance);

      if (calcTestCases2[i].assetType == Pool.TokenType.DEBT) {
        assertEq(_pool.dToken().totalSupply(), calcTestCases2[i].DebtAssets - calcTestCases2[i].inAmount);
        assertEq(_pool.lToken().totalSupply(), calcTestCases2[i].LeverageAssets + amount);
        assertEq(calcTestCases2[i].inAmount, startBondBalance-endBondBalance);
        assertEq(amount, endLevBalance-startLevBalance);
      } else {
        assertEq(_pool.dToken().totalSupply(), calcTestCases2[i].DebtAssets + amount);
        assertEq(_pool.lToken().totalSupply(), calcTestCases2[i].LeverageAssets - calcTestCases2[i].inAmount);
        assertEq(calcTestCases2[i].inAmount, startLevBalance-endLevBalance);
        assertEq(amount, endBondBalance-startBondBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testSwapOnBehalfOf() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases2.length; i++) {
      if (calcTestCases2[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases2[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases2[i].TotalUnderlyingAssets);

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.CreatePool(params, calcTestCases2[i].TotalUnderlyingAssets, calcTestCases2[i].DebtAssets, calcTestCases2[i].LeverageAssets));

      uint256 startBalance = rToken.balanceOf(governance);
      uint256 startBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      uint256 startBondBalanceUser = BondToken(_pool.dToken()).balanceOf(user2);
      uint256 startLevBalanceUser = LeverageToken(_pool.lToken()).balanceOf(user2);


      // Call create and assert minted tokens
      uint256 amount = _pool.swap(calcTestCases2[i].assetType, calcTestCases2[i].inAmount, 0, user2);
      assertEq(amount, calcTestCases2[i].expectedSwap);

      uint256 endBalance = rToken.balanceOf(governance);
      uint256 endBondBalance = BondToken(_pool.dToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      uint256 endBondBalanceUser = BondToken(_pool.dToken()).balanceOf(user2);
      uint256 endLevBalanceUser = LeverageToken(_pool.lToken()).balanceOf(user2);

      assertEq(0, startBalance-endBalance);

      if (calcTestCases2[i].assetType == Pool.TokenType.DEBT) {
        assertEq(_pool.dToken().totalSupply(), calcTestCases2[i].DebtAssets - calcTestCases2[i].inAmount);
        assertEq(_pool.lToken().totalSupply(), calcTestCases2[i].LeverageAssets + amount);
        assertEq(calcTestCases2[i].inAmount, startBondBalance-endBondBalance);
        assertEq(amount, endLevBalanceUser-startLevBalanceUser);
      } else {
        assertEq(_pool.dToken().totalSupply(), calcTestCases2[i].DebtAssets + amount);
        assertEq(_pool.lToken().totalSupply(), calcTestCases2[i].LeverageAssets - calcTestCases2[i].inAmount);
        assertEq(calcTestCases2[i].inAmount, startLevBalance-endLevBalance);
        assertEq(amount, endBondBalanceUser-startBondBalanceUser);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testGetPoolInfo() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000000000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));
    
    Pool.PoolInfo memory info = _pool.getPoolInfo();
    assertEq(info.reserve, 10000000000);
    assertEq(info.debtSupply, 10000);
    assertEq(info.levSupply, 10000);
  }

  function testSetFee() public {
    vm.startPrank(governance);
    Pool _pool = Pool(poolFactory.CreatePool(params, 0, 0, 0));

    _pool.setFee(100);
    assertEq(_pool.fee(), 100);
  }

  function testSetFeeErrorUnauthorized() public {
    vm.startPrank(governance);
    Pool _pool = Pool(poolFactory.CreatePool(params, 0, 0, 0));
    vm.stopPrank();

    vm.expectRevert();
    _pool.setFee(100);
  }

  function testPause() public {
    vm.startPrank(governance);
    Pool _pool = Pool(poolFactory.CreatePool(params, 0, 0, 0));

    _pool.pause();

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    _pool.setFee(0);

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    _pool.create(Pool.TokenType.DEBT, 0, 0);

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    _pool.redeem(Pool.TokenType.DEBT, 0, 0);

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    _pool.swap(Pool.TokenType.DEBT, 0, 0);

    _pool.unpause();
    _pool.setFee(100);
    assertEq(_pool.fee(), 100);
  }

function testNotEnoughBalanceInPool() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));
    vm.stopPrank();
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(minter);
    // Mint less shares than required
    sharesToken.mint(address(_pool), 25*10**18);
    vm.stopPrank();

    vm.startPrank(address(_pool));
    _pool.dToken().mint(user, 1000*10**18);
    vm.stopPrank();

    vm.startPrank(governance);
    //@todo figure out how to specify erc20 insufficient balance error
    vm.expectRevert();
    _pool.distribute();
    vm.stopPrank();
  }

  function testDistribute() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));
    Token sharesToken = Token(_pool.couponToken());
    uint256 initialBalance = 1000 * 10**18;
    uint256 expectedDistribution = (initialBalance + 10000) * params.sharesPerToken / 10**_pool.dToken().SHARES_DECIMALS();
    vm.stopPrank();

    vm.startPrank(address(_pool));
    _pool.dToken().mint(user, initialBalance);
    vm.stopPrank();

    vm.startPrank(minter);
    sharesToken.mint(address(_pool), expectedDistribution);
    vm.stopPrank();

    vm.startPrank(governance);
    _pool.distribute();
    vm.stopPrank();

    assertEq(sharesToken.balanceOf(address(distributor)), expectedDistribution);
  }

  function testDistributeMultiplePeriods() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));

    Token sharesToken = Token(_pool.couponToken());
    uint256 initialBalance = 1000 * 10**18;
    uint256 expectedDistribution = (initialBalance + 10000) * params.sharesPerToken / 10**_pool.dToken().SHARES_DECIMALS();
    vm.stopPrank();
    
    vm.startPrank(address(_pool));
    _pool.dToken().mint(user, initialBalance);
    vm.stopPrank();

    vm.startPrank(minter);
    sharesToken.mint(address(_pool), expectedDistribution * 3);
    vm.stopPrank();

    vm.startPrank(governance);
    _pool.distribute();
    _pool.distribute();
    _pool.distribute();
    vm.stopPrank();

    assertEq(sharesToken.balanceOf(address(distributor)), expectedDistribution * 3);
  }

  function testDistributeNoShares() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));
    vm.stopPrank();
    vm.startPrank(governance);
    vm.expectRevert();
    _pool.distribute();
    vm.stopPrank();
  }

  function testDistributeUnauthorized() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));
    vm.stopPrank();
    vm.expectRevert();
    _pool.distribute();
  }
}

