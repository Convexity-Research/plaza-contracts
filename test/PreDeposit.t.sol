// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {BondToken} from "../src/BondToken.sol";
import {PreDeposit} from "../src/PreDeposit.sol";
import {Distributor} from "../src/Distributor.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract PreDepositTest is Test {
  PreDeposit public preDeposit;
  Token public reserveToken;
  Token public couponToken;

  address user1 = address(2);
  address user2 = address(3);
  address nonOwner = address(4);

  PoolFactory private poolFactory;
  PoolFactory.PoolParams private params;
  Distributor private distributor;

  address private deployer = address(0x5);
  address private minter = address(0x6);
  address private governance = address(0x7);
  
  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);

  uint256 constant INITIAL_BALANCE = 1000 ether;
  uint256 constant RESERVE_CAP = 100 ether;
  uint256 constant DEPOSIT_AMOUNT = 10 ether;
  uint256 constant BOND_AMOUNT = 50 ether;
  uint256 constant LEVERAGE_AMOUNT = 50 ether;

  function setUp() public { 
    // Set block time to 10 days in the future to avoid block.timestamp to start from 0
    vm.warp(block.timestamp + 10 days);

    vm.startPrank(governance);
    
    reserveToken = new Token("Wrapped ETH", "WETH", false);
    couponToken = new Token("USDC", "USDC", false);
    vm.stopPrank();

    setUp_PoolFactory();

    vm.startPrank(governance);

    params = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(reserveToken),
      couponToken: address(couponToken),
      distributionPeriod: 90 days,
      sharesPerToken: 2 * 10**6,
      feeBeneficiary: address(0)
    });
    
    preDeposit = PreDeposit(Utils.deploy(address(new PreDeposit()), abi.encodeCall(PreDeposit.initialize, (
      params,
      address(poolFactory),
      block.timestamp,
      block.timestamp + 7 days,
      RESERVE_CAP,
      "",
      "", 
      "",
      ""
    ))));

    reserveToken.mint(user1, INITIAL_BALANCE);
    reserveToken.mint(user2, INITIAL_BALANCE);
    
    vm.stopPrank();
  }

  function setUp_PoolFactory() internal {
    vm.startPrank(deployer);

    address contractDeployer = address(new Deployer());
    
    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));

    poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize, 
      (governance, contractDeployer, ethPriceFeed, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
    )));

    vm.stopPrank();
  }

  function deployFakePool() public returns(address, address, address) {
    BondToken bondToken = BondToken(Utils.deploy(address(new BondToken()), abi.encodeCall(BondToken.initialize, (
      "", "", governance, governance, address(poolFactory), 0
    ))));
    
    LeverageToken lToken = LeverageToken(Utils.deploy(address(new LeverageToken()), abi.encodeCall(LeverageToken.initialize, (
      "", "", governance, governance, address(poolFactory)
    ))));

    Pool pool = Pool(Utils.deploy(address(new Pool()), abi.encodeCall(Pool.initialize, 
      (address(poolFactory), 0, address(reserveToken), address(bondToken), address(lToken), address(couponToken), 0, 0, address(0), address(0), false)
    )));

    // Adds fake pool to preDeposit contract
    uint256 poolSlot = 0;
    vm.store(address(preDeposit), bytes32(poolSlot), bytes32(uint256(uint160(address(pool)))));
    return (address(pool), address(bondToken), address(lToken));
  }

  function resetReentrancy(address contractAddress) public {
    // Reset `_status` to allow the next call
    vm.store(
      contractAddress,
      bytes32(0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00), // Storage slot for `_status`
      bytes32(uint256(1))  // Reset to `_NOT_ENTERED`
    );
  }

  // Initialization Tests
  function testInitializeWithZeroReserveToken() public {
    PoolFactory.PoolParams memory invalidParams = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(0),
      couponToken: address(couponToken),
      distributionPeriod: 90 days,
      sharesPerToken: 2 * 10**6,
      feeBeneficiary: address(0)
    });

    address preDepositAddress = address(new PreDeposit());

    vm.expectRevert(PreDeposit.InvalidReserveToken.selector);
    Utils.deploy(preDepositAddress, abi.encodeCall(PreDeposit.initialize, (
      invalidParams,
      address(poolFactory),
      block.timestamp,
      block.timestamp + 7 days,
      RESERVE_CAP,
      "",
      "",
      "",
      ""
    )));
  }

  // Deposit Tests
  function testDeposit() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    
    assertEq(preDeposit.balances(user1), DEPOSIT_AMOUNT);
    assertEq(preDeposit.reserveAmount(), DEPOSIT_AMOUNT);
    vm.stopPrank();
  }

  function testDepositBeforeStart() public {
    // Setup new predeposit with future start time
    vm.startPrank(governance);
    params = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(reserveToken),
      couponToken: address(couponToken),
      distributionPeriod: 90 days,
      sharesPerToken: 2 * 10**6,
      feeBeneficiary: address(0)
    });

    PreDeposit newPreDeposit = PreDeposit(Utils.deploy(address(new PreDeposit()), abi.encodeCall(PreDeposit.initialize, (
      params,
      address(poolFactory),
      block.timestamp + 1 days, // Start time in future
      block.timestamp + 7 days,
      RESERVE_CAP,
      "",
      "",
      "",
      ""
    ))));
    vm.stopPrank();

    vm.startPrank(user1);
    reserveToken.approve(address(newPreDeposit), DEPOSIT_AMOUNT);

    vm.expectRevert(PreDeposit.DepositNotYetStarted.selector);
    newPreDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();
  }

  function testDepositAfterEnd() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    
    vm.warp(block.timestamp + 8 days); // After deposit period
    
    vm.expectRevert(PreDeposit.DepositEnded.selector);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();
  }

  // Withdraw Tests
  function testWithdraw() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    
    uint256 balanceBefore = reserveToken.balanceOf(user1);
    preDeposit.withdraw(DEPOSIT_AMOUNT);
    uint256 balanceAfter = reserveToken.balanceOf(user1);
    
    assertEq(balanceAfter - balanceBefore, DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user1), 0);
    assertEq(preDeposit.reserveAmount(), 0);
    vm.stopPrank();
  }

  function testWithdrawAfterDepositEnd() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    
    vm.warp(block.timestamp + 8 days); // After deposit period
    
    vm.expectRevert(PreDeposit.DepositEnded.selector);
    preDeposit.withdraw(DEPOSIT_AMOUNT);
    vm.stopPrank();
  }

  // Pool Creation Tests
  function testCreatePool() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days); // After deposit period

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    preDeposit.createPool();
    assertNotEq(preDeposit.pool(), address(0));
    vm.stopPrank();
  }

  function testCreatePoolNoReserveAmount() public {
    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days);

    vm.expectRevert(PreDeposit.NoReserveAmount.selector);
    preDeposit.createPool();
    vm.stopPrank();
  }

  function testCreatePoolInvalidBondOrLeverageAmount() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(block.timestamp + 8 days); // After deposit period

    vm.expectRevert(PreDeposit.InvalidBondOrLeverageAmount.selector);
    preDeposit.createPool();
    vm.stopPrank();
  }

  function testCreatePoolBeforeDepositEnd() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    resetReentrancy(address(preDeposit));

    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    // Check that the deposit end time is still in the future
    assertGt(preDeposit.depositEndTime(), block.timestamp, "Deposit period has ended");

    vm.expectRevert(PreDeposit.DepositNotEnded.selector);
    preDeposit.createPool();
  }

  function testCreatePoolAfterCreation() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days); // After deposit period

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    preDeposit.createPool();

    // Try to create pool again
    vm.expectRevert(PreDeposit.PoolAlreadyCreated.selector);
    preDeposit.createPool();
    vm.stopPrank();
  }

  function testClaim() public {
    (, address bondToken, address lToken) = deployFakePool();

    // Setup initial deposit
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days); // After deposit period

    // fake bond/lev to predeposit contract, simulating a pool created
    BondToken(bondToken).mint(address(preDeposit), 10000 ether);
    LeverageToken(lToken).mint(address(preDeposit), 10000 ether);

    vm.stopPrank();

    // Claim tokens
    vm.startPrank(user1);
    uint256 balanceBefore = preDeposit.balances(user1);
    preDeposit.claim();
    uint256 balanceAfter = preDeposit.balances(user1);
    
    // Verify balances were updated
    assertEq(balanceAfter, 0);
    assertLt(balanceAfter, balanceBefore);
    
    assertGt(BondToken(bondToken).balanceOf(user1), 0);
    assertGt(LeverageToken(lToken).balanceOf(user1), 0);
    vm.stopPrank();
  }

  function testClaimBeforeDepositEnd() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);

    vm.expectRevert(PreDeposit.DepositNotEnded.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testClaimBeforePoolCreation() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    vm.warp(block.timestamp + 8 days); // After deposit period

    vm.startPrank(user1);
    vm.expectRevert(PreDeposit.ClaimPeriodNotStarted.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testClaimWithZeroBalance() public {
    // Create pool first
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    preDeposit.createPool();
    vm.stopPrank();

    // Try to claim with user2 who has no deposits
    vm.startPrank(user2);
    vm.expectRevert(PreDeposit.NothingToClaim.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testClaimTwice() public {
    (, address bondToken, address lToken) = deployFakePool();

    // Setup initial deposit
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days);
    
    // fake bond/lev to predeposit contract, simulating a pool created
    BondToken(bondToken).mint(address(preDeposit), 10000 ether);
    LeverageToken(lToken).mint(address(preDeposit), 10000 ether);

    vm.stopPrank();

    // First claim should succeed
    vm.startPrank(user1);
    preDeposit.claim();

    // Second claim should fail
    vm.expectRevert(PreDeposit.NothingToClaim.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  // Admin Function Tests
  function testSetParams() public {
    vm.startPrank(governance);
    PoolFactory.PoolParams memory newParams = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(reserveToken),
      couponToken: address(couponToken),
      distributionPeriod: 180 days,
      sharesPerToken: 3 * 10**6,
      feeBeneficiary: address(0)
    });
    preDeposit.setParams(newParams);
    vm.stopPrank();
  }

  function testSetParamsNonOwner() public {
    vm.startPrank(nonOwner);
    PoolFactory.PoolParams memory newParams = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(reserveToken),
      couponToken: address(couponToken),
      distributionPeriod: 180 days,
      sharesPerToken: 3 * 10**6,
      feeBeneficiary: address(0)
    });

    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
    preDeposit.setParams(newParams);
    vm.stopPrank();
  }

  function testIncreaseReserveCap() public {
    vm.prank(governance);
    preDeposit.increaseReserveCap(RESERVE_CAP * 2);
    assertEq(preDeposit.reserveCap(), RESERVE_CAP * 2);
  }

  function testIncreaseReserveCapDecrease() public {
    vm.prank(governance);
    vm.expectRevert(PreDeposit.CapMustIncrease.selector);
    preDeposit.increaseReserveCap(RESERVE_CAP / 2);
  }

  // Time-related Tests
  function testSetDepositStartTime() public {
    // Move time to before deposit start time
    vm.warp(block.timestamp - 1 days);

    uint256 newStartTime = preDeposit.depositStartTime() + 10 hours;
    vm.prank(governance);
    preDeposit.setDepositStartTime(newStartTime);
    assertEq(preDeposit.depositStartTime(), newStartTime);
  }

  function testSetDepositEndTime() public {
    uint256 newEndTime = block.timestamp + 14 days;
    vm.prank(governance);
    preDeposit.setDepositEndTime(newEndTime);
    assertEq(preDeposit.depositEndTime(), newEndTime);
  }

  // Pause/Unpause Tests
  function testPauseUnpause() public {
    vm.startPrank(governance);
    preDeposit.pause();
    
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    
    vm.startPrank(governance);
    preDeposit.unpause();
    
    vm.startPrank(user1);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user1), DEPOSIT_AMOUNT);
  }

  function testClaimTwoUsersSameBondShare() public {
    // Setup initial deposit
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();
    vm.startPrank(user2);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    vm.warp(block.timestamp + 8 days); // After deposit period

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    preDeposit.createPool();
    vm.stopPrank();

    // Claim tokens
    address bondToken = address(Pool(preDeposit.pool()).bondToken());
    
    vm.prank(user1);
    preDeposit.claim();
    
    vm.prank(user2);
    preDeposit.claim();
    
    uint256 user1_bond_share = BondToken(bondToken).balanceOf(user1);
    uint256 user2_bond_share = BondToken(bondToken).balanceOf(user2);
    assertEq(user1_bond_share, user2_bond_share);
    assertEq(user1_bond_share, 25 ether);
  }

  function testTimingAttack() public {
    // Setup initial deposit
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();
    vm.startPrank(user2);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    vm.warp(block.timestamp + 7 days); // depositEndTime

    // Start timing attack
    vm.startPrank(user1);

    // user1 trigger createPool, it's allowed because it's not onlyOwner
    preDeposit.createPool();
    
    // user1 trigger claim
    preDeposit.claim();
    
    reserveToken.approve(address(preDeposit), 10);

    // deposit not possible at the same block as createPool
    vm.expectRevert(PreDeposit.DepositEnded.selector);
    preDeposit.deposit(10);
    vm.stopPrank();
  }

  function testExtendStartTimeAfterStartReverts() public {
    // user can deposit
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    // Extend start time
    vm.prank(governance);
    vm.expectRevert(PreDeposit.DepositAlreadyStarted.selector);
    preDeposit.setDepositStartTime(block.timestamp + 1 days);
  }

  function testPoolPausedOnCreation() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days); // After deposit period
    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    vm.recordLogs();
    preDeposit.createPool();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    
    Pool pool = Pool(address(uint160(uint256(entries[entries.length - 1].topics[1])))); // last log is the pool created address
    assertEq(pool.paused(), true);
    vm.stopPrank();
  }
}
