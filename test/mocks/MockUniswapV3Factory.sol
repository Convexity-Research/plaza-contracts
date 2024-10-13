// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Mock UniswapV3Factory Contract
/// @notice This is a mock of the Uniswap V3 Factory contract for testing purposes
contract MockUniswapV3Factory {
	/// @notice The owner of the factory
	address public owner;

	/// @notice Mapping from fee amount to tick spacing
	mapping(uint24 => int24) public feeAmountTickSpacing;
  mapping(int24 => uint24) public tickSpacingToFee;


	/// @notice Mapping to get the pool address for a given pair of tokens and fee
	mapping(address => mapping(address => mapping(int24 => address))) public getPool;

	/// @notice Emitted when a pool is created
	event PoolCreated(
		address indexed token0,
		address indexed token1,
		uint24 fee,
		int24 tickSpacing,
		address pool
	);

	/// @notice Emitted when the owner is changed
	event OwnerChanged(address indexed oldOwner, address indexed newOwner);

	/// @notice Emitted when a new fee amount is enabled
	event FeeAmountEnabled(uint24 fee, int24 tickSpacing);

	/// @notice Constructor initializes the owner and enables default fee amounts
	constructor() {
		owner = msg.sender;
		emit OwnerChanged(address(0), msg.sender);

		// Initialize default fee amounts and tick spacings
		feeAmountTickSpacing[500] = 10;
		emit FeeAmountEnabled(500, 10);

		feeAmountTickSpacing[3000] = 60;
		emit FeeAmountEnabled(3000, 60);

		feeAmountTickSpacing[10000] = 200;
		emit FeeAmountEnabled(10000, 200);

    enableTickSpacing(1, 100);
    enableTickSpacing(50, 500);
    enableTickSpacing(100, 500);
    enableTickSpacing(200, 3_000);
    enableTickSpacing(2_000, 10_000);
	}

	/// @notice Mocks the createPool function
	/// @param tokenA The address of token A
	/// @param tokenB The address of token B
	/// @param tickSpacing The tick spacing
	/// @return pool The address of the created pool
	function createPool(
		address tokenA,
		address tokenB,
		int24 tickSpacing
	) external returns (address pool) {
		require(tokenA != tokenB, "Same token");
		(address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
		require(token0 != address(0), "Zero address");
		require(tickSpacing != 0, "Fee amount not enabled");
		require(getPool[token0][token1][tickSpacing] == address(0), "Pool already exists");

		// For simplicity, use the keccak256 hash as a mock pool address
		pool = address(uint160(uint256(keccak256(abi.encodePacked(token0, token1, tickSpacing)))));

		getPool[token0][token1][tickSpacing] = pool;
		getPool[token1][token0][tickSpacing] = pool; // Populate mapping in the reverse direction
	}

	/// @notice Mocks the setOwner function
	/// @param _owner The new owner of the factory
	function setOwner(address _owner) external {
		require(msg.sender == owner, "Not owner");
		emit OwnerChanged(owner, _owner);
		owner = _owner;
	}

	/// @notice Mocks the enableFeeAmount function
	/// @param fee The fee amount to enable
	/// @param tickSpacing The tick spacing for the fee amount
	function enableFeeAmount(uint24 fee, int24 tickSpacing) external {
		require(msg.sender == owner, "Not owner");
		require(fee < 1000000, "Fee too high");
		require(tickSpacing > 0 && tickSpacing < 16384, "Invalid tick spacing");
		require(feeAmountTickSpacing[fee] == 0, "Fee amount already enabled");

		feeAmountTickSpacing[fee] = tickSpacing;
		emit FeeAmountEnabled(fee, tickSpacing);
	}

  function enableTickSpacing(int24 tickSpacing, uint24 fee) public {
    require(fee > 0 && fee <= 100_000);
    require(tickSpacing > 0 && tickSpacing < 16384);
    require(tickSpacingToFee[tickSpacing] == 0);

    tickSpacingToFee[tickSpacing] = fee;
  }
}
