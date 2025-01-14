// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {BondToken} from "./BondToken.sol";
import {Distributor} from "./Distributor.sol";
import {LeverageToken} from "./LeverageToken.sol";
import {Create3} from "@create3/contracts/Create3.sol";
import {Deployer} from "./utils/Deployer.sol";
import {ERC20Extensions} from "./lib/ERC20Extensions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title PoolFactory
 * @dev This contract is responsible for creating and managing pools.
 * It inherits from various OpenZeppelin upgradeable contracts for enhanced functionality and security.
 */
contract PoolFactory is Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {
  using SafeERC20 for IERC20;
  using ERC20Extensions for IERC20;

  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
  bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant SECURITY_COUNCIL_ROLE = keccak256("SECURITY_COUNCIL_ROLE");
  struct PoolParams {
    uint256 fee;
    address reserveToken;
    address couponToken;
    uint256 distributionPeriod;
    uint256 sharesPerToken;
    address feeBeneficiary;
  }

  /// @dev Array to store addresses of created pools
  address[] public pools;
  /// @dev Address of the governance contract
  address public governance;
  /// @dev Address of the OracleFeeds contract
  address public oracleFeeds;
  /// @dev Instance of the Deployer contract
  Deployer private deployer;
  /// @dev Address of the UpgradeableBeacon for Pool
  address public poolBeacon;
  /// @dev Address of the UpgradeableBeacon for BondToken
  address public bondBeacon;
  /// @dev Address of the UpgradeableBeacon for LeverageToken
  address public leverageBeacon;
  /// @dev Address of the UpgradeableBeacon for Distributor
  address public distributorBeacon;
  /// @dev Mapping to store distributor addresses for each pool
  mapping(address => address) public distributors;

  /// @dev Error thrown when bond amount is zero
  error ZeroDebtAmount();
  /// @dev Error thrown when reserve amount is zero
  error ZeroReserveAmount();
  /// @dev Error thrown when leverage amount is zero
  error ZeroLeverageAmount();

  /**
   * @dev Emitted when a new pool is created
   * @param pool Address of the newly created pool
   * @param reserveAmount Amount of reserve tokens
   * @param bondAmount Amount of bond tokens
   * @param leverageAmount Amount of leverage tokens
   */
  event PoolCreated(address pool, uint256 reserveAmount, uint256 bondAmount, uint256 leverageAmount);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with the governance address and sets up roles.
   * This function is called once during deployment or upgrading to initialize state variables.
   * @param _governance Address of the governance account that will have the GOV_ROLE.
   * @param _deployer Address of the Deployer contract.
   * @param _oracleFeeds Address of the OracleFeeds contract.
   * @param _poolImplementation Address of the Pool implementation contract.
   * @param _bondImplementation Address of the BondToken implementation contract.
   * @param _leverageImplementation Address of the LeverageToken implementation contract.
   * @param _distributorImplementation Address of the Distributor implementation contract.
   */
  function initialize(
    address _governance,
    address _deployer,
    address _oracleFeeds,
    address _poolImplementation,
    address _bondImplementation,
    address _leverageImplementation,
    address _distributorImplementation
  ) initializer public {
    __UUPSUpgradeable_init();
    __Pausable_init();

    deployer = Deployer(_deployer);
    governance = _governance;
    oracleFeeds = _oracleFeeds;
    _grantRole(GOV_ROLE, _governance);

    // Stores beacon implementation addresses
    poolBeacon = _poolImplementation;
    bondBeacon = _bondImplementation;
    leverageBeacon = _leverageImplementation;
    distributorBeacon = _distributorImplementation;
  }

  /**
   * @dev Creates a new pool with the given parameters
   * @param params Struct containing pool parameters
   * @param reserveAmount Amount of reserve tokens to seed the pool
   * @param bondAmount Amount of bond tokens to mint
   * @param leverageAmount Amount of leverage tokens to mint
   * @return Address of the newly created pool
   */
  function createPool(
    PoolParams calldata params,
    uint256 reserveAmount,
    uint256 bondAmount,
    uint256 leverageAmount,
    string memory bondName,
    string memory bondSymbol,
    string memory leverageName,
    string memory leverageSymbol,
    bool pauseOnCreation
  ) external whenNotPaused() onlyRole(POOL_ROLE) returns (address) {

    if (reserveAmount == 0) {
      revert ZeroReserveAmount();
    }

    if (bondAmount == 0) {
      revert ZeroDebtAmount();
    }

    if (leverageAmount == 0) {
      revert ZeroLeverageAmount();
    }
    
    // Deploy Bond token
    BondToken bondToken = BondToken(deployer.deployBondToken(
      bondBeacon,
      bondName,
      bondSymbol,
      address(this),
      address(this),
      address(this),
      params.sharesPerToken
    ));

    // Deploy Leverage token
    LeverageToken lToken = LeverageToken(deployer.deployLeverageToken(
      leverageBeacon,
      leverageName,
      leverageSymbol,
      address(this),
      address(this),
      address(this)
    ));

    // Deploy pool contract as a BeaconProxy
    bytes memory initData = abi.encodeCall(
      Pool.initialize, 
      (
        address(this),
        params.fee,
        params.reserveToken,
        address(bondToken),
        address(lToken),
        params.couponToken,
        params.sharesPerToken,
        params.distributionPeriod,
        params.feeBeneficiary,
        oracleFeeds,
        pauseOnCreation
      )
    );

    address pool = Create3.create3(
      keccak256(
        abi.encodePacked(
          params.reserveToken,
          params.couponToken,
          bondToken.symbol(),
          lToken.symbol()
        )
      ),
      abi.encodePacked(
        type(BeaconProxy).creationCode,
        abi.encode(poolBeacon, initData)
      )
    );

    // Deploy Distributor contract
    Distributor distributor = Distributor(deployer.deployDistributor(
      distributorBeacon,
      pool,
      address(this)
    ));

    distributors[pool] = address(distributor);

    bondToken.grantRole(MINTER_ROLE, pool);
    lToken.grantRole(MINTER_ROLE, pool);

    bondToken.grantRole(bondToken.DISTRIBUTOR_ROLE(), pool);
    bondToken.grantRole(bondToken.DISTRIBUTOR_ROLE(), address(distributor));
    
    // set token governance
    bondToken.grantRole(GOV_ROLE, governance);
    lToken.grantRole(GOV_ROLE, governance);

    // renounce governance from factory
    bondToken.revokeRole(GOV_ROLE, address(this));
    lToken.revokeRole(GOV_ROLE, address(this));

    pools.push(pool);
    emit PoolCreated(pool, reserveAmount, bondAmount, leverageAmount);

    // Send seed reserves to pool
    IERC20(params.reserveToken).safeTransferFrom(msg.sender, pool, reserveAmount);

    // Mint seed amounts
    bondToken.mint(msg.sender, bondAmount);
    lToken.mint(msg.sender, leverageAmount);
    
    // Revoke minter role from factory
    bondToken.revokeRole(MINTER_ROLE, address(this));
    lToken.revokeRole(MINTER_ROLE, address(this));

    return pool;
  }

  /**
  * @dev Returns the number of pools created.
  * @return The length of the pools array.
  */
  function poolsLength() external view returns (uint256) {
    return pools.length;
  }
  
  /**
   * @dev Grants `role` to `account`.
   * If `account` had not been already granted `role`, emits a {RoleGranted} event.
   * @param role The role to grant
   * @param account The account to grant the role to
   */
  function grantRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE) {
    _grantRole(role, account);
  }

  /**
   * @dev Revokes `role` from `account`.
   * If `account` had been granted `role`, emits a {RoleRevoked} event.
   * @param role The role to revoke
   * @param account The account to revoke the role from
   */
  function revokeRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE) {
    _revokeRole(role, account);
  }

  /**
   * @dev Pauses contract. Reverts any interaction except upgrade.
   */
  function pause() external onlyRole(SECURITY_COUNCIL_ROLE) {
    _pause();
  }

  /**
   * @dev Unpauses contract.
   */
  function unpause() external onlyRole(SECURITY_COUNCIL_ROLE) {
    _unpause();
  }

  /**
   * @dev Authorizes an upgrade to a new implementation.
   * Can only be called by the owner of the contract.
   * @param newImplementation Address of the new implementation
   */
  function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(GOV_ROLE)
    override
  {}
}
