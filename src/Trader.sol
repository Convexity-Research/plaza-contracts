// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Merchant} from "./Merchant.sol";
import {TickMath} from "./lib/TickMath.sol";
import {FullMath} from "./lib/FullMath.sol";
import {ERC20Extensions} from "./lib/ERC20Extensions.sol";
import {Tick} from "@uniswap/v3-core/contracts/libraries/Tick.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract Trader {
  using ERC20Extensions for IERC20;
  ISwapRouter private router;
  IQuoter private quoter;
  IUniswapV3Factory private factory;
  address private constant WETH = 0x4200000000000000000000000000000000000006; // WETH address on Base

  error InvalidTokenAddresses();
  error InvalidSwapAmount();
  error TransferFailed();
  error NoPoolFound();

  constructor(address _router, address _quoter, address _factory) {
    router = ISwapRouter(_router);
    quoter = IQuoter(_quoter);
    factory = IUniswapV3Factory(_factory);
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
    uint24 fee1 = getFeeTier(order.sell, WETH);
    uint24 fee2 = getFeeTier(WETH, order.buy);

    // Define the path: wstETH -> WETH -> USDC
    bytes memory path = abi.encodePacked(
        order.sell,  // wstETH
        fee1, // fee wstETH/WETH
        WETH,
        fee2,  // fee WETH/USDC
        order.buy     // USDC
    );

    // Calculate amountOutMinimum as 0.5% less than order.price
    uint256 amountOutMinimum = (order.price * order.amount * 995) / 100000;

    // Set up swap parameters
    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
        path: path,
        recipient: pool,  // Send USDC directly to the pool
        deadline: block.timestamp + 15 minutes,
        amountIn: order.amount,
        amountOutMinimum: amountOutMinimum
    });

    // Execute the swap
    return router.exactInput(params);
  }

  function quote(address reserveToken, address couponToken, uint256 amountIn) public returns (uint256 amountOut) {
    if (reserveToken == address(0) || couponToken == address(0)) revert InvalidTokenAddresses();
    if (amountIn == 0) revert InvalidSwapAmount();

    // Fetch the fee tiers dynamically
    uint24 fee1 = getFeeTier(reserveToken, WETH);
    uint24 fee2 = getFeeTier(WETH, couponToken);

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
   * @dev Returns the lowest fee tier for the given token pair.
   * This function checks for the existence of a pool for the given token pair at various fee tiers.
   * It starts from the lowest fee tier and goes up to the highest fee tier.
   * If a pool is found at a particular fee tier, it returns that fee tier.
   * If no pool is found for any of the fee tiers, it reverts with a `NoPoolFound` error.
   *
   * @param tokenA The address of the first token.
   * @param tokenB The address of the second token.
   * @return The lowest fee tier for the given token pair.
   */
  function getFeeTier(address tokenA, address tokenB) internal view returns (uint24) {
    address pool = factory.getPool(tokenA, tokenB, 100);
    if (pool != address(0)) return 100;

    pool = factory.getPool(tokenA, tokenB, 200);
    if (pool != address(0)) return 200;

    pool = factory.getPool(tokenA, tokenB, 300);
    if (pool != address(0)) return 300;

    pool = factory.getPool(tokenA, tokenB, 400);
    if (pool != address(0)) return 400;
    
    pool = factory.getPool(tokenA, tokenB, 500);
    if (pool != address(0)) return 500;

    pool = factory.getPool(tokenA, tokenB, 3000);
    if (pool != address(0)) return 3000;

    pool = factory.getPool(tokenA, tokenB, 10000);
    if (pool != address(0)) return 10000;

    revert NoPoolFound();
  }

  function getLiquidity(address tokenA, address tokenB, uint24 targetTickRange) public view returns (uint256) {
    uint24 fee = getFeeTier(tokenA, tokenB);

    address pool = factory.getPool(tokenA, tokenB, fee);
    int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

    if (pool == address(0)) revert NoPoolFound();

    (uint160 sqrtPriceX96, int24 tick,,,,,) = IUniswapV3Pool(pool).slot0();

    // Division here acts as a floor rounding division
    int24 lowerInitializedTick = (tick / tickSpacing) * tickSpacing;

    int24 currentTick = lowerInitializedTick;
    uint128 liquidity = IUniswapV3Pool(pool).liquidity();

    while (true) {
      if (abs(lowerInitializedTick - currentTick) >= targetTickRange) { break; }
      if (abs(lowerInitializedTick - currentTick) % tickSpacing != 0) { break; }
      if (currentTick < TickMath.MIN_TICK && currentTick > TickMath.MAX_TICK) { break; }

      Tick.Info tickInfo = IUniswapV3Pool(pool).ticks(currentTick);
      if (!tickInfo.initialized) { revert; } // this shouldn't happen

      liquidity -= tickInfo.liquidityNet;

      currentTick -= tickSpacing;
    }

    return liquidity;

    // uint256 amount0 = getAmount0ForLiquidity(sqrtPriceX96, TickMath.getSqrtRatioAtTick(tick - 1), liquidity);
    // uint256 amount1 = getAmount1ForLiquidity(TickMath.getSqrtRatioAtTick(tick + 1), sqrtPriceX96, liquidity);

    // return amount0 + (amount1 * uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (1 << 192);
  }

  function getPrice(address tokenA, address tokenB) public view returns (uint256) {
    uint24 fee = getFeeTier(tokenA, tokenB);
    address pool = factory.getPool(tokenA, tokenB, fee);

    if (pool == address(0)) revert NoPoolFound();

    (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();

    // sqrtPriceX96 represents the square root of the price ratio of token1 to token0
    // where token0 is the token with the smaller address (in hex)
    // Price = (sqrtPriceX96 / 2^96)^2 gives us the price of token0 in terms of token1
    if (tokenA < tokenB) {
      // If tokenA < tokenB, then tokenA is token0 and tokenB is token1
      // So we can directly use the formula to get the price of tokenA in terms of tokenB
      return (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (1 << 192);
    } else {
      // If tokenA > tokenB, then tokenB is token0 and tokenA is token1
      // We need to invert the price to get the price of tokenA in terms of tokenB
      return (10**IERC20(tokenA).decimals()) / ((uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (1 << 192));
    }
  }

  function abs(int24 x) internal pure returns (uint24) {
    return x >= 0 ? uint24(x) : uint24(-x);
  }

  // function getLiquidity(address reserveToken, address couponToken) public view returns (uint256) {
  //   uint24 fee1 = getFeeTier(reserveToken, WETH);
  //   uint24 fee2 = getFeeTier(WETH, couponToken);

  //   address pool1 = factory.getPool(reserveToken, WETH, fee1);
  //   address pool2 = factory.getPool(WETH, couponToken, fee2);

  //   if (pool1 == address(0) || pool2 == address(0)) revert NoPoolFound();

  //   (uint160 sqrtPriceX96_1, int24 tick_1,,,,,) = IUniswapV3Pool(pool1).slot0();
  //   (uint160 sqrtPriceX96_2, int24 tick_2,,,,,) = IUniswapV3Pool(pool2).slot0();

  //   uint128 liquidity1 = IUniswapV3Pool(pool1).liquidity();
  //   uint128 liquidity2 = IUniswapV3Pool(pool2).liquidity();

  //   uint256 amount0_1 = getAmount0ForLiquidity(sqrtPriceX96_1, TickMath.getSqrtRatioAtTick(tick_1 - 1), liquidity1);
  //   uint256 amount1_1 = getAmount1ForLiquidity(TickMath.getSqrtRatioAtTick(tick_1 + 1), sqrtPriceX96_1, liquidity1);

  //   uint256 amount0_2 = getAmount0ForLiquidity(sqrtPriceX96_2, TickMath.getSqrtRatioAtTick(tick_2 - 1), liquidity2);
  //   uint256 amount1_2 = getAmount1ForLiquidity(TickMath.getSqrtRatioAtTick(tick_2 + 1), sqrtPriceX96_2, liquidity2);

  //   uint256 value1 = amount0_1 + (amount1_1 * uint256(sqrtPriceX96_1) * uint256(sqrtPriceX96_1)) / (1 << 192);
  //   uint256 value2 = amount0_2 + (amount1_2 * uint256(sqrtPriceX96_2) * uint256(sqrtPriceX96_2)) / (1 << 192);

  //   return value1 < value2 ? value1 : value2;
  // }

  function getAmount0ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity) internal pure returns (uint256 amount0) {
    if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

    return FullMath.mulDiv(
      uint256(liquidity) << 96,
      sqrtRatioBX96 - sqrtRatioAX96,
      sqrtRatioBX96
    ) / sqrtRatioAX96;
  }

  function getAmount1ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity) internal pure returns (uint256 amount1) {
    if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

    return FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, 1 << 96);
  }
}
