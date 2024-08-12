// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {Utils} from "./lib/Utils.sol";
import {BondToken} from "../src/BondToken.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
    address couponToken;
    uint256 sharesPerToken;
    uint256 distributionPeriod;
  }

  address[] public pools;
  address public governance;
  address public distributor;

  event PoolCreated(address pool);

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

  // @todo: make it GOV_ROLE
  // @todo: make it payable (to accept native ETH)
  function CreatePool(PoolParams calldata params, uint256 reserveAmount, uint256 debtAmount, uint256 leverageAmount) external whenNotPaused() returns (address) {
    ERC20 reserveToken = ERC20(params.reserveToken);
    string memory reserveSymbol = reserveToken.symbol();

    // Deploy Bond token
    BondToken dToken = BondToken(Utils.deploy(address(new BondToken()), abi.encodeCall(
      BondToken.initialize, 
      (
        string.concat("Bond", reserveSymbol),
        string.concat("BOND-", reserveSymbol),
        address(this),
        governance,
        distributor
      )
    )));

    // Deploy Leverage token
    LeverageToken lToken = LeverageToken(Utils.deploy(address(new LeverageToken()), abi.encodeCall(
      LeverageToken.initialize, 
      (
        string.concat("Leverage", reserveSymbol),
        string.concat("LVRG-", reserveSymbol),
        address(this),
        governance
      )
    )));

    // Deploy pool contract
    address pool = Utils.deploy(address(new Pool()), abi.encodeCall(
      Pool.initialize, 
      (
        address(this),
        params.fee,
        params.reserveToken,
        address(dToken),
        address(lToken),
        params.couponToken,
        params.sharesPerToken,
        params.distributionPeriod
      )
    ));

    pools.push(pool);
    emit PoolCreated(pool);

    // @todo: make it safeTransferFrom
    // Send seed reserves to pool
    reserveToken.transferFrom(msg.sender, pool, reserveAmount);

    // Mint seed amounts
    dToken.mint(msg.sender, debtAmount);
    lToken.mint(msg.sender, leverageAmount);

    return pool;
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
