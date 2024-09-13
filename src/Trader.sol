// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Merchant} from "./Merchant.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Trader {
  ISwapRouter private router;

  error InvalidTokenAddresses();
  error InvalidSwapAmount();
  error TransferFailed();

  constructor(address _router) {
    router = ISwapRouter(_router);
  }

  function swap(address pool, Merchant.LimitOrder memory order) internal returns (uint256) {
    if (order.sell == address(0) || order.buy == address(0)) revert InvalidTokenAddresses();
    if (order.amount == 0) revert InvalidSwapAmount();

    // Transfer wstETH from pool to this contract
    if (!IERC20(order.sell).transferFrom(pool, address(this), order.amount)) {
      revert TransferFailed();
    }

    // Define the path: wstETH -> WETH -> USDC
    address weth = 0x4200000000000000000000000000000000000006; // WETH address on Base
    bytes memory path = abi.encodePacked(
        order.sell,  // wstETH
        uint24(3000), // 0.3% fee tier for wstETH/WETH pool
        weth,
        uint24(500),  // 0.05% fee tier for WETH/USDC pool
        order.buy     // USDC
    );

    // Approve router to spend tokens
    IERC20(order.sell).approve(address(router), order.amount);

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
}
