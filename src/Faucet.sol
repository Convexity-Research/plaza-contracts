// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Token} from "../test/mocks/Token.sol";

/// @title Faucet
/// @notice A contract for distributing test tokens
/// @dev This contract creates and distributes two types of ERC20 tokens for testing purposes
contract Faucet {
  /// @notice The reserve token (WETH)
  Token public reserveToken;
  /// @notice The coupon token (USDC)
  Token public couponToken;
  /// @notice The address of the deployer
  address private deployer;
  /// @notice A mapping to track whitelisted addresses
  mapping(address => bool) private whitelist;

  /// @notice Initializes the contract by creating new instances of reserve and coupon tokens
  constructor() {
    deployer = msg.sender;
    whitelist[deployer] = true;
    reserveToken = new Token("Wrapped fake liquid staked Ether 2.0", "wstETH", true);
    couponToken = new Token("Circle Fake USD", "USDC", true);
  }
  
  /// @notice Distributes a fixed amount of both reserve and coupon tokens to the caller
  /// @dev Mints 1 WETH and 5000 USDC to the caller's address
  function faucet() public isWhitelisted() {
    reserveToken.mint(msg.sender, 1 ether);
    couponToken.mint(msg.sender, 5000 ether);
  }

  /// @notice Distributes a specified amount of both reserve and coupon tokens to the caller
  /// @param amountReserve The amount of reserve tokens to mint
  /// @param amountCoupon The amount of coupon tokens to mint
  function faucet(uint256 amountReserve, uint256 amountCoupon) public isWhitelisted() {
    reserveToken.mint(msg.sender, amountReserve);
    couponToken.mint(msg.sender, amountCoupon);
  }

  /// @notice Distributes a specified amount of reserve tokens to the caller
  /// @param amount The amount of reserve tokens to mint
  function faucetReserve(uint256 amount) public isWhitelisted() {
    reserveToken.mint(msg.sender, amount);
  }

  /// @notice Distributes a specified amount of coupon tokens to the caller
  /// @param amount The amount of coupon tokens to mint
  function faucetCoupon(uint256 amount) public isWhitelisted() {
    couponToken.mint(msg.sender, amount);
  }

  /// @notice Adds an address to the whitelist
  /// @param account The address to add to the whitelist
  function addToWhitelist(address account) public isWhitelisted() {
    whitelist[account] = true;
  }

  modifier isWhitelisted() {
    require(whitelist[msg.sender], "Not whitelisted");
    _;
  }
}
