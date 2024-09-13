// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {Decimals} from "./lib/Decimals.sol";
import {Token} from "../test/mocks/Token.sol";
import {OracleReader} from "./OracleReader.sol";

/**
 * @title Router
 * @dev Testnet contract that replaces the real Router contract on testnet.
 * @dev *******This contract is out of the scope of an audit.*******
 */
contract Router is OracleReader {

  /**
   * @dev Error thrown when the minimum amount condition is not met.
   */
  error MinAmount();

  using Decimals for uint256;

  /**
   * @dev Constructor that initializes the OracleReader with the ETH price feed.
   * @param _ethPriceFeed The address of the ETH price feed.
   */
  constructor(address _ethPriceFeed) {
    __OracleReader_init(_ethPriceFeed);
  }

  /**
   * @dev Swaps and creates tokens in a pool.
   * @param _pool The address of the pool.
   * @param depositToken The address of the token to deposit.
   * @param tokenType The type of token to create (LEVERAGE or BOND).
   * @param depositAmount The amount of tokens to deposit.
   * @param minAmount The minimum amount of tokens to receive.
   * @return amount of tokens created.
   */
  function swapCreate(address _pool,
    address depositToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount) external returns (uint256) {
    return swapCreate(_pool, depositToken, tokenType, depositAmount, minAmount, block.timestamp, msg.sender);
  }

  /**
   * @dev Swaps and creates tokens in a pool with additional parameters.
   * @param _pool The address of the pool.
   * @param depositToken The address of the token to deposit.
   * @param tokenType The type of token to create (LEVERAGE or BOND).
   * @param depositAmount The amount of tokens to deposit.
   * @param minAmount The minimum amount of tokens to receive.
   * @param deadline The deadline timestamp in seconds for the transaction.
   * @param onBehalfOf The address to receive the created tokens.
   * @return amount of tokens created.
   */
  function swapCreate(address _pool,
    address depositToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf) public returns (uint256) {
    Token reserveToken = Token(Pool(_pool).reserveToken());
    Token USDC = Token(Pool(_pool).couponToken());

    require(depositToken == address(USDC), "invalid deposit token, only accepts fake USDC");

    // Transfer depositAmount of depositToken from user to contract
    require(USDC.transferFrom(msg.sender, address(this), depositAmount), "Transfer failed");

    // Get ETH price from OracleReader
    uint256 ethPrice = getOraclePrice(address(reserveToken));

    uint8 oracleDecimals = getOracleDecimals(address(reserveToken));
    uint8 usdcDecimals = USDC.decimals();

    // Normalize the price if the oracle has more decimals than the coupon token
    if (oracleDecimals > usdcDecimals) {
      ethPrice = ethPrice.normalizeAmount(oracleDecimals, usdcDecimals);
      oracleDecimals = usdcDecimals;
    }
    
    // Calculate the amount of reserveToken based on the price
    uint256 reserveAmount = depositAmount / ethPrice;

    // Normalize the reserve amount to its decimals
    reserveAmount = reserveAmount.normalizeAmount(usdcDecimals-oracleDecimals, reserveToken.decimals());

    // Burn depositAmount from contract
    USDC.burn(address(this), depositAmount);

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

  /**
   * @dev Swaps and redeems tokens from a pool.
   * @param _pool The address of the pool.
   * @param redeemToken The address of the token to redeem.
   * @param tokenType The type of token to redeem (LEVERAGE or BOND).
   * @param depositAmount The amount of tokens to deposit.
   * @param minAmount The minimum amount of tokens to receive.
   * @return amount of tokens redeemed.
   */
  function swapRedeem(address _pool,
    address redeemToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount) external returns (uint256) {
    return swapRedeem(_pool, redeemToken, tokenType, depositAmount, minAmount, block.timestamp, msg.sender);
  }

  /**
   * @dev Swaps and redeems tokens from a pool with additional parameters.
   * @param _pool The address of the pool.
   * @param redeemToken The address of the token to redeem.
   * @param tokenType The type of token to redeem (LEVERAGE or BOND).
   * @param depositAmount The amount of tokens to deposit.
   * @param minAmount The minimum amount of tokens to receive.
   * @param deadline The deadline for the transaction.
   * @param onBehalfOf The address to receive the redeemed tokens.
   * @return amount of tokens redeemed.
   */
  function swapRedeem(address _pool,
    address redeemToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf) public returns (uint256) {
    Token reserveToken = Token(Pool(_pool).reserveToken());
    Token USDC = Token(Pool(_pool).couponToken());

    require(redeemToken == address(USDC), "invalid redeem token, only accepts fake USDC");

    if (tokenType == Pool.TokenType.LEVERAGE) {
      require(Pool(_pool).lToken().transferFrom(msg.sender, address(this), depositAmount), "Transfer failed");
    } else {
      require(Pool(_pool).dToken().transferFrom(msg.sender, address(this), depositAmount), "Transfer failed");
    }

    uint256 redeemAmount = Pool(_pool).redeem(tokenType, depositAmount, 0, deadline, address(this));

    // Get ETH price from OracleReader
    uint256 ethPrice = getOraclePrice(address(reserveToken));

    uint8 oracleDecimals = getOracleDecimals(address(reserveToken));

    // Calculate the amount of reserveToken based on the price
    uint256 usdcAmount = (redeemAmount * ethPrice).normalizeAmount(oracleDecimals + reserveToken.decimals(), USDC.decimals());

    if (minAmount > usdcAmount) {
      revert MinAmount();
    }

    // Burn depositAmount from contract
    reserveToken.burn(address(this), redeemAmount);

    if (onBehalfOf == address(0)) {
      onBehalfOf = msg.sender;
    }

    // Mint reserveToken to contract
    USDC.mint(onBehalfOf, usdcAmount);

    return usdcAmount;
  }
}
