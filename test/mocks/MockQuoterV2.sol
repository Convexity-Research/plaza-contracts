// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Mock QuoterV2 Contract
/// @notice This is a mock of the Uniswap V3 QuoterV2 contract for testing purposes
contract MockQuoterV2 {
  uint256 private mockAmountOut;

	struct QuoteExactInputSingleParams {
		address tokenIn;
		address tokenOut;
		uint24 fee;
		uint256 amountIn;
		uint160 sqrtPriceLimitX96;
	}

	struct QuoteExactOutputSingleParams {
		address tokenIn;
		address tokenOut;
		uint24 fee;
		uint256 amount;
		uint160 sqrtPriceLimitX96;
	}

  function setAmountOut(uint256 _amountOut) public {
    mockAmountOut = _amountOut;
  }

	/// @notice Mocks the quoteExactInputSingle function
	/// @param params The parameters for the exact input single quote
	/// @return amountOut Mocked output amount (equal to amountIn for simplicity)
	/// @return sqrtPriceX96After Mocked sqrt price after (set to zero)
	/// @return initializedTicksCrossed Mocked initialized ticks crossed (set to zero)
	/// @return gasEstimate Mocked gas estimate (set to zero)
	function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
		public
		pure
		returns (
			uint256 amountOut,
			uint160 sqrtPriceX96After,
			uint32 initializedTicksCrossed,
			uint256 gasEstimate
		)
	{
		// Return dummy data
		amountOut = params.amountIn; // For simplicity, return the input amount
		sqrtPriceX96After = 0;
		initializedTicksCrossed = 0;
		gasEstimate = 0;
	}

	function quoteExactInput(bytes memory /*path*/, uint256 amountIn)
		public
		view
		returns (
			uint256 amountOut,
			uint160[] memory sqrtPriceX96AfterList,
			uint32[] memory initializedTicksCrossedList,
			uint256 gasEstimate
		)
	{
		// Return dummy data
		amountOut = amountIn; // For simplicity, return the input amount
    if (mockAmountOut > 0) {
      amountOut = mockAmountOut;
    }

		sqrtPriceX96AfterList = new uint160[](1);
		sqrtPriceX96AfterList[0] = 0;
		initializedTicksCrossedList = new uint32[](1);
		initializedTicksCrossedList[0] = 0;
		gasEstimate = 0;
	}

	/// @notice Mocks thSingle function
	/// @param params The parameters for the exact output single quote
	/// @return amountIn Mocked input amount (equal to amount for simplicity)
	/// @return sqrtPriceX96After Mocked sqrt price after (set to zero)
	/// @return initializedTicksCrossed Mocked initialized ticks crossed (set to zero)
	/// @return gasEstimate Mocked gas estimate (set to zero)
	function quoteExactOutputSingle(QuoteExactOutputSingleParams memory params)
		public
		pure
		returns (
			uint256 amountIn,
			uint160 sqrtPriceX96After,
			uint32 initializedTicksCrossed,
			uint256 gasEstimate
		)
	{
		// Return dummy data
		amountIn = params.amount; // For simplicity, return the output amount
		sqrtPriceX96After = 0;
		initializedTicksCrossed = 0;
		gasEstimate = 0;
	}

	function quoteExactOutput(bytes memory /*path*/, uint256 amountOut)
		public
		pure
		returns (
			uint256 amountIn,
			uint160[] memory sqrtPriceX96AfterList,
			uint32[] memory initializedTicksCrossedList,
			uint256 gasEstimate
		)
	{
		// Return dummy data
		amountIn = amountOut; // For simplicity, return the output amount
		sqrtPriceX96AfterList = new uint160[](1);
		sqrtPriceX96AfterList[0] = 0;
		initializedTicksCrossedList = new uint32[](1);
		initializedTicksCrossedList[0] = 0;
		gasEstimate = 0;
	}
}
