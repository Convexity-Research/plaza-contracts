// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Distributor} from "./Distributor.sol";
import {Pool} from "./Pool.sol";
import {Utils} from "./lib/Utils.sol";
import {BondToken} from "./BondToken.sol";
import {LeverageToken} from "./LeverageToken.sol";
import {TokenDeployer} from "./utils/TokenDeployer.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract PoolFactory is Initializable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {  
  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  struct PoolParams {
    uint256 fee;
    address reserveToken;
    address couponToken;
    uint256 distributionPeriod;
  }

  address[] public pools;
  uint256 public poolsLength;
  address public governance;
  address public distributor;
  TokenDeployer private tokenDeployer;

  error ZeroDebtAmount();
  error ZeroReserveAmount();
  error ZeroLeverageAmount();

  event PoolCreated(address pool, uint256 reserveAmount, uint256 debtAmount, uint256 leverageAmount);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with the governance address and sets up roles.
   * This function is called once during deployment or upgrading to initialize state variables.
   * @param _governance Address of the governance account that will have the GOV_ROLE.
   */
  function initialize(address _governance, address _tokenDeployer, address _distributor) initializer public {
    __UUPSUpgradeable_init();

    tokenDeployer = TokenDeployer(_tokenDeployer);
    governance = _governance;
    distributor = _distributor;
    _grantRole(GOV_ROLE, _governance);
  }

  // @todo: make it payable (to accept native ETH)
  function CreatePool(PoolParams calldata params, uint256 reserveAmount, uint256 debtAmount, uint256 leverageAmount) external whenNotPaused() onlyRole(GOV_ROLE) returns (address) {
    // @todo: with this is safer but some cases are not testable (guess that's still good)
    // if (reserveAmount == 0) {
    //   revert ZeroReserveAmount();
    // }

    // if (debtAmount == 0) {
    //   revert ZeroDebtAmount();
    // }

    // if (leverageAmount == 0) {
    //   revert ZeroLeverageAmount();
    // }

    ERC20 reserveToken = ERC20(params.reserveToken);
    string memory reserveSymbol = reserveToken.symbol();
    
    // Deploy Bond token
    BondToken dToken = BondToken(tokenDeployer.deployDebtToken(
      string.concat("Bond", reserveSymbol),
      string.concat("BOND-", reserveSymbol),
      address(this),
      address(this),
      distributor,
      params.sharesPerToken
    ));

    // Deploy Leverage token
    LeverageToken lToken = LeverageToken(tokenDeployer.deployLeverageToken(
      string.concat("Leverage", reserveSymbol),
      string.concat("LVRG-", reserveSymbol),
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
        address(dToken),
        address(lToken),
        params.couponToken,
        params.distributionPeriod
      )
    ));

    Distributor(distributor).registerPool(pool, params.couponToken);

    dToken.grantRole(MINTER_ROLE, pool);
    lToken.grantRole(MINTER_ROLE, pool);
    
    // set token governance
    dToken.grantRole(GOV_ROLE, governance);
    lToken.grantRole(GOV_ROLE, governance);

    dToken.grantRole(GOV_ROLE, pool);
    lToken.grantRole(GOV_ROLE, pool);

    // remove governance from factory
    dToken.revokeRole(GOV_ROLE, address(this));
    lToken.revokeRole(GOV_ROLE, address(this));

    pools.push(pool);
    poolsLength = poolsLength + 1;
    emit PoolCreated(pool, reserveAmount, debtAmount, leverageAmount);

    // @todo: make it safeTransferFrom
    // Send seed reserves to pool
    if (!reserveToken.transferFrom(msg.sender, pool, reserveAmount)) {
      revert("failed to transfer funds");
    }

    // Mint seed amounts
    dToken.mint(msg.sender, debtAmount);
    lToken.mint(msg.sender, leverageAmount);

    return pool;
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
