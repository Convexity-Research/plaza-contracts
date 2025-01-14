// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {PoolFactory} from "./PoolFactory.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/**
 * @title LeverageToken
 * @dev This contract implements a leverage token with upgradeable capabilities, access control, and pausability.
 */
contract LeverageToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, PausableUpgradeable {
  
  /// @dev Role identifier for accounts with minting privileges
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  /// @dev Role identifier for accounts with governance privileges
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  /// @dev The pool factory
  PoolFactory public poolFactory;

  /// @dev Error thrown when the caller is not the security council
  error CallerIsNotSecurityCouncil();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with a name, symbol, minter, and governance address.
   * @param name The name of the token
   * @param symbol The symbol of the token
   * @param minter The address that will have minting privileges
   * @param governance The address that will have governance privileges
   */
  function initialize(
    string memory name, 
    string memory symbol, 
    address minter, 
    address governance,
    address _poolFactory
    ) initializer public {
    __ERC20_init(name, symbol);
    __ERC20Permit_init(name);
    __UUPSUpgradeable_init();
    __Pausable_init();

    poolFactory = PoolFactory(_poolFactory);

    _grantRole(MINTER_ROLE, minter);
    _grantRole(GOV_ROLE, governance);
    _setRoleAdmin(GOV_ROLE, GOV_ROLE);
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
   * @dev Internal function to update user assets after a transfer.
   * @param from The address tokens are transferred from
   * @param to The address tokens are transferred to
   * @param amount The amount of tokens transferred
   * @notice This function is called during token transfer and is paused when the contract is paused.
   */
  function _update(address from, address to, uint256 amount) internal virtual override whenNotPaused() {
    super._update(from, to, amount);
  }

  /**
   * @dev Pauses all token transfers, mints, burns, and indexing updates.
   * @notice Can only be called by addresses with the SECURITY_COUNCIL_ROLE. Does not prevent contract upgrades.
   */
  function pause() external onlySecurityCouncil {
    _pause();
  }

  /**
   * @dev Unpauses all token transfers, mints, burns, and indexing updates.
   * @notice Can only be called by addresses with the SECURITY_COUNCIL_ROLE.
   */
  function unpause() external onlySecurityCouncil {
    _unpause();
  }

  modifier onlySecurityCouncil() {
    if (!poolFactory.hasRole(poolFactory.SECURITY_COUNCIL_ROLE(), msg.sender)) {
      revert CallerIsNotSecurityCouncil();
    }
    _;
  }

  /**
   * @dev Internal function to authorize an upgrade to a new implementation.
   * @param newImplementation The address of the new implementation
   * @notice Can only be called by the owner of the contract.
   */
  function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(GOV_ROLE)
    override
  {}
}
