// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

contract BondToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, PausableUpgradeable {
  struct PoolAmount {
    uint256 period;
    uint256 amount;
    uint256 sharesPerToken; // 10000 base
  }

  struct IndexedGlobalAssetPool {
    uint256 currentPeriod;
    uint256 sharesPerToken; // 10000 base
    PoolAmount[] previousPoolAmounts;
  }

  struct IndexedUserAssets {
    uint256 lastUpdatedPeriod;
    uint256 indexedAmountShares;
  }

  IndexedGlobalAssetPool public globalPool;

  mapping(address => IndexedUserAssets) public userAssets;

  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
  bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

  event IncreasedAssetPeriod(uint256 currentPeriod, uint256 sharesPerToken);
  event UpdatedUserAssets(address user, uint256 lastUpdatedPeriod, uint256 indexedAmountShares);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    string memory name, 
    string memory symbol, 
    address minter, 
    address governance, 
    address distributor
    ) initializer public {
    __ERC20_init(name, symbol);
    __ERC20Permit_init(name);
    __UUPSUpgradeable_init();

    // Grant the access roles
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _grantRole(MINTER_ROLE, minter);
    _grantRole(GOV_ROLE, governance);
    _grantRole(DISTRIBUTOR_ROLE, distributor);
  }

  /**
   * @dev Mints new tokens to the specified address.
   * Can only be called by addresses with the MINTER_ROLE.
   */
  function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    _mint(to, amount);
  }

  /**
   * @dev Burns tokens from the specified account.
   * Can only be called by addresses with the MINTER_ROLE.
   */
  function burn(address account, uint256 amount) public onlyRole(MINTER_ROLE) {
    _burn(account, amount);
  }

  /**
   * @dev Returns the previous pool amounts from the global pool.
   */
  function getPreviousPoolAmounts() external view returns (PoolAmount[] memory) {
    return globalPool.previousPoolAmounts;
  }

  /**
   * @dev Internal function to update user assets after a transfer.
   * Called during token transfer.
   */
  function _update(address from, address to, uint256 amount) internal virtual override whenNotPaused() {
    if (from != address(0)) {
      updateIndexedUserAssets(from, balanceOf(from));
    }

    if (to != address(0)) {
      updateIndexedUserAssets(to, balanceOf(to));
    }

    super._update(from, to, amount);
  }

  /**
   * @dev Updates the indexed user assets for a specific user.
   * Updates the number of shares held by the user based on the current period.
   */
  function updateIndexedUserAssets(address user, uint256 balance) internal {
    IndexedUserAssets memory userPool = userAssets[user];
    uint256 period = globalPool.currentPeriod;
    uint shares = userAssets[user].indexedAmountShares;
    
    for (uint256 i = userPool.lastUpdatedPeriod; i < period; i++) {
      shares += (balance * globalPool.previousPoolAmounts[i].sharesPerToken) / 10000;
    }
    
    userAssets[user].indexedAmountShares = shares;
    userAssets[user].lastUpdatedPeriod = period;

    emit UpdatedUserAssets(user, period, shares);
  }

  /**
   * @dev Resets the indexed user assets for a specific user.
   * Resets the last updated period and indexed amount of shares to zero.
   */
  function resetIndexedUserAssets(address user) external onlyRole(DISTRIBUTOR_ROLE) whenNotPaused(){
    userAssets[user].lastUpdatedPeriod = globalPool.currentPeriod;
    userAssets[user].indexedAmountShares = 0;
  }

  /**
   * @dev Increases the current period and updates the shares per token.
   * Can only be called by addresses with the GOV_ROLE.
   */
  function increaseIndexedAssetPeriod(uint256 sharesPerToken) public onlyRole(GOV_ROLE) whenNotPaused() {
    globalPool.previousPoolAmounts.push(
      PoolAmount({
        period: globalPool.currentPeriod,
        amount: totalSupply(),
        sharesPerToken: globalPool.sharesPerToken
      })
    );
    globalPool.currentPeriod++;
    globalPool.sharesPerToken = sharesPerToken;

    emit IncreasedAssetPeriod(globalPool.currentPeriod, sharesPerToken);
  }

  /**
   * @dev Updates paused property which will revert any intecation with the contract.
   * Including transfer, mint, burn, or indexing updates.
   * It does not prevent contract upgrades
   */
  function pause() external onlyRole(GOV_ROLE) {
    _pause();
  }

    /**
   * @dev Updates paused property which will revert any intecation with the contract.
   * Including transfer, mint, burn, or indexing updates.
   * It does not prevent contract upgrades
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
    onlyOwner
    override
  {}
}
