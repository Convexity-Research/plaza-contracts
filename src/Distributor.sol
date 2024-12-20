// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {BondToken} from "./BondToken.sol";
import {Decimals} from "./lib/Decimals.sol";
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
contract Distributor is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;
  using ERC20Extensions for IERC20;
  using Decimals for uint256;

  /// @dev Role identifier for accounts with governance privileges
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
  /// @dev Role identifier for the security council (emergency privileges)
  bytes32 public constant SECURITY_COUNCIL_ROLE = keccak256("SECURITY_COUNCIL_ROLE");
  
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

  /// @dev Event emitted when a user claims their shares
  event ClaimedShares(address user, uint256 period, uint256 shares);
  /// @dev Event emitted when a new pool is registered
  event PoolRegistered(address pool, address couponToken);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with the governance address and sets up roles.
   * This function is called once during deployment or upgrading to initialize state variables.
   * @param _governance Address of the governance account that will have the GOV_ROLE.
   */
  function initialize(address _governance, address _pool) initializer public {
    __ReentrancyGuard_init();
    __Pausable_init();

    _grantRole(GOV_ROLE, _governance);
    pool = Pool(_pool);
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
   * @dev Grants `role` to `account`.
   * If `account` had not been already granted `role`, emits a {RoleGranted} event.
   * Requirements:
   * - the caller must have ``role``'s admin role.
   * @param role The role to grant
   * @param account The account to grant the role to
   */
  function grantRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE) {
    _grantRole(role, account);
  }

  /**
   * @dev Revokes `role` from `account`.
   * If `account` had been granted `role`, emits a {RoleRevoked} event.
   * Requirements:
   * - the caller must have ``role``'s admin role.
   * @param role The role to revoke
   * @param account The account to revoke the role from
   */
  function revokeRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE) {
    _revokeRole(role, account);
  }

  /**
   * @dev Pauses all contract functions except for upgrades.
   * Requirements:
   * - the caller must have the `SECURITY_COUNCIL_ROLE`.
   */
  function pause() external onlyRole(SECURITY_COUNCIL_ROLE) {
    _pause();
  }

  /**
   * @dev Unpauses all contract functions.
   * Requirements:
   * - the caller must have the `SECURITY_COUNCIL_ROLE`.
   */
  function unpause() external onlyRole(SECURITY_COUNCIL_ROLE) {
    _unpause();
  }
}
