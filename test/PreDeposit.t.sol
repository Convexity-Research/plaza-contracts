// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {BondToken} from "../src/BondToken.sol";
import {PreDeposit} from "../src/PreDeposit.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {MockPoolFactory} from "./mocks/MockPoolFactory.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract PreDepositTest is Test {
  PreDeposit public preDeposit;
  address public factory;
  Token public reserveToken;
  Token public couponToken;

  address owner = address(1);
  address user1 = address(2);
  address user2 = address(3);
  address nonOwner = address(4);

  uint256 constant INITIAL_BALANCE = 1000 ether;
  uint256 constant RESERVE_CAP = 100 ether;
  uint256 constant DEPOSIT_AMOUNT = 10 ether;
  uint256 constant BOND_AMOUNT = 50 ether;
  uint256 constant LEVERAGE_AMOUNT = 50 ether;

  function setUp() public { 
    vm.startPrank(owner);
    
    reserveToken = new Token("Wrapped ETH", "WETH", false);
    couponToken = new Token("USDC", "USDC", false);

    PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(reserveToken),
      couponToken: address(couponToken),
      distributionPeriod: 90 days,
      sharesPerToken: 2 * 10**6,
      feeBeneficiary: address(0)
    });
    
    factory = address(new MockPoolFactory());
    preDeposit = PreDeposit(Utils.deploy(address(new PreDeposit()), abi.encodeCall(PreDeposit.initialize, (
      params,
      factory,
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

  function deployFakePool() public returns(address, address, address) {
    BondToken bondToken = BondToken(Utils.deploy(address(new BondToken()), abi.encodeCall(BondToken.initialize, (
      "", "", owner, owner, owner, 0
    ))));
    
    LeverageToken lToken = LeverageToken(Utils.deploy(address(new LeverageToken()), abi.encodeCall(LeverageToken.initialize, (
      "", "", owner, owner
    ))));

    Pool pool = Pool(Utils.deploy(address(new Pool()), abi.encodeCall(Pool.initialize, 
      (factory, 0, address(reserveToken), address(bondToken), address(lToken), address(couponToken), 0, 0, address(0), address(0))
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
      factory,
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
    vm.startPrank(owner);
    PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(reserveToken),
      couponToken: address(couponToken),
      distributionPeriod: 90 days,
      sharesPerToken: 2 * 10**6,
      feeBeneficiary: address(0)
    });

    PreDeposit newPreDeposit = PreDeposit(Utils.deploy(address(new PreDeposit()), abi.encodeCall(PreDeposit.initialize, (
      params,
      factory,
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
    
    vm.expectRevert(PreDeposit.WithdrawEnded.selector);
    preDeposit.withdraw(DEPOSIT_AMOUNT);
    vm.stopPrank();
  }

  // Pool Creation Tests
  function testCreatePool() public {
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    vm.startPrank(owner);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days); // After deposit period
    preDeposit.createPool();
    assertNotEq(preDeposit.pool(), address(0));
    vm.stopPrank();
  }

  function testCreatePoolNoReserveAmount() public {
    vm.startPrank(owner);
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

    vm.startPrank(owner);
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

    vm.startPrank(owner);
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

    vm.startPrank(owner);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days); // After deposit period
    preDeposit.createPool();

    // Try to create pool again
    vm.expectRevert(PreDeposit.PoolAlreadyCreated.selector);
    preDeposit.createPool();
    vm.stopPrank();
  }

  function testClaim() public {
    (address pool, address bondToken, address lToken) = deployFakePool();

    // Setup initial deposit
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    // Create pool
    vm.startPrank(owner);
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

    vm.startPrank(owner);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    vm.warp(block.timestamp + 8 days);
    preDeposit.createPool();
    vm.stopPrank();

    // Try to claim with user2 who has no deposits
    vm.startPrank(user2);
    vm.expectRevert(PreDeposit.NothingToClaim.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testClaimTwice() public {
    (address pool, address bondToken, address lToken) = deployFakePool();

    // Setup initial deposit
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    // Create pool
    vm.startPrank(owner);
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
    vm.startPrank(owner);
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
    vm.prank(owner);
    preDeposit.increaseReserveCap(RESERVE_CAP * 2);
    assertEq(preDeposit.reserveCap(), RESERVE_CAP * 2);
  }

  function testIncreaseReserveCapDecrease() public {
    vm.prank(owner);
    vm.expectRevert(PreDeposit.CapMustIncrease.selector);
    preDeposit.increaseReserveCap(RESERVE_CAP / 2);
  }

  // Time-related Tests
  function testSetDepositStartTime() public {
    uint256 newStartTime = block.timestamp + 1 days;
    vm.prank(owner);
    preDeposit.setDepositStartTime(newStartTime);
    assertEq(preDeposit.depositStartTime(), newStartTime);
  }

  function testSetDepositEndTime() public {
    uint256 newEndTime = block.timestamp + 14 days;
    vm.prank(owner);
    preDeposit.setDepositEndTime(newEndTime);
    assertEq(preDeposit.depositEndTime(), newEndTime);
  }

  // Pause/Unpause Tests
  function testPauseUnpause() public {
    vm.startPrank(owner);
    preDeposit.pause();
    
    vm.startPrank(user1);
    reserveToken.approve(address(preDeposit), DEPOSIT_AMOUNT);

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    
    vm.startPrank(owner);
    preDeposit.unpause();
    
    vm.startPrank(user1);
    preDeposit.deposit(DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user1), DEPOSIT_AMOUNT);
  }
}
