// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BondToken} from "./BondToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Distributor is Initializable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {

  struct Pool {
    BondToken bondToken;
    address sharesToken;
  }
  mapping (address => Pool) public pools;

  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  error NotEnoughSharesBalance();
  error UnsupportedPool();
  event ClaimedShares(address user, uint256 period, uint256 shares);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with the governance address and sets up roles.
   * This function is called once during deployment or upgrading to initialize state variables.
   * @param governance Address of the governance account that will have the GOV_ROLE.
   */
  function initialize(address governance) initializer public {
    __UUPSUpgradeable_init();
    _grantRole(GOV_ROLE, governance);
  }

  /**
   * @dev Updates the pool information for a given pool address.
   * Only callable by users with the GOV_ROLE.
   * @param pool Address of the pool to update.
   * @param bondToken Address of the BondToken contract associated with the pool.
   * @param sharesToken Address of the ERC20 token used for shares in the pool.
   */
  function updatePool(address pool, address bondToken, address sharesToken) external onlyRole(GOV_ROLE) whenNotPaused() {
    pools[pool] = Pool({
      bondToken: BondToken(bondToken),
      sharesToken: sharesToken
    });
  }

  /**
   * @dev Allows a user to claim their shares from a specific pool.
   * Calculates the number of shares based on the user's bond token balance and the shares per token.
   * Transfers the calculated shares to the user's address.
   * @param _pool Address of the pool from which to claim shares.
   */
  function claim(address _pool) external whenNotPaused() {
    Pool memory pool = pools[_pool];
    if (address(pool.bondToken) == address(0) || pool.sharesToken == address(0)){
      revert UnsupportedPool();
    }

    (uint256 currentPeriod,) = pool.bondToken.globalPool();
    uint256 balance = pool.bondToken.balanceOf(msg.sender);
    (uint256 lastUpdatedPeriod, uint256 shares) = pool.bondToken.userAssets(msg.sender);
    BondToken.PoolAmount[] memory poolAmounts = pool.bondToken.getPreviousPoolAmounts();

    for (uint256 i = lastUpdatedPeriod; i < currentPeriod; i++) {
      shares += (balance * poolAmounts[i].sharesPerToken) / 10000;
    }
    
    if (ERC20(pool.sharesToken).balanceOf(address(this)) < shares) {
      revert NotEnoughSharesBalance();
    }

    // @todo: replace with safeTransfer
    ERC20(pool.sharesToken).transfer(msg.sender, shares);

    pool.bondToken.resetIndexedUserAssets(msg.sender);
    emit ClaimedShares(msg.sender, currentPeriod, shares);
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
