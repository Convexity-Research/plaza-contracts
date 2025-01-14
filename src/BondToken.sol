// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Decimals} from "./lib/Decimals.sol";
import {PoolFactory} from "./PoolFactory.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/**
 * @title BondToken
 * @dev This contract implements a bond token with upgradeable capabilities, access control, and pausability.
 * It includes functionality for managing indexed user assets and global asset pools.
 */
contract BondToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, PausableUpgradeable {  
  using Decimals for uint256;

  /**
   * @dev Struct to represent a pool's outstanding shares and shares per bond at a specific period
   * @param period The period of the pool amount
   * @param amount The total amount in the pool
   * @param sharesPerToken The number of shares per token (base 10000)
   */
  struct PoolAmount {
    uint256 period;
    uint256 amount;
    uint256 sharesPerToken;
  }

  /**
   * @dev Struct to represent the global asset pool, including the current period, shares per token, and previous pool amounts.
   * @param currentPeriod The current period of the global pool
   * @param sharesPerToken The current number of shares per token (base 10000)
   * @param previousPoolAmounts An array of previous pool amounts
   */
  struct IndexedGlobalAssetPool {
    uint256 currentPeriod;
    uint256 sharesPerToken;
    PoolAmount[] previousPoolAmounts;
  }

  /**
   * @dev Struct to represent a user's indexed assets, which are the user's shares
   * @param lastUpdatedPeriod The last period when the user's assets were updated
   * @param indexedAmountShares The user's indexed amount of shares
   */
  struct IndexedUserAssets {
    uint256 lastUpdatedPeriod;
    uint256 indexedAmountShares;
  }

  /// @dev The global asset pool
  IndexedGlobalAssetPool public globalPool;
  /// @dev Pool factory address
  PoolFactory public poolFactory;

  /// @dev Mapping of user addresses to their indexed assets
  mapping(address => IndexedUserAssets) public userAssets;

  /// @dev Role identifier for accounts with minting privileges
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  /// @dev Role identifier for accounts with governance privileges
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
  /// @dev Role identifier for the distributor
  bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

  /// @dev The number of decimals for shares
  uint8 public constant SHARES_DECIMALS = 6;

  /// @dev Error thrown when the caller is not the security council
  error CallerIsNotSecurityCouncil();

  /// @dev Emitted when the asset period is increased
  event IncreasedAssetPeriod(uint256 currentPeriod, uint256 sharesPerToken);
  /// @dev Emitted when a user's assets are updated
  event UpdatedUserAssets(address user, uint256 lastUpdatedPeriod, uint256 indexedAmountShares);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with a name, symbol, minter, governance address, distributor, and initial shares per token.
   * @param name The name of the token
   * @param symbol The symbol of the token
   * @param minter The address that will have minting privileges
   * @param governance The address that will have governance privileges
   * @param sharesPerToken The initial number of shares per token
   */
  function initialize(
    string memory name, 
    string memory symbol, 
    address minter, 
    address governance,
    address _poolFactory,
    uint256 sharesPerToken
    ) initializer public {

    __ERC20_init(name, symbol);
    __ERC20Permit_init(name);
    __UUPSUpgradeable_init();
    __Pausable_init();

    poolFactory = PoolFactory(_poolFactory);
    globalPool.sharesPerToken = sharesPerToken;

    _grantRole(MINTER_ROLE, minter);
    _grantRole(GOV_ROLE, governance);

    _setRoleAdmin(GOV_ROLE, GOV_ROLE);
    _setRoleAdmin(DISTRIBUTOR_ROLE, GOV_ROLE);
    _setRoleAdmin(MINTER_ROLE, MINTER_ROLE);
  }

  /**
   * @dev Mints new tokens to the specified address.
   * @param to The address that will receive the minted tokens
   * @param amount The amount of tokens to mint
   * @notice Can only be called by addresses with the MINTER_ROLE.
   */
  function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    _mint(to, amount);
  }

  /**
   * @dev Burns tokens from the specified account.
   * @param account The account from which tokens will be burned
   * @param amount The amount of tokens to burn
   * @notice Can only be called by addresses with the MINTER_ROLE.
   */
  function burn(address account, uint256 amount) public onlyRole(MINTER_ROLE) {
    _burn(account, amount);
  }

  /**
   * @dev Returns the previous pool amounts from the global pool.
   * @return An array of PoolAmount structs representing the previous pool amounts
   */
  function getPreviousPoolAmounts() external view returns (PoolAmount[] memory) {
    return globalPool.previousPoolAmounts;
  }

  /**
   * @dev Internal function to update user assets after a transfer.
   * @param from The address tokens are transferred from
   * @param to The address tokens are transferred to
   * @param amount The amount of tokens transferred
   * @notice This function is called during token transfer and is paused when the contract is paused.
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
   * @param user The address of the user
   * @param balance The current balance of the user
   * @notice This function updates the number of shares held by the user based on the current period.
   */
  function updateIndexedUserAssets(address user, uint256 balance) internal {
    uint256 period = globalPool.currentPeriod;
    uint256 shares = getIndexedUserAmount(user, balance, period);
    
    userAssets[user].indexedAmountShares = shares;
    userAssets[user].lastUpdatedPeriod = period;

    emit UpdatedUserAssets(user, period, shares);
  }

  /**
   * @dev Returns the indexed amount of shares for a specific user.
   * @param user The address of the user
   * @param balance The current balance of the user
   * @param period The period to calculate the shares for
   * @return The indexed amount of shares for the user
   * @notice This function calculates the number of shares based on the current period and the previous pool amounts.
   */
  function getIndexedUserAmount(address user, uint256 balance, uint256 period) public view returns(uint256) {
    IndexedUserAssets memory userPool = userAssets[user];
    uint256 shares = userPool.indexedAmountShares;

    for (uint256 i = userPool.lastUpdatedPeriod; i < period; i++) {
      shares += (balance * globalPool.previousPoolAmounts[i].sharesPerToken).toBaseUnit(SHARES_DECIMALS);
    }

    return shares;
  }

  /**
   * @dev Resets the indexed user assets for a specific user.
   * @param user The address of the user
   * @notice This function resets the last updated period and indexed amount of shares to zero.
   * Can only be called by addresses with the DISTRIBUTOR_ROLE and when the contract is not paused.
   */
  function resetIndexedUserAssets(address user) external onlyRole(DISTRIBUTOR_ROLE) whenNotPaused(){
    userAssets[user].lastUpdatedPeriod = globalPool.currentPeriod;
    userAssets[user].indexedAmountShares = 0;
  }

  /**
   * @dev Increases the current period and updates the shares per token.
   * @param sharesPerToken The new number of shares per token
   * @notice Can only be called by addresses with the GOV_ROLE and when the contract is not paused.
   */
  function increaseIndexedAssetPeriod(uint256 sharesPerToken) public onlyRole(DISTRIBUTOR_ROLE) whenNotPaused() {
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
   * @dev Pauses all contract functions except for upgrades.
   * Requirements:
   * - the caller must have the `SECURITY_COUNCIL_ROLE` from the pool factory.
   */
  function pause() external onlySecurityCouncil() {
    _pause();
  }

  /**
   * @dev Unpauses all contract functions.
   * Requirements:
   * - the caller must have the `SECURITY_COUNCIL_ROLE`.
   */
  function unpause() external onlySecurityCouncil() {
    _unpause();
  }

  modifier onlySecurityCouncil() {
    if (!poolFactory.hasRole(poolFactory.SECURITY_COUNCIL_ROLE(), msg.sender)) {
      revert CallerIsNotSecurityCouncil();
    }
    _;
  }

  /**
   * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
   * {upgradeTo} and {upgradeToAndCall}.
   * @param newImplementation Address of the new implementation contract
   * @notice Can only be called by addresses with the GOV_ROLE.
   */
  function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(GOV_ROLE)
    override
  {}
}
