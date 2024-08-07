// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DLSP} from "./DLSP.sol";
import {BondToken} from "./BondToken.sol";
import {LeverageToken} from "./LeverageToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract Pool is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {
  // Protocol
  DLSP public dlsp;
  uint256 public fee;

  // Tokens
  ERC20 public reserveToken;
  BondToken public dToken;
  LeverageToken public lToken;

  // Coupon
  ERC20 public couponToken;
  uint256 public sharesPerToken;

  // Distribution
  uint256 public distributionPeriod;
  uint256 public lastDistributionTime;

  error AccessDenied();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with the governance address and sets up roles.
   * This function is called once during deployment or upgrading to initialize state variables.
   */
  function initialize(
    address _dlsp,
    uint256 _fee,
    address _reserveToken,
    address _dToken,
    address _lToken,
    address _couponToken,
    uint256 _sharesPerToken,
    uint256 _distributionPeriod) initializer public {
    __UUPSUpgradeable_init();
    dlsp = DLSP(_dlsp);
    fee = _fee;
    reserveToken = ERC20(_reserveToken);
    dToken = BondToken(_dToken);
    lToken = LeverageToken(_lToken);
    couponToken = ERC20(_couponToken);
    sharesPerToken = _sharesPerToken;
    distributionPeriod = _distributionPeriod;
    lastDistributionTime = block.timestamp;
  }

  function Issue() external whenNotPaused() {

  }

  function Redeem() external whenNotPaused() {

  }

  function Swap() external whenNotPaused() {

  }

  /**
   * @dev Pauses contract. Reverts any interaction expect upgrade.
   */
  function pause() external onlyRole(dlsp.GOV_ROLE()) {
    _pause();
  }

  /**
   * @dev Unpauses contract.
   */
  function unpause() external onlyRole(dlsp.GOV_ROLE()) {
    _unpause();
  }

  modifier onlyRole(bytes32 role) {
    if (!dlsp.hasRole(role, msg.sender)) {
      revert AccessDenied();
    }
    _;
  }

  // @todo: owner will be DLSP, make sure we can upgrade
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
