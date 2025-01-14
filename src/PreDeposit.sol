// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {BondToken} from "./BondToken.sol";
import {PoolFactory} from "./PoolFactory.sol";
import {LeverageToken} from "./LeverageToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract PreDeposit is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, PausableUpgradeable {
  using SafeERC20 for IERC20;

  // Initializing pool params
  address public pool;
  PoolFactory private factory;
  PoolFactory.PoolParams private params;

  uint256 public reserveAmount;
  uint256 public reserveCap;

  uint256 private bondAmount;
  uint256 private leverageAmount;
  string private bondName;
  string private bondSymbol;
  string private leverageName;
  string private leverageSymbol;

  uint256 public depositStartTime;
  uint256 public depositEndTime;

  bool public poolCreated;

  // Deposit balances
  mapping(address => uint256) public balances;

  // Events
  event PoolCreated(address indexed pool);
  event DepositCapIncreased(uint256 newReserveCap);
  event Deposited(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event Claimed(address indexed user, uint256 bondAmount, uint256 leverageAmount);

  // Errors
  error DepositEnded();
  error NothingToClaim();
  error DepositNotEnded();
  error NoReserveAmount();
  error CapMustIncrease();
  error DepositCapReached();
  error InsufficientBalance();
  error InvalidReserveToken();
  error DepositNotYetStarted();
  error DepositAlreadyStarted();
  error ClaimPeriodNotStarted();
  error DepositEndMustBeAfterStart();
  error InvalidBondOrLeverageAmount();
  error DepositEndMustOnlyBeExtended();
  error DepositStartMustOnlyBeExtended();
  error PoolAlreadyCreated();
  
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with pool parameters and configuration.
   * @param _params Pool parameters struct
   * @param _factory Address of the pool factory
   * @param _depositStartTime Start time for deposits
   * @param _depositEndTime End time for deposits
   * @param _reserveCap Maximum reserve amount
   * @param _bondName Name of the bond token
   * @param _bondSymbol Symbol of the bond token
   * @param _leverageName Name of the leverage token
   * @param _leverageSymbol Symbol of the leverage token
   */
  function initialize(
    PoolFactory.PoolParams memory _params,
    address _factory,
    uint256 _depositStartTime,
    uint256 _depositEndTime,
    uint256 _reserveCap,
    string memory _bondName,
    string memory _bondSymbol,
    string memory _leverageName,
    string memory _leverageSymbol) initializer public {
    if (_params.reserveToken == address(0)) revert InvalidReserveToken();
    __UUPSUpgradeable_init();
    __ReentrancyGuard_init();
    __Ownable_init(msg.sender);
    params = _params;
    depositStartTime = _depositStartTime;
    depositEndTime = _depositEndTime;
    reserveCap = _reserveCap;
    factory = PoolFactory(_factory);
    bondName = _bondName;
    bondSymbol = _bondSymbol;
    leverageName = _leverageName;
    leverageSymbol = _leverageSymbol;
    poolCreated = false;
  }

  function deposit(uint256 amount, address onBehalfOf) external nonReentrant whenNotPaused {
    _deposit(amount, onBehalfOf);
  }

  function deposit(uint256 amount) external nonReentrant whenNotPaused {
    _deposit(amount, address(0));
  }

  function _deposit(uint256 amount, address onBehalfOf) private checkDepositStarted checkDepositNotEnded {
    if (reserveAmount >= reserveCap) revert DepositCapReached();

    address recipient = onBehalfOf == address(0) ? msg.sender : onBehalfOf;

    // if user would like to put more than available in cap, fill the rest up to cap and add that to reserves
    if (reserveAmount + amount >= reserveCap) {
      amount = reserveCap - reserveAmount;
    }

    balances[recipient] += amount;
    reserveAmount += amount;

    IERC20(params.reserveToken).safeTransferFrom(msg.sender, address(this), amount);

    emit Deposited(recipient, amount);
  }

  function withdraw(uint256 amount) external nonReentrant whenNotPaused checkDepositStarted checkDepositNotEnded {
    if (balances[msg.sender] < amount) revert InsufficientBalance();
    balances[msg.sender] -= amount;
    reserveAmount -= amount;

    IERC20(params.reserveToken).safeTransfer(msg.sender, amount);

    emit Withdrawn(msg.sender, amount);
  }

  /**
   * @dev Creates a new pool using the accumulated deposits after deposit period ends.
   */
  function createPool() external nonReentrant whenNotPaused checkDepositEnded {
    if (reserveAmount == 0) revert NoReserveAmount();
    if (bondAmount == 0 || leverageAmount == 0) revert InvalidBondOrLeverageAmount();
    if (poolCreated) revert PoolAlreadyCreated();
    IERC20(params.reserveToken).approve(address(factory), reserveAmount);
    pool = factory.createPool(params, reserveAmount, bondAmount, leverageAmount, bondName, bondSymbol, leverageName, leverageSymbol, true);

    emit PoolCreated(pool);
    poolCreated = true;
  }

  /**
   * @dev Allows users to claim their share of bond and leverage tokens after pool creation.
   */
  function claim() external nonReentrant whenNotPaused checkDepositEnded {
    if (pool == address(0)) revert ClaimPeriodNotStarted();
    
    uint256 userBalance = balances[msg.sender];
    if (userBalance == 0) revert NothingToClaim();

    address bondToken = address(Pool(pool).bondToken());
    address leverageToken = address(Pool(pool).lToken());

    uint256 userBondShare = (bondAmount * userBalance) / reserveAmount;
    uint256 userLeverageShare = (leverageAmount * userBalance) / reserveAmount;

    balances[msg.sender] = 0;

    if (userBondShare > 0) {
      IERC20(bondToken).safeTransfer(msg.sender, userBondShare);
    }
    if (userLeverageShare > 0) {
      IERC20(leverageToken).safeTransfer(msg.sender, userLeverageShare);
    }

    emit Claimed(msg.sender, userBondShare, userLeverageShare);
  }

  /**
   * @dev Updates pool parameters. Can only be called by owner before deposit end time.
   * @param _params New pool parameters
   */
  function setParams(PoolFactory.PoolParams memory _params) external onlyOwner checkDepositNotEnded {
    if (_params.reserveToken == address(0)) revert InvalidReserveToken();
    if (_params.reserveToken != params.reserveToken) revert InvalidReserveToken();
    if (poolCreated) revert PoolAlreadyCreated();

    params = _params;
  }

  /**
   * @dev Sets the bond and leverage token amounts. Can only be called by owner before deposit end time.
   * @param _bondAmount Amount of bond tokens
   * @param _leverageAmount Amount of leverage tokens
   */
  function setBondAndLeverageAmount(uint256 _bondAmount, uint256 _leverageAmount) external onlyOwner checkDepositNotEnded {
    if (poolCreated) revert PoolAlreadyCreated();

    bondAmount = _bondAmount;
    leverageAmount = _leverageAmount;
  }

  /**
   * @dev Increases the reserve cap. Can only be called by owner before deposit end time.
   * @param newReserveCap New maximum reserve amount
   */
  function increaseReserveCap(uint256 newReserveCap) external onlyOwner checkDepositNotEnded {
    if (newReserveCap <= reserveCap) revert CapMustIncrease();
    if (poolCreated) revert PoolAlreadyCreated();
    reserveCap = newReserveCap;

    emit DepositCapIncreased(newReserveCap);
  }

  /**
   * @dev Updates the deposit start time. Can only be called by owner before current start time.
   * @param newDepositStartTime New deposit start timestamp
   */
  function setDepositStartTime(uint256 newDepositStartTime) external onlyOwner {
    if (block.timestamp >= depositStartTime) revert DepositAlreadyStarted();
    if (newDepositStartTime <= depositStartTime) revert DepositStartMustOnlyBeExtended();
    if (newDepositStartTime >= depositEndTime) revert DepositEndMustBeAfterStart();

    depositStartTime = newDepositStartTime;
  }

  /**
   * @dev Updates the deposit end time. Can only be called by owner before current end time.
   * @param newDepositEndTime New deposit end timestamp
   */
  function setDepositEndTime(uint256 newDepositEndTime) external onlyOwner checkDepositNotEnded {
    if (newDepositEndTime <= depositEndTime) revert DepositEndMustOnlyBeExtended();
    if (newDepositEndTime <= depositStartTime) revert DepositEndMustBeAfterStart();
    if (poolCreated) revert PoolAlreadyCreated();
    
    depositEndTime = newDepositEndTime;
  }

  /**
   * @dev Pauses the contract. Reverts any interaction except upgrade.
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @dev Unpauses the contract.
   */
  function unpause() external onlyOwner {
    _unpause();
  }

  /**
   * @dev Authorizes an upgrade to a new implementation.
   * Can only be called by the owner of the contract.
   * @param newImplementation The address of the new implementation.
   */
  function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
  {}

  modifier checkDepositNotEnded() {
    if (block.timestamp >= depositEndTime) revert DepositEnded();
    _;
  }

  modifier checkDepositStarted() {
    if (block.timestamp < depositStartTime) revert DepositNotYetStarted();
    _;
  }

  modifier checkDepositEnded() {
    if (block.timestamp < depositEndTime) revert DepositNotEnded();
    _;
  }
}
