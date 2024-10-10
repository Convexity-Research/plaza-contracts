// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Mock SwapRouter Contract
/// @notice This is a mock of the Uniswap V3 SwapRouter contract for testing purposes
contract MockSwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Mocks the exactInputSingle function
    /// @param params The parameters for the exact input single swap
    /// @return amountOut Mocked output amount (equal to amountIn for simplicity)
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut)
    {
        // Return dummy data
        amountOut = params.amountIn; // For simplicity, return the input amount
    }

    /// @notice Mocks the exactInput function
    /// @param params The parameters for the exact input swap
    /// @return amountOut Mocked output amount (equal to amountIn for simplicity)
    function exactInput(ExactInputParams calldata params)
        external
        payable
        returns (uint256 amountOut)
    {
        // Return dummy data
        amountOut = params.amountIn; // For simplicity, return the input amount
    }

    /// @notice Mocks the exactOutputSingle function
    /// @param params The parameters for the exact output single swap
    /// @return amountIn Mocked input amount (equal to amountOut for simplicity)
    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        returns (uint256 amountIn)
    {
        // Return dummy data
        amountIn = params.amountOut; // For simplicity, return the output amount
    }

    /// @notice Mocks the exactOutput function
    /// @param params The parameters for the exact output swap
    /// @return amountIn Mocked input amount (equal to amountOut for simplicity)
    function exactOutput(ExactOutputParams calldata params)
        external
        payable
        returns (uint256 amountIn)
    {
        // Return dummy data
        amountIn = params.amountOut; // For simplicity, return the output amount
    }
}
