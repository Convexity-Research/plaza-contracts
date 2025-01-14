// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {BondToken} from "./BondToken.sol";
import {Decimals} from "./lib/Decimals.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {ERC20Extensions} from "./lib/ERC20Extensions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title Distributor
 * @dev This contract manages the distribution of coupon shares to users based on their bond token balances.
 */
contract Distributor is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;
  using ERC20Extensions for IERC20;
  using Decimals for uint256;
  
  /// @dev Pool factory address
  PoolFactory public poolFactory;
  /// @dev Pool address
  Pool public pool;
  /// @dev Coupon token total amount to be distributed
  uint256 public couponAmountToDistribute;

  /// @dev Error thrown when there are not enough shares in the contract's balance
  error NotEnoughSharesBalance();
  /// @dev Error thrown when an unsupported pool is accessed
  error UnsupportedPool();
  /// @dev Error thrown when there are not enough shares allocated to distribute
  error NotEnoughSharesToDistribute();
  /// @dev Error thrown when there are not enough coupon tokens in the contract's balance
  error NotEnoughCouponBalance();
  /// @dev Error thrown when attempting to register an already registered pool
  error PoolAlreadyRegistered();
  /// @dev Error thrown when the pool has an invalid address
  error InvalidPoolAddress();
  /// @dev error thrown when the caller is not the pool
  error CallerIsNotPool();
  /// @dev error thrown when the caller does not have the required role
  error AccessDenied();

  /// @dev Event emitted when a user claims their shares
  event ClaimedShares(address user, uint256 period, uint256 shares);
  /// @dev Event emitted when a new pool is registered
  event PoolRegistered(address pool, address couponToken);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with the pool address and pool factory address.
   * This function is called once during deployment or upgrading to initialize state variables.
   * @param _pool Address of the pool.
   * @param _poolFactory Address of the pool factory.
   */
  function initialize(address _pool, address _poolFactory) initializer public {
    __ReentrancyGuard_init();
    __Pausable_init();

    pool = Pool(_pool);
    poolFactory = PoolFactory(_poolFactory);
  }

  /**
   * @dev Allows a user to claim their shares from a specific pool.
   * Calculates the number of shares based on the user's bond token balance and the shares per token.
   * Transfers the calculated shares to the user's address.
   */
  function claim() external whenNotPaused nonReentrant {
    BondToken bondToken = Pool(pool).bondToken();
    address couponToken = Pool(pool).couponToken();

    if (address(bondToken) == address(0) || couponToken == address(0)){
      revert UnsupportedPool();
    }

    (uint256 currentPeriod,) = bondToken.globalPool();
    uint256 balance = bondToken.balanceOf(msg.sender);
    uint256 shares = bondToken.getIndexedUserAmount(msg.sender, balance, currentPeriod)
                              .normalizeAmount(bondToken.decimals(), IERC20(couponToken).safeDecimals());

    if (IERC20(couponToken).balanceOf(address(this)) < shares) {
      revert NotEnoughSharesBalance();
    }
    
    // check if pool has enough *allocated* shares to distribute
    if (couponAmountToDistribute < shares) {
      revert NotEnoughSharesToDistribute();
    }

    // check if the distributor has enough shares tokens as the amount to distribute
    if (IERC20(couponToken).balanceOf(address(this)) < couponAmountToDistribute) {
      revert NotEnoughSharesToDistribute();
    }

    couponAmountToDistribute -= shares;    
    bondToken.resetIndexedUserAssets(msg.sender);
    IERC20(couponToken).safeTransfer(msg.sender, shares);
    
    emit ClaimedShares(msg.sender, currentPeriod, shares);
  }

  /**
   * @dev Allocates shares to a pool.
   * @param _amountToDistribute Amount of shares to allocate.
   */
  function allocate(uint256 _amountToDistribute) external whenNotPaused {
    require(address(pool) == msg.sender, CallerIsNotPool());

    address couponToken = pool.couponToken();
    couponAmountToDistribute += _amountToDistribute;

    if (IERC20(couponToken).balanceOf(address(this)) < couponAmountToDistribute) {
      revert NotEnoughCouponBalance();
    }
  }

  /**
   * @dev Pauses the contract. Reverts any interaction except upgrade.
   */
  function pause() external onlyRole(poolFactory.SECURITY_COUNCIL_ROLE()) {
    _pause();
  }

  /**
   * @dev Unpauses the contract.
   */
  function unpause() external onlyRole(poolFactory.SECURITY_COUNCIL_ROLE()) {
    _unpause();
  }

  /**
   * @dev Modifier to check if the caller has the specified role.
   * @param role The role to check for.
   */
  modifier onlyRole(bytes32 role) {
    if (!poolFactory.hasRole(role, msg.sender)) {
      revert AccessDenied();
    }
    _;
  }
}
