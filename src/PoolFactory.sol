// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Distributor} from "./Distributor.sol";
import {Pool} from "./Pool.sol";
import {Utils} from "./lib/Utils.sol";
import {BondToken} from "./BondToken.sol";
import {LeverageToken} from "./LeverageToken.sol";
import {TokenDeployer} from "./utils/TokenDeployer.sol";
import {ERC20Extensions} from "./lib/ERC20Extensions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

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
  /// @dev Number of pools created
  uint256 public poolsLength;
  /// @dev Address of the governance contract
  address public governance;
  /// @dev Address of the distributor contract
  address public distributor;
  /// @dev Address of the ETH price feed
  address private ethPriceFeed;
  /// @dev Instance of the TokenDeployer contract
  TokenDeployer private tokenDeployer;

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
   * @param _tokenDeployer Address of the TokenDeployer contract.
   * @param _distributor Address of the Distributor contract.
   * @param _ethPriceFeed Address of the ETH price feed.
   */
  function initialize(address _governance, address _tokenDeployer, address _distributor, address _ethPriceFeed) initializer public {
    __UUPSUpgradeable_init();

    tokenDeployer = TokenDeployer(_tokenDeployer);
    governance = _governance;
    distributor = _distributor;
    ethPriceFeed = _ethPriceFeed;
    _grantRole(GOV_ROLE, _governance);
  }

  /**
   * @dev Creates a new pool with the given parameters
   * @param params Struct containing pool parameters
   * @param reserveAmount Amount of reserve tokens to seed the pool
   * @param bondAmount Amount of bond tokens to mint
   * @param leverageAmount Amount of leverage tokens to mint
   * @return Address of the newly created pool
   */
  // @todo: make it payable (to accept native ETH)
  function CreatePool(PoolParams calldata params, uint256 reserveAmount, uint256 bondAmount, uint256 leverageAmount) external whenNotPaused() onlyRole(GOV_ROLE) returns (address) {
    // @todo: with this is safer but some cases are not testable (guess that's still good)
    // if (reserveAmount == 0) {
    //   revert ZeroReserveAmount();
    // }

    // if (bondAmount == 0) {
    //   revert ZeroDebtAmount();
    // }

    // if (leverageAmount == 0) {
    //   revert ZeroLeverageAmount();
    // }

    string memory reserveSymbol = IERC20(params.reserveToken).safeSymbol();
    
    // Deploy Bond token
    BondToken bondToken = BondToken(tokenDeployer.deployDebtToken(
      string.concat("Bond", reserveSymbol),
      string.concat("bond", reserveSymbol),
      address(this),
      address(this),
      distributor,
      params.sharesPerToken
    ));

    // Deploy Leverage token
    LeverageToken lToken = LeverageToken(tokenDeployer.deployLeverageToken(
      string.concat("Leverage", reserveSymbol),
      string.concat("lev", reserveSymbol),
      address(this),
      address(this)
    ));

    // Deploy pool contract
    address pool = Utils.deploy(address(new Pool()), abi.encodeCall(
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
        ethPriceFeed
      )
    ));

    Distributor(distributor).registerPool(pool, params.couponToken);

    bondToken.grantRole(MINTER_ROLE, pool);
    lToken.grantRole(MINTER_ROLE, pool);
    
    // set token governance
    bondToken.grantRole(GOV_ROLE, governance);
    lToken.grantRole(GOV_ROLE, governance);

    bondToken.grantRole(GOV_ROLE, pool);
    lToken.grantRole(GOV_ROLE, pool);

    // remove governance from factory
    bondToken.revokeRole(GOV_ROLE, address(this));
    lToken.revokeRole(GOV_ROLE, address(this));

    pools.push(pool);
    poolsLength = poolsLength + 1;
    emit PoolCreated(pool, reserveAmount, bondAmount, leverageAmount);

    // Send seed reserves to pool
    IERC20(params.reserveToken).safeTransferFrom(msg.sender, pool, reserveAmount);

    // Mint seed amounts
    bondToken.mint(msg.sender, bondAmount);
    lToken.mint(msg.sender, leverageAmount);

    return pool;
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
   * @param newImplementation Address of the new implementation
   */
  function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(GOV_ROLE)
    override
  {}
}
