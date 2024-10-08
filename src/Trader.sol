// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Merchant} from "./Merchant.sol";
import {Tick} from "./lib/uniswap/Tick.sol";
import {TickMath} from "./lib/uniswap/TickMath.sol";
import {FullMath} from "./lib/uniswap/FullMath.sol";
import {ERC20Extensions} from "./lib/ERC20Extensions.sol";
import {LiquidityAmounts} from "./lib/uniswap/LiquidityAmounts.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {ICLFactory} from "./lib/aerodrome/ICLFactory.sol";
import {ICLPool} from "./lib/aerodrome/ICLPool.sol";

contract Trader {
  using ERC20Extensions for IERC20;
  ISwapRouter private router;
  IQuoter private quoter;
  ICLFactory private factory;
  address private constant WETH = 0x4200000000000000000000000000000000000006; // WETH address on Base
  
  error NoPoolFound();
  error TransferFailed();
  error InvalidSwapAmount();
  error InvalidTokenAddresses();

  constructor(address _router, address _quoter, address _factory) {
    router = ISwapRouter(_router);
    quoter = IQuoter(_quoter);
    factory = ICLFactory(_factory);
  }

  function swap(address pool, Merchant.LimitOrder memory order) internal returns (uint256) {
    if (order.sell == address(0) || order.buy == address(0)) revert InvalidTokenAddresses();
    if (order.amount == 0) revert InvalidSwapAmount();

    // @todo: use safeTransferFrom
    // Transfer wstETH from pool to this contract
    if (!IERC20(order.sell).transferFrom(pool, address(this), order.amount)) {
      revert TransferFailed();
    }

    // Approve router to spend tokens
    if (!IERC20(order.sell).approve(address(router), order.amount)) {
      revert TransferFailed();
    }

    // Fetch the fee tiers dynamically
    (,uint24 fee1,) = getPool(order.sell, WETH);
    (,uint24 fee2,) = getPool(WETH, order.buy);

    // Define the path: wstETH -> WETH -> USDC
    bytes memory path = abi.encodePacked(
        order.sell,  // wstETH
        fee1, // fee wstETH/WETH
        WETH,
        fee2,  // fee WETH/USDC
        order.buy     // USDC
    );
    
    // Set up swap parameters
    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
        path: path,
        recipient: pool,  // Send USDC directly to the pool
        deadline: block.timestamp + 15 minutes,
        amountIn: order.amount,
        amountOutMinimum: order.minAmount
    });

    // Execute the swap
    return router.exactInput(params);
  }

  function quote(address reserveToken, address couponToken, uint256 amountIn) public returns (uint256 amountOut) {
    if (reserveToken == address(0) || couponToken == address(0)) revert InvalidTokenAddresses();
    if (amountIn == 0) revert InvalidSwapAmount();

    // Fetch the fee tiers dynamically
    (,uint24 fee1,) = getPool(reserveToken, WETH);
    (,uint24 fee2,) = getPool(WETH, couponToken);

    // Define the path: wstETH -> WETH -> USDC
    bytes memory path = abi.encodePacked(
        reserveToken, // wstETH
        fee1, // fee wstETH/WETH
        WETH,
        fee2, // fee WETH/USDC
        couponToken // USDC
    );

    // Get the quote
    amountOut = quoter.quoteExactInput(path, amountIn);
  }

  /**
   * @dev Returns the pool address and fee for the given token pair.
   * This function checks for the existence of a pool for the given token pair at various tick spacings.
   * It iterates through predefined tick spacings and attempts to find a valid pool.
   * If a pool is found, it returns the pool address and corresponding fee.
   * If no pool is found for any of the tick spacings, it reverts with a `NoPoolFound` error.
   *
   * @param tokenA The address of the first token.
   * @param tokenB The address of the second token.
   * @return The pool address and fee for the given token pair.
   */
  function getPool(address tokenA, address tokenB) private view returns (address, uint24, int24) {
    // this only works for Aerodrome, they decided to break compatibility with getPool mapping
    int24[5] memory spacing = [int24(1), int24(50), int24(100), int24(200), int24(2000)];

    for (uint24 i = 0; i < spacing.length; i++) {
      try factory.getPool(tokenA, tokenB, spacing[i]) returns (address _pool) {
        if (_pool == address(0)) continue;
        
        (bool success, bytes memory data) = address(factory).staticcall(abi.encodeWithSignature("tickSpacingToFee(int24)", spacing[i]));
        if (!success) continue;
        
        return (_pool, abi.decode(data, (uint24)), spacing[i]);

      } catch {}
    }

    revert NoPoolFound();
  }
  
  // @todo: this always goes from current tick to a lower tick
  // It should be dynamic depending on what token is being sold
  function getLiquidityAmounts(address tokenA, address tokenB, uint24 targetTickRange) public view returns (uint256 amount0, uint256 amount1) {
    (address pool,,int24 tickSpacing) = getPool(tokenA, tokenB);

    if (pool == address(0)) revert NoPoolFound();

    (uint160 sqrtPriceX96, int24 tick,,,,) = ICLPool(pool).slot0();

    // Division here acts as a floor rounding division
    int24 lowerCurrentTick = (tick / tickSpacing) * tickSpacing;

    int24 tempTick = lowerCurrentTick;
    int128 liquidity = int128(ICLPool(pool).liquidity());

    while (true) {
      if (abs(lowerCurrentTick - tempTick) >= targetTickRange) { break; }
      if (abs(lowerCurrentTick - tempTick) % uint24(tickSpacing) != 0) { break; }
      if (tempTick < TickMath.MIN_TICK && tempTick > TickMath.MAX_TICK) { break; }

      (,int128 liquidityNet,,,,,,,,bool initialized) = ICLPool(pool).ticks(tempTick);
      if (!initialized) { return (0, 0); } // this shouldn't happen

      liquidity -= liquidityNet;

      tempTick -= tickSpacing;
    }

    uint160 lowerSqrtPriceX96 = TickMath.getSqrtRatioAtTick(tempTick);
    uint160 upperSqrtPriceX96 = TickMath.getSqrtRatioAtTick(lowerCurrentTick + tickSpacing);

    (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
      sqrtPriceX96,
      lowerSqrtPriceX96,
      upperSqrtPriceX96,
      uint128(liquidity)
    );

    if (tokenA < tokenB ) {
      return (amount0, amount1);
    } else {
      return (amount1, amount0);
    }
  }

  function getPrice(address tokenA, address tokenB) public view returns (uint256) {
    (address pool,,) = getPool(tokenA, tokenB);

    if (pool == address(0)) revert NoPoolFound();

    (uint160 sqrtPriceX96,,,,,) = ICLPool(pool).slot0();

    // sqrtPriceX96 represents the square root of the price ratio of token1 to token0
    // where token0 is the token with the smaller address (in hex)
    // Price = (sqrtPriceX96 / 2^96)^2 gives us the price of token0 in terms of token1
    if (tokenA < tokenB) {
      // If tokenA < tokenB, then tokenA is token0 and tokenB is token1
      // So we can directly use the formula to get the price of tokenA in terms of tokenB
      return (uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * 10**IERC20(tokenA).safeDecimals()) / (1 << 192);
    } else {
      // If tokenA > tokenB, then tokenB is token0 and tokenA is token1
      // We need to invert the price to get the price of tokenB in terms of tokenA
      return (uint256(1 << 192) * 10**IERC20(tokenB).safeDecimals()) / (uint256(sqrtPriceX96) * uint256(sqrtPriceX96));
    }
  }

  function abs(int24 x) internal pure returns (uint24) {
    return x >= 0 ? uint24(x) : uint24(-x);
  }
}
