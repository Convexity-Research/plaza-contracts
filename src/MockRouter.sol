// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {Decimals} from "./lib/Decimals.sol";
import {Token} from "../test/mocks/Token.sol";
import {OracleReader} from "./OracleReader.sol";
import {ERC20Extensions} from "./lib/ERC20Extensions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Router
 * @dev Testnet contract that replaces the real Router contract on testnet.
 * @dev *******This contract is out of the scope of an audit.*******
 */
contract Router is OracleReader {
  using Decimals for uint256;
  using SafeERC20 for IERC20;
  using ERC20Extensions for IERC20;

  /**
   * @dev Error thrown when the minimum amount condition is not met.
   */
  error MinAmount();
  
  /**
   * @dev Constructor that initializes the OracleReader with the ETH price feed.
   * @param _oracleFeeds The address of the OracleFeeds contract.
   */
  constructor(address _oracleFeeds) {
    __OracleReader_init(_oracleFeeds);
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
    address reserveToken = Pool(_pool).reserveToken();
    address USDC = Pool(_pool).couponToken();

    require(depositToken == address(USDC), "invalid deposit token, only accepts fake USDC");

    // Transfer depositAmount of depositToken from user to contract
    IERC20(USDC).safeTransferFrom(msg.sender, address(this), depositAmount);

    // Get ETH price from OracleReader
    uint256 ethPrice =  getOraclePrice(reserveToken, USD);

    uint8 oracleDecimals = getOracleDecimals(reserveToken, USD);
    uint8 usdcDecimals = IERC20(USDC).safeDecimals();

    // Normalize the price if the oracle has more decimals than the coupon token
    if (oracleDecimals > usdcDecimals) {
      ethPrice = ethPrice.normalizeAmount(oracleDecimals, usdcDecimals);
      oracleDecimals = usdcDecimals;
    }

    // Ensure deposit amount is not zero
    require(depositAmount > 0, "Deposit amount must be greater than 0");

    // depositAmount is in USDC (18 decimals)
    // ethPrice is in USDC per ETH (8 decimals)
    // We want reserveAmount in ETH (18 decimals)
    
    // First scale up depositAmount by 8 decimals to match price feed precision
    uint256 scaledDepositAmount = depositAmount / (10 ** (usdcDecimals - oracleDecimals));
    
    // Divide by price to get ETH amount (result will have 18 decimals)
    // depositAmount(18) / 10^10 = scaledDepositAmount(8)
    // scaledDepositAmount(8) / ethPrice(8) * 10^18 = reserveAmount(18) 
    uint256 reserveAmount = (scaledDepositAmount * (10 ** IERC20(reserveToken).safeDecimals())) / ethPrice;

    // Ensure we don't get 0 reserveAmount due to rounding
    require(reserveAmount > 0, "Deposit amount too small");

    // Burn depositAmount from contract
    Token(USDC).burn(address(this), depositAmount);

    // Mint reserveToken to contract
    Token(reserveToken).mint(address(this), reserveAmount);

    // Approve reserveToken to pool
    IERC20(reserveToken).safeIncreaseAllowance(_pool, reserveAmount);

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
    address reserveToken = Pool(_pool).reserveToken();
    address USDC = Pool(_pool).couponToken();

    require(redeemToken == USDC, "invalid redeem token, only accepts fake USDC");

    address tokenToTransfer;
    if (tokenType == Pool.TokenType.LEVERAGE) {
      tokenToTransfer = address(Pool(_pool).lToken());
    } else {
      tokenToTransfer = address(Pool(_pool).bondToken());
    }
    IERC20(tokenToTransfer).safeTransferFrom(msg.sender, address(this), depositAmount);

    uint256 redeemAmount = Pool(_pool).redeem(tokenType, depositAmount, 0, deadline, onBehalfOf);

    // Get ETH price from OracleReader
    uint256 ethPrice = getOraclePrice(reserveToken, USD);

    uint8 oracleDecimals = getOracleDecimals(reserveToken, USD);

    // Calculate the amount of reserveToken based on the price
    uint256 usdcAmount = (redeemAmount * ethPrice).normalizeAmount(oracleDecimals + IERC20(reserveToken).safeDecimals(), IERC20(USDC).safeDecimals());

    if (minAmount > usdcAmount) {
      revert MinAmount();
    }

    // Burn depositAmount from contract
    Token(reserveToken).burn(msg.sender, redeemAmount);

    if (onBehalfOf == address(0)) {
      onBehalfOf = msg.sender;
    }

    // Mint reserveToken to contract
    Token(USDC).mint(onBehalfOf, usdcAmount);

    return usdcAmount;
  }
}
