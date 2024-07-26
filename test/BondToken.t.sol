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

    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(200);
    vm.stopPrank();
  }
function testMinting() public {
    uint256 initialBalance = token.balanceOf(minter);
    uint256 mintAmount = 500;

    vm.startPrank(minter);
    token.mint(user, mintAmount);
    vm.stopPrank();

    assertEq(token.balanceOf(user), mintAmount);
    assertEq(token.balanceOf(minter), initialBalance);
  }

  function testMintingWithNoPermission() public {
    uint256 initialBalance = token.balanceOf(user);

     // MINTER_ROLE
    vm.expectRevert();
    vm.startPrank(user);
    token.mint(user, 100);
    vm.stopPrank();

    assertEq(token.balanceOf(user), initialBalance);
  }

  function testBurning() public {
    uint256 initialBalance = token.balanceOf(minter);
    uint256 burnAmount = 100;

    vm.startPrank(minter);
    token.burn(minter, burnAmount);
    vm.stopPrank();

    assertEq(token.balanceOf(minter), initialBalance - burnAmount);
  }

  function testBurningWithNoPermission() public {
    uint256 initialBalance = token.balanceOf(user);

    // MINTER_ROLE
    vm.expectRevert();
    vm.startPrank(user);
    token.burn(user, 50);
    vm.stopPrank();

    assertEq(token.balanceOf(user), initialBalance);
  }

  function testIncreaseIndexedAssetPeriod() public {
    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(5000);
    vm.stopPrank();

    (uint256 currentPeriod, uint256 sharesPerToken) = token.globalPool();
    
    assertEq(currentPeriod, 2);
    assertEq(sharesPerToken, 5000);
  }

  function testIncreaseIndexedAssetPeriodWithNoPermission() public {
    // GOV_ROLE
    vm.expectRevert();
    vm.startPrank(user);
    token.increaseIndexedAssetPeriod(5000);
    vm.stopPrank();
  }

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
