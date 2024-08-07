// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

contract BondToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
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

  bool public paused;

  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
  bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

  event IncreasedAssetPeriod(uint256 currentPeriod, uint256 sharesPerToken);
  event UpdatedUserAssets(address user, uint256 lastUpdatedPeriod, uint256 indexedAmountShares);
  event ContractPause(bool paused);

  error ContractPaused();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(string memory name, string memory symbol, address minter, address governance) initializer public {
    __ERC20_init(name, symbol);
    __ERC20Permit_init(name);
    __UUPSUpgradeable_init();

    // Grant ADMIN_ROLE to deployer
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

    // Grant the MINTER_ROLE to the specified minter address
    _grantRole(MINTER_ROLE, minter);

    // Grant the GOV_ROLE to the governance address
    _grantRole(GOV_ROLE, governance);
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
   * @dev Internal function to update user assets after a transfer.
   * Called during token transfer.
   */
  function _update(address from, address to, uint256 amount) internal virtual override {
    if (paused) {
      revert ContractPaused();
    }

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
  function resetIndexedUserAssets(address user) external onlyRole(DISTRIBUTOR_ROLE) {
    if (paused) {
      revert ContractPaused();
    }
    userAssets[user].lastUpdatedPeriod = globalPool.currentPeriod;
    userAssets[user].indexedAmountShares = 0;
  }

  /**
   * @dev Increases the current period and updates the shares per token.
   * Can only be called by addresses with the GOV_ROLE.
   */
  function increaseIndexedAssetPeriod(uint256 sharesPerToken) public onlyRole(GOV_ROLE) {
    if (paused) {
      revert ContractPaused();
    }

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
    paused = !paused;
    emit ContractPause(paused);
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
