// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "../../src/Pool.sol";

contract TestCases {
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

  function initializeTestCases() public {
    // Reset test cases
    delete calcTestCases;

    // Debt - Below Threshold
    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        expectedCreate: 355555,
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
        expectedCreate: 319852,
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
        expectedCreate: 259433,
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
        expectedCreate: 515555,
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
        expectedCreate: 397058,
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
        expectedCreate: 474137,
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
        expectedCreate: 351,
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
        expectedCreate: 427,
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
        expectedCreate: 640,
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
        expectedCreate: 639,
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
        expectedCreate: 4697,
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
        expectedCreate: 581,
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
        expectedCreate: 12152,
        expectedRedeem: 2057,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        expectedCreate: 1666,
        expectedRedeem: 864,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.BOND,
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
        expectedCreate: 45138,
        expectedRedeem: 599,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        expectedCreate: 740,
        expectedRedeem: 13824,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        expectedCreate: 6666,
        expectedRedeem: 1536,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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
        assetType: Pool.TokenType.BOND,
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

  function initializeRealisticTestCases() public {
    // Reset test cases
    delete calcTestCases;

    // Debt - Below Threshold
    calcTestCases.push(CalcTestCase({
      assetType: Pool.TokenType.BOND,
      inAmount: 3 ether,
      ethPrice: 3000 * 10**8,
      TotalUnderlyingAssets: 1000000 ether,
      DebtAssets: 30000000 ether,
      LeverageAssets: 1000000 ether,
      expectedCreate: 112500000000000000000,
      expectedRedeem: 80000000000000000,
      expectedSwap: 400000032000002560
    }));
    // Debt - Above Threshold
    calcTestCases.push(CalcTestCase({
      assetType: Pool.TokenType.BOND,
      inAmount: 3 ether,
      ethPrice: 3000 * 10**8,
      TotalUnderlyingAssets: 1000000 ether,
      DebtAssets: 20000000 ether,
      LeverageAssets: 1000000 ether,
      expectedCreate: 90000000000000000000,
      expectedRedeem: 100000000000000000,
      expectedSwap: 300000000000000000
    }));
    
    // Leverage - Below Threshold
    calcTestCases.push(CalcTestCase({
      assetType: Pool.TokenType.LEVERAGE,
      inAmount: 3 ether,
      ethPrice: 3000 * 10**8,
      TotalUnderlyingAssets: 1000000 ether,
      DebtAssets: 30000000 ether,
      LeverageAssets: 1000000 ether,
      expectedCreate: 15000000000000000000,
      expectedRedeem: 600000000000000000,
      expectedSwap: 22500013500008100004
    }));
    // Leverage - Above Threshold
    calcTestCases.push(CalcTestCase({
      assetType: Pool.TokenType.LEVERAGE,
      inAmount: 3 ether,
      ethPrice: 3000 * 10**8,
      TotalUnderlyingAssets: 1000000 ether,
      DebtAssets: 20000000 ether,
      LeverageAssets: 1000000 ether,
      expectedCreate: 9000000000000000000,
      expectedRedeem: 1000000000000000000,
      expectedSwap: 30000000000000000000
    }));
    // Random Values but Leverage Level = 1.2
    calcTestCases.push(CalcTestCase({
      assetType: Pool.TokenType.BOND,
      inAmount: 3 ether,
      ethPrice: 3000 * 10**8,
      TotalUnderlyingAssets: 1000000 ether,
      DebtAssets: 25000000 ether,
      LeverageAssets: 1000000 ether,
      expectedCreate: 93750000000000000000,
      expectedRedeem: 96000000000000000,
      expectedSwap: 480000046400004485
    }));
    calcTestCases.push(CalcTestCase({
      assetType: Pool.TokenType.LEVERAGE,
      inAmount: 3 ether,
      ethPrice: 3000 * 10**8,
      TotalUnderlyingAssets: 1000000 ether,
      DebtAssets: 25000000 ether,
      LeverageAssets: 1000000 ether,
      expectedCreate: 15000000000000000000,
      expectedRedeem: 600000000000000000,
      expectedSwap: 18750011328131844079
    }));
  }

  // eth comes from Pool constant (3000)
  function initializeTestCasesFixedEth() public {
    delete calcTestCases;
    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1000,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 1000000000,
        DebtAssets: 25000000000,
        LeverageAssets: 1000000000,
        expectedCreate: 31250,
        expectedRedeem: 32,
        expectedSwap: 160
    }));

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1250,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 1200456789222,
        DebtAssets: 25123456789,
        LeverageAssets: 1321654987,
        expectedCreate: 37500,
        expectedRedeem: 41,
        expectedSwap: 0
    }));

    calcTestCases.push(CalcTestCase({
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

    calcTestCases.push(CalcTestCase({
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

    calcTestCases.push(CalcTestCase({
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

    calcTestCases.push(CalcTestCase({
        assetType: Pool.TokenType.BOND,
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
}
