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

  /// @notice Initializes the contract by creating new instances of reserve and coupon tokens
  constructor() {
    reserveToken = new Token("Wrapped Fake ETH", "WETH");
    couponToken = new Token("Circle Fake USD", "USDC");
  }
  
  /// @notice Distributes a fixed amount of both reserve and coupon tokens to the caller
  /// @dev Mints 1 WETH and 5000 USDC to the caller's address
  function faucet() public {
    reserveToken.mint(msg.sender, 1 ether);
    couponToken.mint(msg.sender, 5000 ether);
  }

  /// @notice Distributes a specified amount of both reserve and coupon tokens to the caller
  /// @param amountReserve The amount of reserve tokens to mint
  /// @param amountCoupon The amount of coupon tokens to mint
  function faucet(uint256 amountReserve, uint256 amountCoupon) public {
    reserveToken.mint(msg.sender, amountReserve);
    couponToken.mint(msg.sender, amountCoupon);
  }

  /// @notice Distributes a specified amount of reserve tokens to the caller
  /// @param amount The amount of reserve tokens to mint
  function faucetReserve(uint256 amount) public {
    reserveToken.mint(msg.sender, amount);
  }

  /// @notice Distributes a specified amount of coupon tokens to the caller
  /// @param amount The amount of coupon tokens to mint
  function faucetCoupon(uint256 amount) public {
    couponToken.mint(msg.sender, amount);
  }
}
