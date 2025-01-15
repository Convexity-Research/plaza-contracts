// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Auction} from "../src/Auction.sol";
import {Utils} from "../src/lib/Utils.sol";
import {MockPool} from "./mocks/MockPool.sol";
import {BondToken} from "../src/BondToken.sol";
import {TestCases} from "./data/TestCases.sol";
import {Decimals} from "../src/lib/Decimals.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Distributor} from "../src/Distributor.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";
import {Validator} from "../src/utils/Validator.sol";
import {OracleReader} from "../src/OracleReader.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract PoolTest is Test, TestCases {
  using Decimals for uint256;
  using Strings for uint256;

  PoolFactory private poolFactory;
  PoolFactory.PoolParams private params;

  MockPriceFeed private mockPriceFeed;
  address private oracleFeedsContract;

  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private securityCouncil = address(0x4);
  address private user = address(0x5);
  address private user2 = address(0x6);

  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);
  uint256 private constant CHAINLINK_DECIMAL_PRECISION = 10**8;
  uint8 private constant CHAINLINK_DECIMAL = 8;

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);

    address contractDeployer = address(new Deployer());
    oracleFeedsContract = address(new OracleFeeds());

    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));

    poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize, 
      (governance, contractDeployer, oracleFeedsContract, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
    )));

    params.fee = 0;
    params.feeBeneficiary = governance;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH", false));
    params.sharesPerToken = 50 * 10 ** 18;
    params.distributionPeriod = 0;
    params.couponToken = address(new Token("USDC", "USDC", false));
    
    OracleFeeds(oracleFeedsContract).setPriceFeed(params.reserveToken, address(0), ethPriceFeed, 1 days);

    // Deploy the mock price feed
    mockPriceFeed = new MockPriceFeed();

    // Use vm.etch to deploy the mock contract at the specific address
    bytes memory bytecode = address(mockPriceFeed).code;
    vm.etch(ethPriceFeed, bytecode);

    // Set oracle price
    mockPriceFeed = MockPriceFeed(ethPriceFeed);
    mockPriceFeed.setMockPrice(3000 * int256(CHAINLINK_DECIMAL_PRECISION), uint8(CHAINLINK_DECIMAL));
    
    vm.stopPrank();

    vm.startPrank(governance);
    poolFactory.grantRole(poolFactory.POOL_ROLE(), governance);
    poolFactory.grantRole(poolFactory.SECURITY_COUNCIL_ROLE(), securityCouncil);
    vm.stopPrank();
  }

  function useMockPool(address poolAddress) public {
    // Deploy the mock pool
    MockPool mockPool = new MockPool();

    // Use vm.etch to deploy the mock contract at the specific address
    vm.etch(poolAddress, address(mockPool).code);
  }

  function setEthPrice(uint256 price) public {
    mockPriceFeed = MockPriceFeed(ethPriceFeed);
    mockPriceFeed.setMockPrice(int256(price), uint8(CHAINLINK_DECIMAL));
  }

  function resetReentrancy(address contractAddress) public {
    // Reset `_status` to allow the next call
    vm.store(
      contractAddress,
      bytes32(0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00), // Storage slot for `_status`
      bytes32(uint256(1))  // Reset to `_NOT_ENTERED`
    );
  }

  function fakeSucceededAuction(address poolAddress, uint256 period) public {
    address auction = Utils.deploy(address(new Auction()), abi.encodeWithSelector(Auction.initialize.selector, params.couponToken, params.reserveToken, 1000000000000, block.timestamp + 10 days, 1000, address(0), 95));

    uint256 auctionSlot = 11;
    bytes32 auctionPeriodSlot = keccak256(abi.encode(period, auctionSlot));
    vm.store(address(poolAddress), auctionPeriodSlot, bytes32(uint256(uint160(auction))));

    uint256 stateSlot = 6;
    vm.store(auction, bytes32(stateSlot), bytes32(uint256(1)));
  }

  function testGetCreateAmount() public {
    initializeTestCases();
    
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      string memory salt = i.toString();
      Pool _pool = Pool(poolFactory.createPool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets, "", salt, "", "", false));

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
    pool.getCreateAmount(Pool.TokenType.BOND, 10, 0, 100, 100, 3000, CHAINLINK_DECIMAL);
  }

  function testGetCreateAmountZeroLeverageSupply() public {
    Pool pool = new Pool();
    vm.expectRevert(Pool.ZeroLeverageSupply.selector);
    pool.getCreateAmount(Pool.TokenType.LEVERAGE, 10, 100000, 0, 10000, 30000000 * CHAINLINK_DECIMAL_PRECISION, CHAINLINK_DECIMAL);
  }

    function testGetCreateAmountZeroLeverageSupplyCollatLower() public {
    Pool pool = new Pool();
    vm.expectRevert(Pool.ZeroLeverageSupply.selector);
    // collateral level is 1/10000000, less than threshold
    pool.getCreateAmount(Pool.TokenType.LEVERAGE, 10, 100000, 0, 1, 1, CHAINLINK_DECIMAL);
  }

  function testCreate() public {
    initializeTestCasesFixedEth();
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets + calcTestCases[i].inAmount);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      string memory salt = i.toString();
      
      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.createPool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets, "", salt, "", "", false));
      useMockPool(address(_pool));
      rToken.approve(address(_pool), calcTestCases[i].inAmount);

      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 startReserveBalance = rToken.balanceOf(governance);

      vm.expectEmit(true, true, true, true);
      emit Pool.TokensCreated(governance, governance, calcTestCases[i].assetType, calcTestCases[i].inAmount, calcTestCases[i].expectedCreate);

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0);
      assertEq(amount, calcTestCases[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 endReserveBalance = rToken.balanceOf(governance);
      assertEq(calcTestCases[i].inAmount, startReserveBalance-endReserveBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(amount, endBondBalance-startBondBalance);
        assertEq(0, endLevBalance-startLevBalance);
      } else {
        assertEq(0, endBondBalance-startBondBalance);
        assertEq(amount, endLevBalance-startLevBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));

      resetReentrancy(address(_pool));
    }
  }

  function testCreateOnBehalfOf() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets + calcTestCases[i].inAmount);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.createPool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets, "", salt, "", "", false));
      rToken.approve(address(_pool), calcTestCases[i].inAmount);

      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(user2);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(user2);
      uint256 startReserveBalance = rToken.balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0, block.timestamp, user2);
      assertEq(amount, calcTestCases[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(user2);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(user2);
      uint256 endReserveBalance = rToken.balanceOf(governance);
      assertEq(calcTestCases[i].inAmount, startReserveBalance-endReserveBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(amount, endBondBalance-startBondBalance);
        assertEq(0, endLevBalance-startLevBalance);
      } else {
        assertEq(0, endBondBalance-startBondBalance);
        assertEq(amount, endLevBalance-startLevBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));

      resetReentrancy(address(_pool));
    }
  }

  function testCreateDeadlineExactSuccess() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));

    rToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    uint256 amount = _pool.create(Pool.TokenType.BOND, 1000, 30000, block.timestamp, governance);
    assertEq(amount, 30000);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testCreateDeadlineSuccess() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));

    rToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    uint256 amount = _pool.create(Pool.TokenType.BOND, 1000, 30000, block.timestamp + 10000, governance);
    assertEq(amount, 30000);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testCreateDeadlineRevert() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));

    rToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    vm.expectRevert(Validator.TransactionTooOld.selector);
    _pool.create(Pool.TokenType.BOND, 1000, 30000, block.timestamp - 1, governance);
  }

  function testCreateDeadlineSimulateBlockAdvanceRevert() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    
    // Simulate block advanced
    useMockPool(address(_pool));
    MockPool(address(_pool)).setTime(block.timestamp + 1);

    rToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    vm.expectRevert(Validator.TransactionTooOld.selector);
    _pool.create(Pool.TokenType.BOND, 1000, 30000, block.timestamp, governance);
  }

  function testCreateMinAmountExactSuccess() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    rToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    uint256 amount = _pool.create(Pool.TokenType.BOND, 1000, 30000);
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
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    rToken.approve(address(_pool), 1000);

    // Call create and expect error
    vm.expectRevert(Pool.MinAmount.selector);
    _pool.create(Pool.TokenType.BOND, 1000, 30001);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testGetRedeemAmount() public {
    initializeTestCases();
    
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      Pool _pool = Pool(poolFactory.createPool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets, "", salt, "", "", false));

      uint256 amount = _pool.getRedeemAmount(
        calcTestCases[i].assetType, 
        calcTestCases[i].inAmount, 
        calcTestCases[i].DebtAssets, 
        calcTestCases[i].LeverageAssets, 
        calcTestCases[i].TotalUnderlyingAssets, 
        calcTestCases[i].ethPrice * CHAINLINK_DECIMAL_PRECISION,
        CHAINLINK_DECIMAL,
        0
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
    initializeTestCasesFixedEth();

    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.createPool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets, "", salt, "", "", false));

      uint256 startBalance = rToken.balanceOf(governance);
      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      vm.expectEmit(true, true, true, true);
      emit Pool.TokensRedeemed(governance, governance, calcTestCases[i].assetType, calcTestCases[i].inAmount, calcTestCases[i].expectedRedeem);

      // Call create and assert minted tokens
      uint256 amount = _pool.redeem(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0);
      assertEq(amount, calcTestCases[i].expectedRedeem);

      uint256 endBalance = rToken.balanceOf(governance);
      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      assertEq(amount, endBalance-startBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(calcTestCases[i].inAmount, startBondBalance-endBondBalance);
        assertEq(0, endLevBalance-startLevBalance);
      } else {
        assertEq(0, endBondBalance-startBondBalance);
        assertEq(calcTestCases[i].inAmount, startLevBalance-endLevBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testRedeemOnBehalfOf() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.createPool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets, "", salt, "", "", false));

      uint256 startBalance = rToken.balanceOf(user2);
      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.redeem(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0, block.timestamp, user2);
      assertEq(amount, calcTestCases[i].expectedRedeem);

      uint256 endBalance = rToken.balanceOf(user2);
      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      assertEq(amount, endBalance-startBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(calcTestCases[i].inAmount, startBondBalance-endBondBalance);
        assertEq(0, endLevBalance-startLevBalance);
      } else {
        assertEq(0, endBondBalance-startBondBalance);
        assertEq(calcTestCases[i].inAmount, startLevBalance-endLevBalance);
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
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    rToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    uint256 amount = _pool.redeem(Pool.TokenType.BOND, 1000, 33);
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
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    rToken.approve(address(_pool), 1000);

    // Call create and expect error
    vm.expectRevert(Pool.MinAmount.selector);
    _pool.redeem(Pool.TokenType.BOND, 1000, 34);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testGetPoolInfo() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000000000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    
    Pool.PoolInfo memory info = _pool.getPoolInfo();
    assertEq(info.reserve, 10000000000);
    assertEq(info.bondSupply, 10000);
    assertEq(info.levSupply, 10000);
  }

  function testSetDistributionPeriod() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 1);
    rToken.approve(address(poolFactory), 1);
    Pool _pool = Pool(poolFactory.createPool(params, 1, 1, 1, "", "", "", "", false));
    rToken.burn(address(_pool), 1);
    
    _pool.setDistributionPeriod(100);

    Pool.PoolInfo memory info = _pool.getPoolInfo();
    assertEq(info.distributionPeriod, 100);
  }

  function testSetDistributionPeriodErrorUnauthorized() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 1);
    rToken.approve(address(poolFactory), 1);
    Pool _pool = Pool(poolFactory.createPool(params, 1, 1, 1, "", "", "", "", false));
    vm.stopPrank();

    rToken.burn(address(_pool), 1);

    vm.expectRevert();
    _pool.setDistributionPeriod(100);
  }

  function testSetFee() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 1);
    rToken.approve(address(poolFactory), 1);
    Pool _pool = Pool(poolFactory.createPool(params, 1, 1, 1, "", "", "", "", false));
    rToken.burn(address(_pool), 1);

    _pool.setFee(100);

    Pool.PoolInfo memory info = _pool.getPoolInfo();
    assertEq(info.fee, 100);
  }

  function testSetFeeErrorUnauthorized() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 1);
    rToken.approve(address(poolFactory), 1);
    Pool _pool = Pool(poolFactory.createPool(params, 1, 1, 1, "", "", "", "", false));
    rToken.burn(address(_pool), 1);
    vm.stopPrank();

    vm.expectRevert();
    _pool.setFee(100);
  }

  function testPause() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 1);
    rToken.approve(address(poolFactory), 1);
    Pool _pool = Pool(poolFactory.createPool(params, 1, 1, 1, "", "", "", "", false));
    rToken.burn(address(_pool), 1);

    vm.startPrank(securityCouncil);
    _pool.pause();

    vm.startPrank(governance);
    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    _pool.create(Pool.TokenType.BOND, 0, 0);

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    _pool.redeem(Pool.TokenType.BOND, 0, 0);

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    _pool.startAuction();

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    _pool.distribute();

    vm.startPrank(securityCouncil);
    _pool.unpause();

    vm.startPrank(governance);
    _pool.setFee(100);

    Pool.PoolInfo memory info = _pool.getPoolInfo();
    assertEq(info.fee, 100);
  }

  function testNotEnoughBalanceInPool() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    vm.stopPrank();
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(minter);
    // Mint less shares than required
    sharesToken.mint(address(_pool), 25*10**18);
    vm.stopPrank();

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user, 1000*10**18);
    vm.stopPrank();

    vm.startPrank(governance);
    //@todo figure out how to specify erc20 insufficient balance error
    vm.expectRevert();
    _pool.distribute();
    vm.stopPrank();
  }

  function testDistributeasd() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    address distributor = poolFactory.distributors(address(_pool));

    Token sharesToken = Token(_pool.couponToken());
    uint256 initialBalance = 1000 * 10**18;
    uint256 expectedDistribution = (initialBalance + 10000) * params.sharesPerToken / 10**_pool.bondToken().SHARES_DECIMALS();

    vm.stopPrank();

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user, initialBalance);
    vm.stopPrank();

    vm.startPrank(minter);
    sharesToken.mint(address(_pool), expectedDistribution);
    vm.stopPrank();

    vm.startPrank(governance);

    fakeSucceededAuction(address(_pool), 0);

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("state()"),
      abi.encode(uint256(1))
    );

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("totalBuyCouponAmount()"),
      abi.encode(expectedDistribution)
    );

    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    vm.stopPrank();
    vm.startPrank(distributor);
    _pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);

    vm.stopPrank();
    vm.startPrank(governance);

    _pool.distribute();
    vm.stopPrank();

    assertEq(sharesToken.balanceOf(distributor), expectedDistribution);
  }

  function testDistributeFailedPoolSale() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    address distributor = poolFactory.distributors(address(_pool));

    Token sharesToken = Token(_pool.couponToken());
    uint256 initialBalance = 1000 * 10**18;
    vm.stopPrank();

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user, initialBalance);

    fakeSucceededAuction(address(_pool), 0);

    // Force auction to fail during pool sale
    vm.mockCall(
      address(0),
      abi.encodeWithSignature("state()"),
      abi.encode(uint256(3))
    );

    // Fast forward 5 days
    vm.warp(block.timestamp + 5 days);

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("totalBuyCouponAmount()"),
      abi.encode(uint256(0))
    );

    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    _pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);

    vm.expectEmit(true, true, true, true);
    emit Pool.DistributionRollOver(0, 0);

    _pool.distribute();
    vm.stopPrank();

    Pool.PoolInfo memory info = _pool.getPoolInfo();
    assertEq(info.currentPeriod, 1);
    assertEq(sharesToken.balanceOf(address(distributor)), 0);
  }

  function testDistributeFailedUndersold() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    address distributor = poolFactory.distributors(address(_pool));
    
    Token sharesToken = Token(_pool.couponToken());
    uint256 initialBalance = 1000 * 10**18;
    vm.stopPrank();

    vm.startPrank(address(_pool));
    _pool.bondToken().mint(user, initialBalance);

    fakeSucceededAuction(address(_pool), 0);

    // Force auction to fail during pool sale
    vm.mockCall(
      address(0),
      abi.encodeWithSignature("state()"),
      abi.encode(uint256(2))
    );

    vm.mockCall(
      address(0),
      abi.encodeWithSignature("totalBuyCouponAmount()"),
      abi.encode(uint256(0))
    );

    // increase indexed asset period - this is done by Pool when Auction starts but its mocked on this test
    _pool.bondToken().increaseIndexedAssetPeriod(params.sharesPerToken);

    vm.expectEmit(true, true, true, true);
    emit Pool.DistributionRollOver(0, 0);

    // Fast forward 5 days
    vm.warp(block.timestamp + 5 days);

    _pool.distribute();
    vm.stopPrank();

    Pool.PoolInfo memory info = _pool.getPoolInfo();
    assertEq(info.currentPeriod, 1);
    assertEq(sharesToken.balanceOf(address(distributor)), 0);
  }

  function testDistributeNoShares() public {
    Token rToken = Token(params.reserveToken);

    vm.startPrank(governance);
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
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
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    vm.stopPrank();
    vm.expectRevert();
    _pool.distribute();
  }

  function testCreateRealistic() public {
    initializeRealisticTestCases();
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets + calcTestCases[i].inAmount);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      setEthPrice(calcTestCases[i].ethPrice);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.createPool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets, "", salt, "", "", false));
      rToken.approve(address(_pool), calcTestCases[i].inAmount);

      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 startReserveBalance = rToken.balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0);
      assertEq(amount, calcTestCases[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 endReserveBalance = rToken.balanceOf(governance);
      assertEq(calcTestCases[i].inAmount, startReserveBalance-endReserveBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
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

  function testRedeemRealistic() public {
    initializeRealisticTestCases();

    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets);
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      setEthPrice(calcTestCases[i].ethPrice);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.createPool(params, calcTestCases[i].TotalUnderlyingAssets, calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets, "", salt, "", "", false));

      uint256 startBalance = rToken.balanceOf(governance);
      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.redeem(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0);
      assertEq(amount, calcTestCases[i].expectedRedeem);

      uint256 endBalance = rToken.balanceOf(governance);
      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      assertEq(amount, endBalance-startBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(calcTestCases[i].inAmount, startBondBalance-endBondBalance);
        assertEq(0, endLevBalance-startLevBalance);
      } else {
        assertEq(0, endBondBalance-startBondBalance);
        assertEq(calcTestCases[i].inAmount, startLevBalance-endLevBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testCreateTokensWithDifferentDecimals() public {
    vm.startPrank(deployer);
    PoolFactory.PoolParams memory _params;
    _params.fee = 0;
    _params.reserveToken = address(new Token("Wrapped ETH", "WETH", false));
    _params.sharesPerToken = 50 * 10 ** 18;
    _params.distributionPeriod = 0;
    _params.couponToken = address(new Token("USDC", "USDC", false));

    OracleFeeds(poolFactory.oracleFeeds()).setPriceFeed(_params.reserveToken, address(0), ethPriceFeed, 1 days);
    
    vm.stopPrank();
    vm.startPrank(governance);

    uint8 reserveDecimals = 6;
    Token(_params.reserveToken).setDecimals(reserveDecimals);

    initializeRealisticTestCases();
    
    Token rToken = Token(_params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) {
        continue;
      }

      // Mint reserve tokens
      rToken.mint(governance, calcTestCases[i].TotalUnderlyingAssets.normalizeAmount(18, reserveDecimals) + calcTestCases[i].inAmount.normalizeAmount(18, reserveDecimals));
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets.normalizeAmount(18, reserveDecimals));

      setEthPrice(calcTestCases[i].ethPrice);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(poolFactory.createPool(_params, calcTestCases[i].TotalUnderlyingAssets.normalizeAmount(18, reserveDecimals), calcTestCases[i].DebtAssets, calcTestCases[i].LeverageAssets, "", salt, "", "", false));
      rToken.approve(address(_pool), calcTestCases[i].inAmount.normalizeAmount(18, reserveDecimals));

      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 startReserveBalance = rToken.balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases[i].assetType, calcTestCases[i].inAmount.normalizeAmount(18, reserveDecimals), 0);
      assertEq(amount, calcTestCases[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 endReserveBalance = rToken.balanceOf(governance);
      assertEq(calcTestCases[i].inAmount.normalizeAmount(18, reserveDecimals), startReserveBalance-endReserveBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
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

  function testClaimFees() public {
    vm.startPrank(governance);

    // Create a pool with 2% fee
    params.fee = 20000; // 2% fee (1000000 precision)
    params.feeBeneficiary = address(0x942);

    // Mint and approve reserve tokens
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 1000 ether);
    rToken.approve(address(poolFactory), 1000 ether);

    Pool pool = Pool(poolFactory.createPool(params, 1000 ether, 500 ether, 250 ether, "", "", "", "", false));

    // Fast forward one year
    vm.warp(block.timestamp + 365 days);

    // Calculate expected fee
    uint256 expectedFee = (1000 ether * 20000) / 1000000; // 2% of 1000 ether

    // Check initial balance of fee beneficiary
    address feeBeneficiary = pool.feeBeneficiary();
    uint256 initialBalance = rToken.balanceOf(feeBeneficiary);
    
    vm.stopPrank();

    // Claim fees
    vm.startPrank(feeBeneficiary);
    pool.claimFees();

    vm.stopPrank();

    // Check final balance of fee beneficiary
    uint256 finalBalance = rToken.balanceOf(feeBeneficiary);

    // Assert that the claimed fee is correct (allowing for small rounding errors)
    assertEq(finalBalance - initialBalance, expectedFee);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(pool), rToken.balanceOf(address(pool)));
  }

  function testClaimFeesNothingToClaim() public {
    vm.startPrank(governance);

    // Create a pool with 2% fee
    params.fee = 20000; // 2% fee (1000000 precision)
    params.feeBeneficiary = address(0x942);

    // Mint and approve reserve tokens
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 1000 ether);
    rToken.approve(address(poolFactory), 1000 ether);

    Pool pool = Pool(poolFactory.createPool(params, 1000 ether, 500 ether, 250 ether, "", "", "", "", false));
    
    vm.stopPrank();

    // Claim fees
    vm.startPrank(params.feeBeneficiary);
    vm.expectRevert(Pool.NoFeesToClaim.selector);
    pool.claimFees();
    vm.stopPrank();

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(pool), rToken.balanceOf(address(pool)));
  }

  function testClaimNotBeneficiary() public {
    vm.startPrank(governance);

    // Create a pool with 2% fee
    params.fee = 20000; // 2% fee (1000000 precision)
    params.feeBeneficiary = address(0x942);

    // Mint and approve reserve tokens
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 1000 ether);
    rToken.approve(address(poolFactory), 1000 ether);

    Pool pool = Pool(poolFactory.createPool(params, 1000 ether, 500 ether, 250 ether, "", "", "", "", false));

    vm.stopPrank();
    vm.startPrank(user);
    
    // Claim fees
    vm.expectRevert(Pool.NotBeneficiary.selector);
    pool.claimFees();

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(pool), rToken.balanceOf(address(pool)));
  }

  function testCreateRedeemWithFees() public {
    vm.startPrank(governance);

    // Create a pool with 2% fee
    params.fee = 20000; // 2% fee (1000000 precision)
    params.feeBeneficiary = address(0x942);

    // Mint and approve reserve tokens
    Token rToken = Token(params.reserveToken);
    rToken.mint(governance, 1000 ether);
    rToken.approve(address(poolFactory), 1000 ether);

    Pool pool = Pool(poolFactory.createPool(params, 1000 ether, 500 ether, 250 ether, "", "", "", "", false));
    vm.stopPrank();

    // User creates leverage tokens
    vm.startPrank(user);
    
    rToken.mint(user, 100 ether);
    rToken.approve(address(pool), 100 ether);
    uint256 levAmount = pool.create(Pool.TokenType.LEVERAGE, 100 ether, 0);
    
    // Advance time by 30 days
    vm.warp(block.timestamp + 30 days);
    
    mockPriceFeed.setMockPrice(3000 * int256(CHAINLINK_DECIMAL_PRECISION), uint8(CHAINLINK_DECIMAL));

    // Calculate expected fee
    uint256 expectedFee = (100 ether * params.fee * 30 days) / (1000000 * 365 days);
    
    // User redeems leverage tokens
    pool.bondToken().approve(address(pool), levAmount);
    uint256 redeemedAmount = pool.redeem(Pool.TokenType.LEVERAGE, levAmount, 0);

    // User should get back less than initial deposit due to fees
    assertLt(redeemedAmount, 100 ether);
    
    // Verify fee amount is correct
    uint256 actualFee = 100 ether - redeemedAmount;
    assertApproxEqRel(actualFee, expectedFee, 0.05e18); // 5% tolerance

    vm.stopPrank();

    // Reset state
    rToken.burn(user, rToken.balanceOf(user));
    rToken.burn(address(pool), rToken.balanceOf(address(pool)));
  }

  function testCreateStaleOraclePrice() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000001000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));

    rToken.approve(address(_pool), 1000);

    // Advance time for oracle price to be stale
    vm.warp(block.timestamp + 1 days + 1);

    // Expect revert due to stale oracle price
    vm.expectRevert(OracleReader.StalePrice.selector);

    // Call create and assert minted tokens
    _pool.create(Pool.TokenType.BOND, 1000, 30000, block.timestamp, governance);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testOracleInvertedPrice() public {
    vm.startPrank(deployer);
    mockPriceFeed.setMockPrice(27887401483629120000, 18);
    vm.stopPrank();

    vm.startPrank(governance);
    // Mint reserve tokens
    Token(params.reserveToken).mint(governance, 10000000000);
    Token(params.reserveToken).approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false));
    uint256 price = _pool.getOraclePrice(_pool.USD(), params.reserveToken);
    assertEq(price, 35858486155012863);

    uint256 price2 = _pool.getOraclePrice(params.reserveToken, _pool.USD());
    assertEq(price2, 27887401483629120000);
  }  
}
