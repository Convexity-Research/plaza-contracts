// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Token} from "../test/mocks/Token.sol";

/// @title Faucet
/// @notice A contract for distributing test tokens
/// @dev This contract creates and distributes two types of ERC20 tokens for testing purposes
contract Faucet {
  /// @notice The reserve token (WETH)
  Token public wstETH;
  /// @notice The second reserve token (CBETH)
  Token public cbETH;
  /// @notice The coupon token (USDC)
  Token public couponToken;
  /// @notice The address of the deployer
  address private deployer;
  /// @notice A mapping to track whitelisted addresses
  mapping(address => bool) private whitelist;

  /// @notice Initializes the contract by creating new instances of reserve and coupon tokens
  constructor(address _wstETH, address _cbETH, address _couponToken) {
    deployer = msg.sender;
    whitelist[deployer] = true;

    if (_wstETH != address(0)) {
      wstETH = Token(_wstETH);
    } else {
      wstETH = new Token("Wrapped fake liquid staked Ether 2.0", "wstETH", true);
    }

    if (_cbETH != address(0)) {
      cbETH = Token(_cbETH);
    } else {
      cbETH = new Token("Coinbase Wrapped Fake Staked ETH", "cbETH", true);
    }

    if (_couponToken != address(0)) {
      couponToken = Token(_couponToken);
    } else {
      couponToken = new Token("Circle Fake USD", "USDC", true);
    }
  }
  
  /// @notice Distributes a fixed amount of both reserve and coupon tokens to the caller
  /// @dev Mints 1 WETH and 5000 USDC to the caller's address
  function faucet() public isWhitelisted() {
    wstETH.mint(msg.sender, 1 ether);
    cbETH.mint(msg.sender, 1 ether);
    couponToken.mint(msg.sender, 5000 ether);
  }

  /// @notice Distributes a specified amount of both reserve and coupon tokens to the caller
  /// @param amountWstETH The amount of WstETH to mint
  /// @param amountCbETH The amount of cbETH to mint
  /// @param amountCoupon The amount of coupon tokens to mint
  /// @param amountEth The amount of ETH to send to the caller
  /// @param onBehalfOf The address to mint the tokens on behalf of
  function faucet(uint256 amountWstETH, uint256 amountCbETH, uint256 amountCoupon, uint256 amountEth, address onBehalfOf) public isWhitelisted() {
    address user = onBehalfOf == address(0) ? msg.sender : onBehalfOf;
    if (amountWstETH > 0) {
      wstETH.mint(user, amountWstETH);
    }
    if (amountCbETH > 0) {
      cbETH.mint(user, amountCbETH);
    }
    if (amountCoupon > 0) {
      couponToken.mint(user, amountCoupon);
    }
    if (amountEth > 0) {
      (bool success, ) = payable(user).call{value: amountEth}("");
      require(success, "Faucet: ETH transfer failed");
    }
  }

  /// @notice Distributes a specified amount of both reserve and coupon tokens to the caller
  /// @param amountWstETH The amount of WstETH to mint
  /// @param amountCbETH The amount of cbETH to mint
  /// @param amountCoupon The amount of coupon tokens to mint
  /// @param amountEth The amount of ETH to send to the caller
  /// @param users The addresses to mint the tokens on behalf of
  function faucet(uint256 amountWstETH, uint256 amountCbETH, uint256 amountCoupon, uint256 amountEth, address[] memory users) public isWhitelisted() {
    for (uint256 i = 0; i < users.length; i++) {
      address user = users[i];
      faucet(amountWstETH, amountCbETH, amountCoupon, amountEth, user);
    }
  }

  /// @notice Distributes a specified amount of reserve tokens to the caller
  /// @param amount The amount of reserve tokens to mint
  /// @param onBehalfOf The address to mint the tokens on behalf of
  function faucetReserve(uint256 amount, address onBehalfOf) public isWhitelisted() {
    address user = onBehalfOf == address(0) ? msg.sender : onBehalfOf;
    wstETH.mint(user, amount);
  }

  /// @notice Distributes a specified amount of coupon tokens to the caller
  /// @param amount The amount of coupon tokens to mint
  /// @param onBehalfOf The address to mint the tokens on behalf of
  function faucetCoupon(uint256 amount, address onBehalfOf) public isWhitelisted() {
    address user = onBehalfOf == address(0) ? msg.sender : onBehalfOf;
    couponToken.mint(user, amount);
  }

  /// @notice Adds an address to the whitelist
  /// @param account The address to add to the whitelist
  function addToWhitelist(address account) public isWhitelisted() {
    whitelist[account] = true;
  }

  /// @notice Fallback function to receive ETH
  receive() external payable {}

  modifier isWhitelisted() {
    require(whitelist[msg.sender], "Not whitelisted");
    _;
  }
}
