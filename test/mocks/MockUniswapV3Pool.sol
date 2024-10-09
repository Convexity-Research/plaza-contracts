// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Mock UniswapV3Pool Contract
/// @notice This is a mock of the Uniswap V3 Pool contract for testing purposes
contract MockUniswapV3Pool {
	// Pool state variables
	address public factory;
	address public token0;
	address public token1;
	uint24 public fee;
	int24 public tickSpacing;
	uint128 public maxLiquidityPerTick;

	// Remove individual variable declarations of sqrtPriceX96, tick, etc.

	// Slot0 struct as per Uniswap V3 Pool
	struct Slot0 {
		// the current price
		uint160 sqrtPriceX96;
		// the current tick
		int24 tick;
		// the most-recently updated index of the observations array
		uint16 observationIndex;
		// the current maximum number of observations that are being stored
		uint16 observationCardinality;
		// the next maximum number of observations to store, triggered in observations.write
		uint16 observationCardinalityNext;
		// whether the pool is locked
		bool unlocked;
	}

	/// @notice The slot0 state variable
	Slot0 public slot0;

	uint256 public feeGrowthGlobal0X128;
	uint256 public feeGrowthGlobal1X128;

	uint128 public liquidity = 9169178941640739570;

	/// @notice Emitted when the pool is initialized
	/// @param sqrtPriceX96 The initial sqrt price of the pool
	/// @param tick The initial tick of the pool
	event Initialize(uint160 sqrtPriceX96, int24 tick);

	/// @notice Emitted on swaps
	/// @param sender The address initiating the swap
	/// @param recipient The address receiving the output of the swap
	/// @param amount0 The change in token0 balance
	/// @param amount1 The change in token1 balance
	/// @param sqrtPriceX96 The sqrt price after the swap
	/// @param liquidity The liquidity after the swap
	/// @param tick The tick after the swap
	event Swap(
		address indexed sender,
		address indexed recipient,
		int256 amount0,
		int256 amount1,
		uint160 sqrtPriceX96,
		uint128 liquidity,
		int24 tick
	);

	/// @notice Emitted on mint
	event Mint(
		address sender,
		address indexed owner,
		int24 indexed tickLower,
		int24 indexed tickUpper,
		uint128 amount,
		uint256 amount0,
		uint256 amount1
	);

	/// @notice Emitted on burn
	event Burn(
		address indexed owner,
		int24 indexed tickLower,
		int24 indexed tickUpper,
		uint128 amount,
		uint256 amount0,
		uint256 amount1
	);

	/// @notice Emitted on collect
	event Collect(
		address indexed owner,
		address recipient,
		int24 indexed tickLower,
		int24 indexed tickUpper,
		uint128 amount0,
		uint128 amount1
	);

	constructor() {
		setStorage(0);
	}

	function setStorage(uint160 _sqrtPriceX96) public {
		// Initialize state variables with dummy data
		factory = msg.sender;
		token0 = address(0x0);
		token1 = address(0x0);
		fee = 500;
		tickSpacing = 10;
		maxLiquidityPerTick = type(uint128).max;
    liquidity = 12208558192753768788;

		// Initialize slot0 variables with dummy data
		slot0 = Slot0({
			sqrtPriceX96: _sqrtPriceX96 == 0 ? 3996428064337469953968261 : _sqrtPriceX96,
			tick: -197904,
			observationIndex: 0,
			observationCardinality: 1,
			observationCardinalityNext: 1,
			unlocked: true
		});
	}

	/// @notice Mock initialize function
	/// @param _sqrtPriceX96 The initial sqrt price of the pool
	function initialize(uint160 _sqrtPriceX96) external {
		slot0.sqrtPriceX96 = _sqrtPriceX96;
		slot0.tick = 0; // For simplicity, set tick to 0
		emit Initialize(_sqrtPriceX96, slot0.tick);
	}
	
	function swap(
		address recipient,
		bool zeroForOne,
		int256 amountSpecified,
		uint160 /*sqrtPriceLimitX96*/,
		bytes calldata data
	) external returns (int256 amount0, int256 amount1) {
		// For simplicity, assume 1:1 swap rate
		if (zeroForOne) {
			amount0 = -amountSpecified;
			amount1 = amountSpecified;
		} else {
			amount0 = amountSpecified;
			amount1 = -amountSpecified;
		}

		// Call the swap callback
		IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);

		// Emit the Swap event
		emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
	}

	/// @notice Mock mint function
	/// @param recipient The address for which the liquidity will be created
	/// @param tickLower The lower tick of the position
	/// @param tickUpper The upper tick of the position
	/// @param amount The amount of liquidity to mint
	/// @param data Any data that should be passed through to the callback
	/// @return amount0 The amount of token0 needed
	/// @return amount1 The amount of token1 needed
	function mint(
		address recipient,
		int24 tickLower,
		int24 tickUpper,
		uint128 amount,
		bytes calldata data
	) external returns (uint256 amount0, uint256 amount1) {
		// For simplicity, assume minting requires equal amounts of token0 and token1
		amount0 = amount;
		amount1 = amount;

		// Call the mint callback
		IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);

		// Emit the Mint event
		emit Mint(msg.sender, recipient, tickLower, tickUpper, amount, amount0, amount1);
	}

	/// @notice Mock burn function
	/// @param tickLower The lower tick of the position
	/// @param tickUpper The upper tick of the position
	/// @param amount The amount of liquidity to burn
	/// @return amount0 The amount of token0 owed
	/// @return amount1 The amount of token1 owed
	function burn(
		int24 tickLower,
		int24 tickUpper,
		uint128 amount
	) external returns (uint256 amount0, uint256 amount1) {
		// For simplicity, assume burning returns equal amounts of token0 and token1
		amount0 = amount;
		amount1 = amount;

		// Emit the Burn event
		emit Burn(msg.sender, tickLower, tickUpper, amount, amount0, amount1);
	}

	/// @notice Mock collect function
	/// @param recipient The address which should receive the fees collected
	/// @param tickLower The lower tick of the position
	/// @param tickUpper The upper tick of the position
	/// @param amount0Requested How much token0 should be withdrawn from the fees owed
	/// @param amount1Requested How much token1 should be withdrawn from the fees owed
	/// @return amount0 The amount of fees collected in token0
	/// @return amount1 The amount of fees collected in token1
	function collect(
		address recipient,
		int24 tickLower,
		int24 tickUpper,
		uint128 amount0Requested,
		uint128 amount1Requested
	) external returns (uint128 amount0, uint128 amount1) {
		// For simplicity, assume that the full requested amounts are available
		amount0 = amount0Requested;
		amount1 = amount1Requested;

		// Emit the Collect event
		emit Collect(msg.sender, recipient, tickLower, tickUpper, amount0, amount1);
	}

	/// @notice Mock function to increase observation cardinality
	/// @param _observationCardinalityNext The desired minimum number of observations for the pool to store
	function increaseObservationCardinalityNext(uint16 _observationCardinalityNext) external {
		slot0.observationCardinalityNext = _observationCardinalityNext; // Update slot0 variable
	}

	/// @notice Mock observe function
	/// @param secondsAgos Array of seconds ago from which to get the cumulative values
	/// @return tickCumulatives Array of tick accumulations
	/// @return secondsPerLiquidityCumulativeX128s Array of seconds per liquidity accumulations
	function observe(uint32[] calldata secondsAgos)
		external
		pure
		returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
	{
		// Return dummy data
		uint256 len = secondsAgos.length;
		tickCumulatives = new int56[](len);
		secondsPerLiquidityCumulativeX128s = new uint160[](len);
	}

	function snapshotCumulativesInside(int24 /*tickLower*/, int24 /*tickUpper*/)
		external
		pure
		returns (
			int56 tickCumulativeInside,
			uint160 secondsPerLiquidityInsideX128,
			uint32 secondsInside
		)
	{
		// Return dummy data
		tickCumulativeInside = 0;
		secondsPerLiquidityInsideX128 = 0;
		secondsInside = 0;
	}

  function ticks(int24 /*tick*/)
    external
    pure
    returns (
      uint128 liquidityGross,
      int128 liquidityNet,
      int128 stakedLiquidityNet,
      uint256 feeGrowthOutside0X128,
      uint256 feeGrowthOutside1X128,
      uint256 rewardGrowthOutsideX128,
      int56 tickCumulativeOutside,
      uint160 secondsPerLiquidityOutsideX128,
      uint32 secondsOutside,
      bool initialized
    ) {
      return (1732736840509164, -173273684050916, 0, 0, 0, 0, 0, 0, 0, true);
    }
}

/// @notice Mock interface for UniswapV3SwapCallback
interface IUniswapV3SwapCallback {
	function uniswapV3SwapCallback(
		int256 amount0Delta,
		int256 amount1Delta,
		bytes calldata data
	) external;
}

/// @notice Mock interface for UniswapV3MintCallback
interface IUniswapV3MintCallback {
	function uniswapV3MintCallback(
		uint256 amount0Owed,
		uint256 amount1Owed,
		bytes calldata data
	) external;
}
