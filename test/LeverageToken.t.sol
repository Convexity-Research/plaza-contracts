// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/LeverageToken.sol";
import {Utils} from "../src/lib/Utils.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract LeverageTokenTest is Test {
  LeverageToken private token;
  ERC1967Proxy private proxy;
  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private user = address(0x4);
  address private user2 = address(0x5);
  address private securityCouncil = address(0x6);
  
  PoolFactory private poolFactory;

  /**
   * @dev Sets up the testing environment.
   * Deploys the LeverageToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(governance);
    poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize, 
      (governance, address(0), address(0), address(0), address(0), address(0), address(0))
    )));

    poolFactory.grantRole(poolFactory.SECURITY_COUNCIL_ROLE(), securityCouncil);
    vm.stopPrank();
  
    vm.startPrank(deployer);
    // Deploy and initialize LeverageToken
    LeverageToken implementation = new LeverageToken();

    // Deploy the proxy and initialize the contract through the proxy
    proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(implementation.initialize, ("LeverageToken", "LEVR", minter, governance, address(poolFactory))));

    // Attach the LeverageToken interface to the deployed proxy
    token = LeverageToken(address(proxy));
    vm.stopPrank();

    // Mint some initial tokens to the minter for testing
    vm.startPrank(minter);
    token.mint(minter, 1000);
    vm.stopPrank();
  }

  function testPause() public {
    // makes sure it starts false
    assertEq(token.paused(), false);

    // makes sure minting works if not paused
    vm.startPrank(minter);
    token.mint(user, 1000);

    // pause contract
    vm.startPrank(securityCouncil);
    token.pause();

    // check it reverts on minting
    vm.startPrank(minter);
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.mint(user, 1);

    // check it reverts on burning
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.burn(user, 1);

    // check it reverts on transfer
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.transfer(user, 1);

    // @todo: check if contract is still upgradable on pause
    // token._authorizeUpgrade(address(0));

    // unpause contract
    vm.startPrank(securityCouncil);
    token.unpause();

    // make sure you can now do stuff
    vm.startPrank(user);
    token.transfer(user2, 1000);
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
}
