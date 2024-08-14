// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {DLSP} from "../src/DLSP.sol";
import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {BondToken} from "../src/BondToken.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Utils} from "../src/lib/Utils.sol";

contract PoolTest is Test {
  DLSP private dlsp;
  DLSP.PoolParams private params;

  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private user = address(0x4);
  address private user2 = address(0x5);
  address private distributor = address(0x6);

  struct CalcTestCase {
      Pool.TokenType assetType;
      uint256 inAmount;
      uint256 ethPrice;
      uint256 TotalUnderlyingAssets;
      uint256 DebtAssets;
      uint256 LeverageAssets;
      uint256 expectedCreate;
      uint256 expectedRedeem;
  }

  CalcTestCase[] public calcTestCases;
  CalcTestCase[] public calcTestCases2;

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);

    dlsp = DLSP(Utils.deploy(address(new DLSP()), abi.encodeCall(DLSP.initialize, (governance))));

    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH"));
    params.sharesPerToken = 0;
    params.distributionPeriod = 0;
    
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
        expectedRedeem: 32
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 80000,
        expectedRedeem: 50
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 46875,
        expectedRedeem: 48
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 500,
        ethPrice: 3500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 17500,
        expectedRedeem: 14
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 93750,
        expectedRedeem: 96
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 750,
        ethPrice: 4500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 33750,
        expectedRedeem: 16
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 60000,
        expectedRedeem: 24
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 800,
        ethPrice: 2600,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 25000,
        expectedRedeem: 25
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2200,
        ethPrice: 3300,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 72600,
        expectedRedeem: 66
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3500,
        ethPrice: 4200,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 147000,
        expectedRedeem: 83
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2900,
        ethPrice: 2700,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 90625,
        expectedRedeem: 92
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1800,
        ethPrice: 3800,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 68400,
        expectedRedeem: 47
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 100,
        ethPrice: 8000,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 8000,
        expectedRedeem: 1
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 600,
        ethPrice: 3200,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 19200,
        expectedRedeem: 18
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1600,
        ethPrice: 2900,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 50000,
        expectedRedeem: 51
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 140625,
        expectedRedeem: 144
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 300,
        ethPrice: 7000,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 21000,
        expectedRedeem: 4
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 5000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 156250,
        expectedRedeem: 160
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 400,
        ethPrice: 6500,
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 26000,
        expectedRedeem: 6
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
        expectedRedeem: 33
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 80000,
        expectedRedeem: 50
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 37500,
        expectedRedeem: 60
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 500,
        ethPrice: 3500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 17500,
        expectedRedeem: 14
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 45000,
        expectedRedeem: 200
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 750,
        ethPrice: 4500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 33750,
        expectedRedeem: 16
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 60000,
        expectedRedeem: 24
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 800,
        ethPrice: 2600,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 20800,
        expectedRedeem: 30
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2200,
        ethPrice: 3300,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 72600,
        expectedRedeem: 66
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3500,
        ethPrice: 4200,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 147000,
        expectedRedeem: 83
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2900,
        ethPrice: 2700,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 78300,
        expectedRedeem: 107
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1800,
        ethPrice: 3800,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 68400,
        expectedRedeem: 47
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 100,
        ethPrice: 8000,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 8000,
        expectedRedeem: 1
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 600,
        ethPrice: 3200,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 19200,
        expectedRedeem: 18
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1600,
        ethPrice: 2900,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 46400,
        expectedRedeem: 55
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 112500,
        expectedRedeem: 180
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 300,
        ethPrice: 7000,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 21000,
        expectedRedeem: 4
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 5000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 60000,
        expectedRedeem: 416
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 400,
        ethPrice: 6500,
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 26000,
        expectedRedeem: 6
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
        expectedRedeem: 5
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 45000,
        DebtAssets: 2800000,
        LeverageAssets: 1600000,
        expectedCreate: 355555, // @todo: solidity 355555 - go 355556
        expectedRedeem: 11
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 50000,
        DebtAssets: 3200000,
        LeverageAssets: 1700000,
        expectedCreate: 255000,
        expectedRedeem: 8
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 500,
        ethPrice: 3500,
        TotalUnderlyingAssets: 32000,
        DebtAssets: 2100000,
        LeverageAssets: 1200000,
        expectedCreate: 93750,
        expectedRedeem: 2
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 68000,
        DebtAssets: 3500000,
        LeverageAssets: 1450000,
        expectedCreate: 319852, // @todo: solidity 319852 - go 319853
        expectedRedeem: 28
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 750,
        ethPrice: 4500,
        TotalUnderlyingAssets: 42000,
        DebtAssets: 2700000,
        LeverageAssets: 1800000,
        expectedCreate: 160714,
        expectedRedeem: 3
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 30000,
        DebtAssets: 2900000,
        LeverageAssets: 1350000,
        expectedCreate: 270000,
        expectedRedeem: 5
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 800,
        ethPrice: 2600,
        TotalUnderlyingAssets: 40000,
        DebtAssets: 3100000,
        LeverageAssets: 1500000,
        expectedCreate: 150000,
        expectedRedeem: 4
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2200,
        ethPrice: 3300,
        TotalUnderlyingAssets: 53000,
        DebtAssets: 2400000,
        LeverageAssets: 1250000,
        expectedCreate: 259433, // @todo: solidity 259433 - go 259434
        expectedRedeem: 18
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3500,
        ethPrice: 4200,
        TotalUnderlyingAssets: 48000,
        DebtAssets: 2700000,
        LeverageAssets: 1650000,
        expectedCreate: 601562,
        expectedRedeem: 20
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2900,
        ethPrice: 2700,
        TotalUnderlyingAssets: 45000,
        DebtAssets: 2900000,
        LeverageAssets: 1600000,
        expectedCreate: 515555, // @todo: solidity 515555 - go 515556
        expectedRedeem: 16
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1800,
        ethPrice: 3800,
        TotalUnderlyingAssets: 42000,
        DebtAssets: 3300000,
        LeverageAssets: 1400000,
        expectedCreate: 300000,
        expectedRedeem: 10
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 100,
        ethPrice: 8000,
        TotalUnderlyingAssets: 37000,
        DebtAssets: 3500000,
        LeverageAssets: 1500000,
        expectedCreate: 20270,
        expectedRedeem: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 600,
        ethPrice: 3200,
        TotalUnderlyingAssets: 30000,
        DebtAssets: 2200000,
        LeverageAssets: 1000000,
        expectedCreate: 100000,
        expectedRedeem: 3
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1600,
        ethPrice: 2900,
        TotalUnderlyingAssets: 34000,
        DebtAssets: 3100000,
        LeverageAssets: 1800000,
        expectedCreate: 423529,
        expectedRedeem: 6
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 68000,
        DebtAssets: 2700000,
        LeverageAssets: 1200000,
        expectedCreate: 397058, // @todo: solidity 397058 - go 397059
        expectedRedeem: 50
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 300,
        ethPrice: 7000,
        TotalUnderlyingAssets: 30000,
        DebtAssets: 2900000,
        LeverageAssets: 1700000,
        expectedCreate: 85000,
        expectedRedeem: 1
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 58000,
        DebtAssets: 2600000,
        LeverageAssets: 1100000,
        expectedCreate: 474137, // @todo: solidity 474137 - go 474138
        expectedRedeem: 52
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 400,
        ethPrice: 6500,
        TotalUnderlyingAssets: 33000,
        DebtAssets: 2300000,
        LeverageAssets: 1400000,
        expectedCreate: 84848,
        expectedRedeem: 1
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
        expectedRedeem: 6396
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 7500000,
        DebtAssets: 900000,
        LeverageAssets: 1600000,
        expectedCreate: 427, // @todo: solidity 427 - go 428
        expectedRedeem: 9346
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3000,
        ethPrice: 2500,
        TotalUnderlyingAssets: 8000000,
        DebtAssets: 950000,
        LeverageAssets: 1700000,
        expectedCreate: 640, // @todo: solidity 640 - go 641
        expectedRedeem: 14049
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1000,
        ethPrice: 3500,
        TotalUnderlyingAssets: 9000000,
        DebtAssets: 1200000,
        LeverageAssets: 1200000,
        expectedCreate: 133, // @todo solidity 133 - go 134
        expectedRedeem: 7471
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2500,
        ethPrice: 4500,
        TotalUnderlyingAssets: 9500000,
        DebtAssets: 1300000,
        LeverageAssets: 1500000,
        expectedCreate: 395, // @todo solidity 395 - go 396
        expectedRedeem: 15785
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 10000000,
        DebtAssets: 1250000,
        LeverageAssets: 1450000,
        expectedCreate: 174,
        expectedRedeem: 8255
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1800,
        ethPrice: 5500,
        TotalUnderlyingAssets: 10500000,
        DebtAssets: 1350000,
        LeverageAssets: 1550000,
        expectedCreate: 266,
        expectedRedeem: 12164
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1600,
        ethPrice: 2700,
        TotalUnderlyingAssets: 7000000,
        DebtAssets: 850000,
        LeverageAssets: 1300000,
        expectedCreate: 298,
        expectedRedeem: 8576
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3000,
        ethPrice: 3400,
        TotalUnderlyingAssets: 8000000,
        DebtAssets: 950000,
        LeverageAssets: 1700000,
        expectedCreate: 639, // @todo: solidity 639 - go 640
        expectedRedeem: 14068
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5000,
        ethPrice: 150000,
        TotalUnderlyingAssets: 5000000000000,
        DebtAssets: 3000000000000,
        LeverageAssets: 1000000000000,
        expectedCreate: 1000,
        expectedRedeem: 24990
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1000,
        ethPrice: 2500,
        TotalUnderlyingAssets: 8000000,
        DebtAssets: 1000000,
        LeverageAssets: 1800000,
        expectedCreate: 226,
        expectedRedeem: 4422
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 4800,
        TotalUnderlyingAssets: 750000000000,
        DebtAssets: 300000000000,
        LeverageAssets: 50000000000,
        expectedCreate: 215,
        expectedRedeem: 47600
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 7000,
        ethPrice: 6000,
        TotalUnderlyingAssets: 3000000,
        DebtAssets: 1200000,
        LeverageAssets: 2000000,
        expectedCreate: 4697, // @todo: solidity 4697 - go 4698
        expectedRedeem: 10430
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 8500,
        ethPrice: 5000,
        TotalUnderlyingAssets: 20000000000,
        DebtAssets: 8000000000,
        LeverageAssets: 3000000000,
        expectedCreate: 1285,
        expectedRedeem: 56212
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2400,
        ethPrice: 7500,
        TotalUnderlyingAssets: 100000000000,
        DebtAssets: 30000000000,
        LeverageAssets: 5000000000,
        expectedCreate: 120,
        expectedRedeem: 47808
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4000,
        ethPrice: 2200,
        TotalUnderlyingAssets: 100000000,
        DebtAssets: 25000000,
        LeverageAssets: 5000000,
        expectedCreate: 202,
        expectedRedeem: 79090
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3700,
        ethPrice: 4500,
        TotalUnderlyingAssets: 1500000000000,
        DebtAssets: 400000000000,
        LeverageAssets: 200000000000,
        expectedCreate: 496,
        expectedRedeem: 27585
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 3000,
        TotalUnderlyingAssets: 2500000,
        DebtAssets: 1000000,
        LeverageAssets: 1500000,
        expectedCreate: 912,
        expectedRedeem: 2466
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2900,
        ethPrice: 12000,
        TotalUnderlyingAssets: 10000000000000,
        DebtAssets: 4000000000000,
        LeverageAssets: 2000000000000,
        expectedCreate: 581, // @todo: solidity 581 - go 582
        expectedRedeem: 14451
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
        expectedRedeem: 2057
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1000,
        ethPrice: 3600,
        TotalUnderlyingAssets: 7200000,
        DebtAssets: 216000000,
        LeverageAssets: 1800000,
        expectedCreate: 37500,
        expectedRedeem: 26
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 4800,
        TotalUnderlyingAssets: 960000000,
        DebtAssets: 38400000000,
        LeverageAssets: 500000000,
        expectedCreate: 8333,
        expectedRedeem: 1228
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 7000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 144000000,
        DebtAssets: 1440000000,
        LeverageAssets: 2000000,
        expectedCreate: 87500,
        expectedRedeem: 560
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 8500,
        ethPrice: 9000,
        TotalUnderlyingAssets: 5400000000,
        DebtAssets: 405000000000,
        LeverageAssets: 3000000000,
        expectedCreate: 23611,
        expectedRedeem: 3060
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2400,
        ethPrice: 6000,
        TotalUnderlyingAssets: 360000000,
        DebtAssets: 18000000000,
        LeverageAssets: 500000000,
        expectedCreate: 150000,
        expectedRedeem: 38
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4000,
        ethPrice: 1800,
        TotalUnderlyingAssets: 432000000,
        DebtAssets: 6480000000,
        LeverageAssets: 5000000,
        expectedCreate: 231,
        expectedRedeem: 69120
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3700,
        ethPrice: 1500,
        TotalUnderlyingAssets: 54000000,
        DebtAssets: 675000000,
        LeverageAssets: 200000000,
        expectedCreate: 57812,
        expectedRedeem: 246
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 4800,
        TotalUnderlyingAssets: 720000000,
        DebtAssets: 28800000000,
        LeverageAssets: 500000000,
        expectedCreate: 5208,
        expectedRedeem: 432
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2900,
        ethPrice: 3000,
        TotalUnderlyingAssets: 900000000,
        DebtAssets: 22500000000,
        LeverageAssets: 4000000,
        expectedCreate: 90625,
        expectedRedeem: 92
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1200,
        ethPrice: 6000,
        TotalUnderlyingAssets: 1800000000,
        DebtAssets: 90000000000,
        LeverageAssets: 500000000,
        expectedCreate: 1666, // @todo: solidity 1666 - go 1667
        expectedRedeem: 864
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4500,
        ethPrice: 15000,
        TotalUnderlyingAssets: 18000000000,
        DebtAssets: 2250000000000,
        LeverageAssets: 1500000000,
        expectedCreate: 703125,
        expectedRedeem: 28
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5200,
        ethPrice: 2400,
        TotalUnderlyingAssets: 288000000,
        DebtAssets: 5760000000,
        LeverageAssets: 500000000,
        expectedCreate: 45138, // @todo: solidity 45138 - go 45139
        expectedRedeem: 599
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3000,
        ethPrice: 9000,
        TotalUnderlyingAssets: 5400000000,
        DebtAssets: 405000000000,
        LeverageAssets: 250000000,
        expectedCreate: 281250,
        expectedRedeem: 32
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 6000,
        ethPrice: 7200,
        TotalUnderlyingAssets: 4320000000,
        DebtAssets: 259200000000,
        LeverageAssets: 3000000000,
        expectedCreate: 20833,
        expectedRedeem: 1728
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 7000,
        ethPrice: 4800,
        TotalUnderlyingAssets: 1440000000,
        DebtAssets: 57600000000,
        LeverageAssets: 600000000,
        expectedCreate: 350000,
        expectedRedeem: 140
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 8000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 900000000,
        DebtAssets: 11250000000,
        LeverageAssets: 300000000,
        expectedCreate: 13333,
        expectedRedeem: 4800
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 2500,
        ethPrice: 1200,
        TotalUnderlyingAssets: 36000000,
        DebtAssets: 360000000,
        LeverageAssets: 300000000,
        expectedCreate: 31250,
        expectedRedeem: 208
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 3600,
        TotalUnderlyingAssets: 108000000,
        DebtAssets: 3240000000,
        LeverageAssets: 5000000,
        expectedCreate: 740, // @todo: solidity 740 - go 741
        expectedRedeem: 13824
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4700,
        ethPrice: 6000,
        TotalUnderlyingAssets: 720000000,
        DebtAssets: 43200000000,
        LeverageAssets: 300000000,
        expectedCreate: 352500,
        expectedRedeem: 62
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 2400,
        TotalUnderlyingAssets: 288000000,
        DebtAssets: 5760000000,
        LeverageAssets: 2000000,
        expectedCreate: 52,
        expectedRedeem: 43200
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 5500,
        ethPrice: 15000,
        TotalUnderlyingAssets: 18000000000,
        DebtAssets: 2250000000000,
        LeverageAssets: 1500000000,
        expectedCreate: 859375,
        expectedRedeem: 35
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2700,
        ethPrice: 7200,
        TotalUnderlyingAssets: 432000000,
        DebtAssets: 25920000000,
        LeverageAssets: 100000000,
        expectedCreate: 3125,
        expectedRedeem: 2332
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 4200,
        ethPrice: 9000,
        TotalUnderlyingAssets: 5400000000,
        DebtAssets: 405000000000,
        LeverageAssets: 200000000,
        expectedCreate: 393750,
        expectedRedeem: 44
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 4800,
        TotalUnderlyingAssets: 720000000,
        DebtAssets: 28800000000,
        LeverageAssets: 300000000,
        expectedCreate: 6666, // @todo: solidity 6666 - go 6667
        expectedRedeem: 1536
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 6800,
        ethPrice: 12000,
        TotalUnderlyingAssets: 14400000000,
        DebtAssets: 1440000000000,
        LeverageAssets: 500000000,
        expectedCreate: 850000,
        expectedRedeem: 54
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4500,
        ethPrice: 6000,
        TotalUnderlyingAssets: 720000000,
        DebtAssets: 43200000000,
        LeverageAssets: 300000000,
        expectedCreate: 9375,
        expectedRedeem: 2160
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 7800,
        ethPrice: 15000,
        TotalUnderlyingAssets: 18000000000,
        DebtAssets: 2250000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 1218750,
        expectedRedeem: 49
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5100,
        ethPrice: 3600,
        TotalUnderlyingAssets: 108000000,
        DebtAssets: 3240000000,
        LeverageAssets: 100000000,
        expectedCreate: 23611,
        expectedRedeem: 1101
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 3100,
        ethPrice: 1200,
        TotalUnderlyingAssets: 288000000,
        DebtAssets: 2880000000,
        LeverageAssets: 500000000,
        expectedCreate: 38750,
        expectedRedeem: 248
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
        expectedRedeem: 32
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 1250,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 37500,
        expectedRedeem: 41
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 500,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 32000,
        DebtAssets: 2100000,
        LeverageAssets: 1200000,
        expectedCreate: 93750,
        expectedRedeem: 2
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1600,
        ethPrice: 0,
        TotalUnderlyingAssets: 7000000,
        DebtAssets: 850000,
        LeverageAssets: 1300000,
        expectedCreate: 298,
        expectedRedeem: 8580
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 960000000,
        DebtAssets: 38400000000,
        LeverageAssets: 500000000,
        expectedCreate: 8333,
        expectedRedeem: 1228
    }));

    calcTestCases2.push(CalcTestCase({
        assetType: Pool.TokenType.DEBT,
        inAmount: 7000,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 144000000,
        DebtAssets: 1440000000,
        LeverageAssets: 2000000,
        expectedCreate: 210000,
        expectedRedeem: 233
    }));
  }

  function testGetCreateAmount() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets);
      rToken.approve(address(dlsp), calcTestCases[i].TotalUnderlyingAssets);

      Pool _pool = Pool(dlsp.CreatePool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets));

      uint256 amount = _pool.getCreateAmount(calcTestCases[i].assetType, calcTestCases[i].inAmount, calcTestCases[i].ethPrice);
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
    vm.startPrank(governance);
    Pool _pool = Pool(dlsp.CreatePool(params, 0, 0, 0));

    vm.expectRevert(Pool.ZeroDebtSupply.selector);
    _pool.getCreateAmount(Pool.TokenType.DEBT, 10, 3000);
  }

  function testGetCreateAmountZeroLeverageSupply() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 100000);
    rToken.approve(address(dlsp), 100000);

    Pool _pool = Pool(dlsp.CreatePool(params, 100000, 10, 0));
    
    vm.expectRevert(Pool.ZeroLeverageSupply.selector);
    _pool.getCreateAmount(Pool.TokenType.LEVERAGE, 10, 30000000);
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
      rToken.approve(address(dlsp), calcTestCases2[i].TotalUnderlyingAssets);

      // Create pool and approve deposit amount
      Pool _pool = Pool(dlsp.CreatePool(params, calcTestCases2[i].TotalUnderlyingAssets, calcTestCases2[i].DebtAssets, calcTestCases2[i].LeverageAssets));
      rToken.approve(address(_pool), calcTestCases2[i].inAmount);

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases2[i].assetType, calcTestCases2[i].inAmount, 0);
      assertEq(amount, calcTestCases2[i].expectedCreate);

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
    rToken.approve(address(dlsp), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(dlsp.CreatePool(params, 10000000000, 10000, 10000));
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
    rToken.approve(address(dlsp), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(dlsp.CreatePool(params, 10000000000, 10000, 10000));
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
      rToken.approve(address(dlsp), calcTestCases[i].TotalUnderlyingAssets);

      Pool _pool = Pool(dlsp.CreatePool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets));

      uint256 amount = _pool.getRedeemAmount(calcTestCases[i].assetType, calcTestCases[i].inAmount, calcTestCases[i].ethPrice);
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
      rToken.approve(address(dlsp), calcTestCases2[i].TotalUnderlyingAssets);

      // Create pool and approve deposit amount
      Pool _pool = Pool(dlsp.CreatePool(params, calcTestCases2[i].TotalUnderlyingAssets, calcTestCases2[i].DebtAssets, calcTestCases2[i].LeverageAssets));

      // Call create and assert minted tokens
      uint256 amount = _pool.redeem(calcTestCases2[i].assetType, calcTestCases2[i].inAmount, 0);
      assertEq(amount, calcTestCases2[i].expectedRedeem);

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testRedeemMinAmountExactSuccess() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(dlsp), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(dlsp.CreatePool(params, 10000000000, 10000, 10000));
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
    rToken.approve(address(dlsp), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(dlsp.CreatePool(params, 10000000000, 10000, 10000));
    rToken.approve(address(_pool), 1000);

    // Call create and expect error
    vm.expectRevert(Pool.MinAmount.selector);
    _pool.redeem(Pool.TokenType.DEBT, 1000, 34);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testSetFee() public {
    vm.startPrank(governance);
    Pool _pool = Pool(dlsp.CreatePool(params, 0, 0, 0));

    _pool.setFee(100);
    assertEq(_pool.fee(), 100);
  }

  function testSetFeeErrorUnauthorized() public {
    vm.startPrank(governance);
    Pool _pool = Pool(dlsp.CreatePool(params, 0, 0, 0));
    vm.stopPrank();

    vm.expectRevert();
    _pool.setFee(100);
  }

  function testPause() public {
    vm.startPrank(governance);
    Pool _pool = Pool(dlsp.CreatePool(params, 0, 0, 0));

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
}
