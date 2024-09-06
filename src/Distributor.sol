// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {BondToken} from "./BondToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Distributor is Initializable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {

  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
  bytes32 public constant POOL_FACTORY_ROLE = keccak256("POOL_FACTORY_ROLE");

  struct PoolInfo {
    address couponToken;
    uint256 amountToDistribute;
  }

  //map of pool info
  mapping(address => PoolInfo) public poolInfos;

  mapping(address => uint256) public couponAmountsToDistribute;

  error NotEnoughSharesBalance();
  error UnsupportedPool();
  error NotEnoughSharesToDistribute();
  error NotEnoughCouponBalance();
  error PoolAlreadyRegistered();
  event ClaimedShares(address user, uint256 period, uint256 shares);
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
  function initialize(address _governance) initializer public {
    __UUPSUpgradeable_init();

    _grantRole(GOV_ROLE, _governance);
  }

  /**
   * @dev Allows the pool factory to register a pool in the distributor.
   */
  function registerPool(address _pool, address _couponToken) external onlyRole(POOL_FACTORY_ROLE) {
    require(_pool != address(0), "Invalid pool address");
    
    poolInfos[_pool] = PoolInfo(_couponToken, 0);
    emit PoolRegistered(_pool, _couponToken);
  }

  /**
   * @dev Allows a user to claim their shares from a specific pool.
   * Calculates the number of shares based on the user's bond token balance and the shares per token.
   * Transfers the calculated shares to the user's address.
   * @param _pool Address of the pool from which to claim shares.
   */
  function claim(address _pool) external whenNotPaused() {
    require(_pool != address(0), UnsupportedPool());
    
    Pool pool = Pool(_pool);
    BondToken dToken = pool.dToken();
    address couponToken = pool.couponToken();
    ERC20 sharesToken = ERC20(couponToken);

    uint8 decimals = sharesToken.decimals();

    if (address(dToken) == address(0) || address(sharesToken) == address(0)){
      revert UnsupportedPool();
    }

    (uint256 currentPeriod,) = dToken.globalPool();
    uint256 balance = dToken.balanceOf(msg.sender);
    uint256 shares = dToken.getIndexedUserAmount(msg.sender, balance);

    if (sharesToken.balanceOf(address(this)) < shares) {
      revert NotEnoughSharesBalance();
    }

    PoolInfo memory poolInfo = poolInfos[_pool];

    // check if pool has enough *allocated* shares to distribute
    if (poolInfo.amountToDistribute < shares) {
      revert NotEnoughSharesToDistribute();
    }

    // check if the distributor has enough shares tokens as the amount to distribute
    if (sharesToken.balanceOf(address(this)) < poolInfo.amountToDistribute) {
      revert NotEnoughSharesToDistribute();
    }

    // @todo: replace with safeTransfer
    if (!sharesToken.transfer(msg.sender, shares)) {
      revert("not enough balance");
    }

    poolInfo.amountToDistribute -= shares;
    couponAmountsToDistribute[couponToken] -= shares;

    dToken.resetIndexedUserAssets(msg.sender);
    emit ClaimedShares(msg.sender, currentPeriod, shares);
  }

  /**
   * @dev Allocates shares to a pool.
   * @param _pool Address of the pool to allocate shares to.
   * @param _amountToDistribute Amount of shares to allocate.
   */
  function allocate(address _pool, uint256 _amountToDistribute) external {
    require(_pool == msg.sender, "Caller must be a registered pool");

    Pool pool = Pool(_pool);

    address couponToken = pool.couponToken();

    couponAmountsToDistribute[couponToken] += _amountToDistribute;
    poolInfos[_pool].amountToDistribute += _amountToDistribute;

    if (ERC20(couponToken).balanceOf(address(this)) < couponAmountsToDistribute[couponToken]) {
      revert NotEnoughCouponBalance();
    }
  }

  /**
    * @dev Grants `role` to `account`.
    * If `account` had not been already granted `role`, emits a {RoleGranted}
    * event.
    * May emit a {RoleGranted} event.
    */
  function grantRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE) {
    _grantRole(role, account);
  }

  /**
    * @dev Revokes `role` from `account`.
    * If `account` had been granted `role`, emits a {RoleRevoked} event.
    * May emit a {RoleRevoked} event.
    */
  function revokeRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE) {
    _revokeRole(role, account);
  }

  /**
   * @dev Pauses contract. Reverts any interaction expect upgrade.
   */
  function pause() external onlyRole(GOV_ROLE) {
    _pause();
  }

  /**
   * @dev Unpauses contract.
   */
  function unpause() external onlyRole(GOV_ROLE) {
    _unpause();
  }

  /**
   * @dev Authorizes an upgrade to a new implementation.
   * Can only be called by the owner of the contract.
   */
  function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(GOV_ROLE)
    override
  {}
}
