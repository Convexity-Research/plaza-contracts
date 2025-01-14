// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title The interface for the CL Factory
/// @notice The CL Factory facilitates creation of CL pools and control over the protocol fees
interface ICLFactory {
    /// @notice Emitted when the owner of the factory is changed
    /// @param oldOwner The owner before the owner was changed
    /// @param newOwner The owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when the swapFeeManager of the factory is changed
    /// @param oldFeeManager The swapFeeManager before the swapFeeManager was changed
    /// @param newFeeManager The swapFeeManager after the swapFeeManager was changed
    event SwapFeeManagerChanged(address indexed oldFeeManager, address indexed newFeeManager);

    /// @notice Emitted when the swapFeeModule of the factory is changed
    /// @param oldFeeModule The swapFeeModule before the swapFeeModule was changed
    /// @param newFeeModule The swapFeeModule after the swapFeeModule was changed
    event SwapFeeModuleChanged(address indexed oldFeeModule, address indexed newFeeModule);

    /// @notice Emitted when the unstakedFeeManager of the factory is changed
    /// @param oldFeeManager The unstakedFeeManager before the unstakedFeeManager was changed
    /// @param newFeeManager The unstakedFeeManager after the unstakedFeeManager was changed
    event UnstakedFeeManagerChanged(address indexed oldFeeManager, address indexed newFeeManager);

    /// @notice Emitted when the unstakedFeeModule of the factory is changed
    /// @param oldFeeModule The unstakedFeeModule before the unstakedFeeModule was changed
    /// @param newFeeModule The unstakedFeeModule after the unstakedFeeModule was changed
    event UnstakedFeeModuleChanged(address indexed oldFeeModule, address indexed newFeeModule);

    /// @notice Emitted when the defaultUnstakedFee of the factory is changed
    /// @param oldUnstakedFee The defaultUnstakedFee before the defaultUnstakedFee was changed
    /// @param newUnstakedFee The defaultUnstakedFee after the unstakedFeeModule was changed
    event DefaultUnstakedFeeChanged(uint24 indexed oldUnstakedFee, uint24 indexed newUnstakedFee);

    /// @notice Emitted when a pool is created
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param tickSpacing The minimum number of ticks between initialized ticks
    /// @param pool The address of the created pool
    event PoolCreated(address indexed token0, address indexed token1, int24 indexed tickSpacing, address pool);

    /// @notice Emitted when a new tick spacing is enabled for pool creation via the factory
    /// @param tickSpacing The minimum number of ticks between initialized ticks for pools
    /// @param fee The default fee for a pool created with a given tickSpacing
    event TickSpacingEnabled(int24 indexed tickSpacing, uint24 indexed fee);

    /// @notice The address of the pool implementation contract used to deploy proxies / clones
    /// @return The address of the pool implementation contract
    function poolImplementation() external view returns (address);

    /// @notice Returns the current owner of the factory
    /// @dev Can be changed by the current owner via setOwner
    /// @return The address of the factory owner
    function owner() external view returns (address);

    /// @notice Returns the current swapFeeManager of the factory
    /// @dev Can be changed by the current swap fee manager via setSwapFeeManager
    /// @return The address of the factory swapFeeManager
    function swapFeeManager() external view returns (address);

    /// @notice Returns the current swapFeeModule of the factory
    /// @dev Can be changed by the current swap fee manager via setSwapFeeModule
    /// @return The address of the factory swapFeeModule
    function swapFeeModule() external view returns (address);

    /// @notice Returns the current unstakedFeeManager of the factory
    /// @dev Can be changed by the current unstaked fee manager via setUnstakedFeeManager
    /// @return The address of the factory unstakedFeeManager
    function unstakedFeeManager() external view returns (address);

    /// @notice Returns the current unstakedFeeModule of the factory
    /// @dev Can be changed by the current unstaked fee manager via setUnstakedFeeModule
    /// @return The address of the factory unstakedFeeModule
    function unstakedFeeModule() external view returns (address);

    /// @notice Returns the current defaultUnstakedFee of the factory
    /// @dev Can be changed by the current unstaked fee manager via setDefaultUnstakedFee
    /// @return The default Unstaked Fee of the factory
    function defaultUnstakedFee() external view returns (uint24);

