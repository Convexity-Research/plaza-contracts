// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/BondToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BondTokenTest is Test {
  BondToken private token;
  ERC1967Proxy private proxy;
  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private user = address(0x4);
  address private user2 = address(0x5);

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);
    // Deploy and initialize BondToken
    BondToken implementation = new BondToken();

    // Deploy the proxy and initialize the contract through the proxy
    proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(implementation.initialize, ("BondToken", "BOND", minter, governance)));

    // Attach the BondToken interface to the deployed proxy
    token = BondToken(address(proxy));
    vm.stopPrank();
    
    // Mint some initial tokens to the minter for testing
    vm.startPrank(minter);
    token.mint(minter, 1000);
    vm.stopPrank();

    // Increase the indexed asset period for testing
    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(200);
    vm.stopPrank();
  }

  /**
   * @dev Tests minting of tokens by an address with MINTER_ROLE.
   * Asserts that the user's balance is updated correctly.
   */
  function testMinting() public {
    uint256 initialBalance = token.balanceOf(minter);
    uint256 mintAmount = 500;

    vm.startPrank(minter);
    token.mint(user, mintAmount);
    vm.stopPrank();

    assertEq(token.balanceOf(user), mintAmount);
    assertEq(token.balanceOf(minter), initialBalance);
  }

  /**
   * @dev Tests minting of tokens by an address without MINTER_ROLE.
   * Expects the transaction to revert.
   */
  function testMintingWithNoPermission() public {
    uint256 initialBalance = token.balanceOf(user);

    vm.expectRevert();
    vm.startPrank(user);
    token.mint(user, 100);
    vm.stopPrank();

    assertEq(token.balanceOf(user), initialBalance);
  }

  /**
   * @dev Tests burning of tokens by an address with MINTER_ROLE.
   * Asserts that the minter's balance is decreased correctly.
   */
  function testBurning() public {
    uint256 initialBalance = token.balanceOf(minter);
    uint256 burnAmount = 100;

    vm.startPrank(minter);
    token.burn(minter, burnAmount);
    vm.stopPrank();

    assertEq(token.balanceOf(minter), initialBalance - burnAmount);
  }

  /**
   * @dev Tests burning of tokens by an address without MINTER_ROLE.
   * Expects the transaction to revert.
   */
  function testBurningWithNoPermission() public {
    uint256 initialBalance = token.balanceOf(user);

    vm.expectRevert();
    vm.startPrank(user);
    token.burn(user, 50);
    vm.stopPrank();

    assertEq(token.balanceOf(user), initialBalance);
  }

  /**
   * @dev Tests increasing the indexed asset period by an address with GOV_ROLE.
   * Asserts that the globalPool's period and sharesPerToken are updated correctly.
   */
  function testIncreaseIndexedAssetPeriod() public {
    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(5000);
    vm.stopPrank();

    (uint256 currentPeriod, uint256 sharesPerToken) = token.globalPool();
    
    assertEq(currentPeriod, 2);
    assertEq(sharesPerToken, 5000);
  }

  /**
   * @dev Tests increasing the indexed asset period by an address without GOV_ROLE.
   * Expects the transaction to revert.
   */
  function testIncreaseIndexedAssetPeriodWithNoPermission() public {
    vm.expectRevert();
    vm.startPrank(user);
    token.increaseIndexedAssetPeriod(5000);
    vm.stopPrank();
  }

  /**
   * @dev Tests token transfer within the same period without affecting indexed shares.
   * Asserts that the user's lastUpdatedPeriod and indexedAmountShares remain unchanged.
   */
  function testTransferSamePeriod() public {
    vm.startPrank(minter);
    token.mint(user, 1000);
    vm.stopPrank();

    (uint256 lastUpdatedPeriod, uint256 indexedAmountShares) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);

    vm.startPrank(user);
    token.transfer(user2, 100);
    vm.stopPrank();

    (lastUpdatedPeriod, indexedAmountShares) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);
  }

  /**
   * @dev Tests token transfer after an indexed asset period increase.
   * Asserts the updates to user assets and global pool data.
   */
  function testTransferAfterPeriodIncrease() public {
    vm.startPrank(minter);
    token.mint(user, 1000);
    vm.stopPrank();

    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(200);
    vm.stopPrank();

    (uint256 lastUpdatedPeriod, uint256 indexedAmountShares) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);

    (lastUpdatedPeriod, indexedAmountShares) = token.globalPool();
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 200);

    vm.startPrank(user);
    token.transfer(user2, 100);
    vm.stopPrank();

    // User1
    (lastUpdatedPeriod, indexedAmountShares) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 20);
    assertEq(token.balanceOf(user), 900);

    // User2
    (lastUpdatedPeriod, indexedAmountShares) = token.userAssets(user2);
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 0);
    assertEq(token.balanceOf(user2), 100);
  }

  /**
   * @dev Tests token transfer after an indexed asset period increase with both users receiving shares.
   * Asserts the updates to both users' assets and global pool data.
   */
  function testTransferAfterPeriodIncreaseBothUsersPaid() public {
    vm.startPrank(minter);
    token.mint(user, 1000);
    token.mint(user2, 2000);
    vm.stopPrank();

    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(200);
    vm.stopPrank();

    (uint256 lastUpdatedPeriod, uint256 indexedAmountShares) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);

    (lastUpdatedPeriod, indexedAmountShares) = token.globalPool();
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 200);

    vm.startPrank(user);
    token.transfer(user2, 100);
    vm.stopPrank();

    // User1
    (lastUpdatedPeriod, indexedAmountShares) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 20);
    assertEq(token.balanceOf(user), 900);

    // User2
    (lastUpdatedPeriod, indexedAmountShares) = token.userAssets(user2);
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 40);
    assertEq(token.balanceOf(user2), 2100);
  }
}
