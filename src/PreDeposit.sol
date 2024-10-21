// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {BondToken} from "./BondToken.sol";
import {PoolFactory} from "./PoolFactory.sol";
import {LeverageToken} from "./LeverageToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PreDeposit is Ownable, ReentrancyGuard {

  // Initializing pool params
  address pool;
  PoolFactory private factory;
  PoolFactory.PoolParams private params;

  uint256 public reserveAmount;
  uint256 public reserveCap;

  uint256 private bondAmount;
  uint256 private leverageAmount;

  uint256 public depositEndTime;

  // Deposit balances
  mapping(address => uint256) public balances;

  // Events
  event PoolCreated(address indexed pool);
  event Deposit(address indexed user, uint256 amount);
  event Withdraw(address indexed user, uint256 amount);
  event Claimed(address indexed user, uint256 bondAmount, uint256 leverageAmount);

  // Errors
  error DepositEnded();
  error WithdrawEnded();
  error NothingToClaim();
  error DepositNotEnded();
  error NoReserveAmount();
  error InsufficientBalance();
  error InvalidReserveToken();
  error ClaimPeriodNotStarted();
  error InvalidBondOrLeverageAmount();
  error DepositCapReached();
  error CapMustIncrease();

  constructor(PoolFactory.PoolParams memory _params, address _factory, uint256 _depositEndTime, uint256 _reserveCap) Ownable(msg.sender) {
    if (_params.reserveToken == address(0)) revert InvalidReserveToken();
    params = _params;
    depositEndTime = _depositEndTime;
    reserveCap = _reserveCap;
    factory = PoolFactory(_factory);
  }

  function deposit(uint256 amount) external nonReentrant {
    if (block.timestamp > depositEndTime) revert DepositEnded();
    if (reserveAmount >= reserveCap) revert DepositCapReached();

    // if user would like to put more than available in cap, fill the rest up to cap and add that to reserves
    if (reserveAmount + amount >= reserveCap) {
      amount = reserveCap - reserveAmount;
    }

    balances[msg.sender] += amount;
    reserveAmount += amount;

    IERC20(params.reserveToken).transferFrom(msg.sender, address(this), amount);

    emit Deposit(msg.sender, amount);
  }

  function withdraw(uint256 amount) external nonReentrant {
    if (block.timestamp > depositEndTime) revert WithdrawEnded();

    if (balances[msg.sender] < amount) revert InsufficientBalance();
    balances[msg.sender] -= amount;
    reserveAmount -= amount;

    IERC20(params.reserveToken).transfer(msg.sender, amount);

    emit Withdraw(msg.sender, amount);
  }

  function createPool() external onlyOwner {
    if (block.timestamp < depositEndTime) revert DepositNotEnded();
    if (reserveAmount == 0) revert NoReserveAmount();
    if (bondAmount == 0 || leverageAmount == 0) revert InvalidBondOrLeverageAmount();

    IERC20(params.reserveToken).approve(address(factory), reserveAmount);
    pool = factory.CreatePool(params, reserveAmount, bondAmount, leverageAmount);

    emit PoolCreated(pool);
  }

  function claim() external nonReentrant {
    if (block.timestamp < depositEndTime) revert DepositNotEnded();
    if (pool == address(0)) revert ClaimPeriodNotStarted();
    
    uint256 userBalance = balances[msg.sender];
    if (userBalance == 0) revert NothingToClaim();

    BondToken bondToken = BondToken(Pool(pool).bondToken());
    LeverageToken leverageToken = LeverageToken(Pool(pool).lToken());

    uint256 userBondShare = (bondToken.balanceOf(address(this)) * userBalance) / reserveAmount;
    uint256 userLeverageShare = (leverageToken.balanceOf(address(this)) * userBalance) / reserveAmount;

    balances[msg.sender] = 0;

    if (userBondShare > 0) {
      bondToken.transfer(msg.sender, userBondShare);
    }
    if (userLeverageShare > 0) {
      leverageToken.transfer(msg.sender, userLeverageShare);
    }

    emit Claimed(msg.sender, userBondShare, userLeverageShare);
  }

  // admin functions
  function setParams(PoolFactory.PoolParams memory _params) external onlyOwner {
    if (_params.reserveToken == address(0)) revert InvalidReserveToken();
    if (_params.reserveToken != params.reserveToken) revert InvalidReserveToken();

    params = _params;
  }

  function setBondAndLeverageAmount(uint256 _bondAmount, uint256 _leverageAmount) external onlyOwner {
    bondAmount = _bondAmount;
    leverageAmount = _leverageAmount;
  }

  function increaseReserveCap(uint256 newReserveCap) external onlyOwner {
    if (newReserveCap <= reserveCap) revert CapMustIncrease();
    reserveCap = newReserveCap;
  }
}
