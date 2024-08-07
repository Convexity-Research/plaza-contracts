// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// import {BondToken} from "./BondToken.sol";
// import {LeverageToken} from "./LeverageToken.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pool} from "./Pool.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract DLSP is Initializable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {

  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  struct PoolParams {
    uint256 fee;
    address reserveToken;
    address dToken;
    address lToken;
    address couponToken;
    uint256 sharesPerToken;
    uint256 distributionPeriod;
  }

  Pool[] public pools;
  address public governance;

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

    governance = _governance;
    _grantRole(GOV_ROLE, _governance);
  }

  function CreatePool(PoolParams calldata params) external whenNotPaused() returns (address) {
    Pool pool = _deployPool(params);
    pools.push(pool);

    return address(pool);
  }

  function Issue() external whenNotPaused() {

  }

  function Redeem() external whenNotPaused() {

  }

  function Swap() external whenNotPaused() {

  }

  function _deployPool(PoolParams calldata params) private returns (Pool) {
    // Deploy and initialize Pool
    Pool implementation = new Pool();

    // Deploy the proxy and initialize the contract through the proxy
    return Pool(address(new ERC1967Proxy(
      address(implementation), 
      abi.encodeCall(
        implementation.initialize, 
        (
          address(this),
          params.fee,
          params.reserveToken,
          params.dToken,
          params.lToken,
          params.couponToken,
          params.sharesPerToken,
          params.distributionPeriod
        )
      )
    )));
  }

  function setGovernance(address _governance) external onlyRole(GOV_ROLE) {
    _grantRole(GOV_ROLE, _governance);
    _revokeRole(GOV_ROLE, governance);
    governance = _governance;
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
    onlyOwner
    override
  {}
}