    /// @notice Returns a default fee for a tick spacing.
    /// @dev Use getFee for the most up to date fee for a given pool.
    /// A tick spacing can never be removed, so this value should be hard coded or cached in the calling context
    /// @param tickSpacing The enabled tick spacing. Returns 0 if not enabled
    /// @return fee The default fee for the given tick spacing
    function tickSpacingToFee(int24 tickSpacing) external view returns (uint24 fee);

    /// @notice Returns a list of enabled tick spacings. Used to iterate through pools created by the factory
    /// @dev Tick spacings cannot be removed. Tick spacings are not ordered
    /// @return List of enabled tick spacings
    function tickSpacings() external view returns (int24[] memory);

    /// @notice Returns the pool address for a given pair of tokens and a tick spacing, or address 0 if it does not exist
    /// @dev tokenA and tokenB may be passed in either token0/token1 or token1/token0 order
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param tickSpacing The tick spacing of the pool
    /// @return pool The pool address
    function getPool(address tokenA, address tokenB, int24 tickSpacing) external view returns (address pool);

    /// @notice Return address of pool created by this factory given its `index`
    /// @param index Index of the pool
    /// @return The pool address in the given index
    function allPools(uint256 index) external view returns (address);

    /// @notice Returns the number of pools created from this factory
    /// @return Number of pools created from this factory
    function allPoolsLength() external view returns (uint256);

    /// @notice Used in VotingEscrow to determine if a contract is a valid pool of the factory
    /// @param pool The address of the pool to check
    /// @return Whether the pool is a valid pool of the factory
    function isPair(address pool) external view returns (bool);

    /// @notice Get swap & flash fee for a given pool. Accounts for default and dynamic fees
    /// @dev Swap & flash fee is denominated in pips. i.e. 1e-6
    /// @param pool The pool to get the swap & flash fee for
    /// @return The swap & flash fee for the given pool
    function getSwapFee(address pool) external view returns (uint24);

    /// @notice Get unstaked fee for a given pool. Accounts for default and dynamic fees
    /// @dev Unstaked fee is denominated in pips. i.e. 1e-6
    /// @param pool The pool to get the unstaked fee for
    /// @return The unstaked fee for the given pool
    function getUnstakedFee(address pool) external view returns (uint24);

    /// @notice Creates a pool for the given two tokens and fee
    /// @param tokenA One of the two tokens in the desired pool
    /// @param tokenB The other of the two tokens in the desired pool
    /// @param tickSpacing The desired tick spacing for the pool
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @dev tokenA and tokenB may be passed in either order: token0/token1 or token1/token0. The call will
    /// revert if the pool already exists, the tick spacing is invalid, or the token arguments are invalid
    /// @return pool The address of the newly created pool
    function createPool(address tokenA, address tokenB, int24 tickSpacing, uint160 sqrtPriceX96)
        external
        returns (address pool);

    /// @notice Updates the owner of the factory
    /// @dev Must be called by the current owner
    /// @param _owner The new owner of the factory
    function setOwner(address _owner) external;

    /// @notice Updates the swapFeeManager of the factory
    /// @dev Must be called by the current swap fee manager
    /// @param _swapFeeManager The new swapFeeManager of the factory
    function setSwapFeeManager(address _swapFeeManager) external;

    /// @notice Updates the swapFeeModule of the factory
    /// @dev Must be called by the current swap fee manager
    /// @param _swapFeeModule The new swapFeeModule of the factory
    function setSwapFeeModule(address _swapFeeModule) external;

    /// @notice Updates the unstakedFeeManager of the factory
    /// @dev Must be called by the current unstaked fee manager
    /// @param _unstakedFeeManager The new unstakedFeeManager of the factory
    function setUnstakedFeeManager(address _unstakedFeeManager) external;

    /// @notice Updates the unstakedFeeModule of the factory
    /// @dev Must be called by the current unstaked fee manager
    /// @param _unstakedFeeModule The new unstakedFeeModule of the factory
    function setUnstakedFeeModule(address _unstakedFeeModule) external;

    /// @notice Updates the defaultUnstakedFee of the factory
    /// @dev Must be called by the current unstaked fee manager
    /// @param _defaultUnstakedFee The new defaultUnstakedFee of the factory
    function setDefaultUnstakedFee(uint24 _defaultUnstakedFee) external;

    /// @notice Enables a certain tickSpacing
    /// @dev Tick spacings may never be removed once enabled
    /// @param tickSpacing The spacing between ticks to be enforced in the pool
    /// @param fee The default fee associated with a given tick spacing
    function enableTickSpacing(int24 tickSpacing, uint24 fee) external;
}
