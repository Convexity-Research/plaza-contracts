// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {Decimals} from "./lib/Decimals.sol";
import {Token} from "../test/mocks/Token.sol";
import {OracleReader} from "./OracleReader.sol";

// Testnet contract that replaces the real Router contract on testnet
// Out of the scope of an audit
contract Router is OracleReader {
  using Decimals for uint256;

  Token public reserveToken = Token(0xE46230A4963b8bBae8681b5c05F8a22B9469De18);
  Token public couponToken = Token(0xDA1334a1084170eb1438E0d9d5C8799A07fbA7d3);

  function swapAndCreate(address _pool,
    address depositToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount) external returns (uint256) {
    return swapCreate(_pool, depositToken, tokenType, depositAmount, minAmount, block.timestamp, msg.sender);
  }

  function swapCreate(address _pool,
    address depositToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf) public returns (uint256) {
    require(depositToken == address(couponToken), "invalid deposit token, only accepts fake USDC");

    // Transfer depositAmount of depositToken from user to contract
    require(couponToken.transferFrom(msg.sender, address(this), depositAmount), "Transfer failed");

    // Get ETH price from OracleReader
    uint256 ethPrice = getOraclePrice(address(reserveToken));

    // Calculate the amount of reserveToken based on the price
    uint256 reserveAmount = depositAmount / ethPrice.normalizeAmount(getOracleDecimals(address(reserveToken)), couponToken.decimals());
    reserveAmount = reserveAmount.normalizeAmount(couponToken.decimals(), reserveToken.decimals());

    // Burn depositAmount from contract
    couponToken.burn(address(this), depositAmount);

    // Mint reserveToken to contract
    reserveToken.mint(address(this), reserveAmount);

    // Approve reserveToken to pool
    require(reserveToken.approve(_pool, reserveAmount), "Approval failed");

    if (onBehalfOf == address(0)) {
      onBehalfOf = msg.sender;
    }

    // Call create on pool
    return Pool(_pool).create(tokenType, reserveAmount, minAmount, deadline, onBehalfOf);
  }

  function redeemSwap(address _pool,
    address redeemToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount) external returns (uint256) {
    return redeemSwap(_pool, redeemToken, tokenType, depositAmount, minAmount, block.timestamp, msg.sender);
  }

  function redeemSwap(address _pool,
    address redeemToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf) public returns (uint256) {
    require(redeemToken == address(couponToken), "invalid redeem token, only accepts fake USDC");

    // Transfer depositAmount of depositToken from user to contract
    require(couponToken.transferFrom(msg.sender, address(this), depositAmount), "Transfer failed");

    // Get ETH price from OracleReader
    uint256 ethPrice = getOraclePrice(address(reserveToken));

    // Calculate the amount of reserveToken based on the price
    uint256 reserveAmount = depositAmount / ethPrice.normalizeAmount(getOracleDecimals(address(reserveToken)), couponToken.decimals());
    reserveAmount = reserveAmount.normalizeAmount(couponToken.decimals(), reserveToken.decimals());

    // Burn depositAmount from contract
    couponToken.burn(address(this), depositAmount);

    // Mint reserveToken to contract
    reserveToken.mint(address(this), reserveAmount);

    // Approve reserveToken to pool
    require(reserveToken.approve(_pool, reserveAmount), "Approval failed");

    if (onBehalfOf == address(0)) {
      onBehalfOf = msg.sender;
    }

    // Call create on pool
    return Pool(_pool).redeem(tokenType, reserveAmount, minAmount, deadline, onBehalfOf);
  }
}
