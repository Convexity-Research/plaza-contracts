// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

contract LeverageToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, PausableUpgradeable {
  
  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    string memory name, 
    string memory symbol, 
    address minter, 
    address governance
    ) initializer public {
    __ERC20_init(name, symbol);
    __ERC20Permit_init(name);
    __UUPSUpgradeable_init();

    // Grant the access roles
    _grantRole(MINTER_ROLE, minter);
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
  function _update(address from, address to, uint256 amount) internal virtual override whenNotPaused() {
    super._update(from, to, amount);
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
