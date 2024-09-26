// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Merchant} from "./Merchant.sol";
import {TickMath} from "./lib/TickMath.sol";
import {FullMath} from "./lib/FullMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract Trader {
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
    // @todo: investigate why this could modify state - if I restrict to view, it moans
    amountOut = quoter.quoteExactInput(path, amountIn);
  }

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

  function getLiquidity(address reserveToken, address couponToken) public view returns (uint256) {
    uint24 fee1 = getFeeTier(reserveToken, WETH);
    uint24 fee2 = getFeeTier(WETH, couponToken);

    address pool1 = factory.getPool(reserveToken, WETH, fee1);
    address pool2 = factory.getPool(WETH, couponToken, fee2);

    if (pool1 == address(0) || pool2 == address(0)) revert NoPoolFound();

    (uint160 sqrtPriceX96_1, int24 tick_1,,,,,) = IUniswapV3Pool(pool1).slot0();
    (uint160 sqrtPriceX96_2, int24 tick_2,,,,,) = IUniswapV3Pool(pool2).slot0();

    uint128 liquidity1 = IUniswapV3Pool(pool1).liquidity();
    uint128 liquidity2 = IUniswapV3Pool(pool2).liquidity();

    uint256 amount0_1 = getAmount0ForLiquidity(sqrtPriceX96_1, TickMath.getSqrtRatioAtTick(tick_1 - 1), liquidity1);
    uint256 amount1_1 = getAmount1ForLiquidity(TickMath.getSqrtRatioAtTick(tick_1 + 1), sqrtPriceX96_1, liquidity1);

    uint256 amount0_2 = getAmount0ForLiquidity(sqrtPriceX96_2, TickMath.getSqrtRatioAtTick(tick_2 - 1), liquidity2);
    uint256 amount1_2 = getAmount1ForLiquidity(TickMath.getSqrtRatioAtTick(tick_2 + 1), sqrtPriceX96_2, liquidity2);

    uint256 value1 = amount0_1 + (amount1_1 * uint256(sqrtPriceX96_1) * uint256(sqrtPriceX96_1)) / (1 << 192);
    uint256 value2 = amount0_2 + (amount1_2 * uint256(sqrtPriceX96_2) * uint256(sqrtPriceX96_2)) / (1 << 192);

    return value1 < value2 ? value1 : value2;
  }

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
