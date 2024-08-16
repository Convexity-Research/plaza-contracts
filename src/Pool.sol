// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {PoolFactory} from "./PoolFactory.sol";
import {BondToken} from "./BondToken.sol";
import {LeverageToken} from "./LeverageToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract Pool is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {
  // uint public constant MINIMUM_LIQUIDITY = 10**3;
  uint256 private constant POINT_EIGHT = 800000; // 1000000 precision | 800000=0.8
  uint256 private constant POINT_TWO = 200000;
  uint256 private constant COLLATERAL_THRESHOLD = 1200000;
  uint256 private constant PRECISION = 1000000;
  uint256 private constant BOND_TARGET_PRICE = 100;

  // @todo: get price from oracle
  uint256 private constant ETH_PRICE = 3000;

  // Protocol
  PoolFactory public poolFactory;
  uint256 public fee;

  // Tokens
  address public reserveToken;
  BondToken public dToken;
  LeverageToken public lToken;

  // Coupon
  address public couponToken;
  uint256 public sharesPerToken;

  // Distribution
  uint256 public distributionPeriod;
  uint256 public lastDistributionTime;

  enum TokenType {
    DEBT,
    LEVERAGE
  }

  error MinAmount();
  error ZeroAmount();
  error AccessDenied();
  error ZeroDebtSupply();
  error ZeroLeverageSupply();

  event TokensCreated(address caller, TokenType tokenType, uint256 depositedAmount, uint256 mintedAmount);
  event TokensRedeemed(address caller, TokenType tokenType, uint256 depositedAmount, uint256 redeemedAmount);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with the governance address and sets up roles.
   * This function is called once during deployment or upgrading to initialize state variables.
   */
  function initialize(
    address _poolFactory,
    uint256 _fee,
    address _reserveToken,
    address _dToken,
    address _lToken,
    address _couponToken,
    uint256 _sharesPerToken,
    uint256 _distributionPeriod) initializer public {
    __UUPSUpgradeable_init();
    poolFactory = PoolFactory(_poolFactory);
    fee = _fee;
    reserveToken = _reserveToken;
    dToken = BondToken(_dToken);
    lToken = LeverageToken(_lToken);
    couponToken = _couponToken;
    sharesPerToken = _sharesPerToken;
    distributionPeriod = _distributionPeriod;
    lastDistributionTime = block.timestamp;
  }

  /**
    * @dev Transfers `depositAmount` of `reserveToken` from the caller, calculates the amount to mint
    * If the amount is valid, mints the appropriate token (dToken or lToken) to the caller.
    * 
    * @param tokenType The type of token to mint (DEBT or LEVERAGE).
    * @param depositAmount The amount of `reserveToken` to deposit.
    * @param minAmount The minimum amount of tokens to mint to avoid slippage.
    * @return The amount of tokens minted.
    */
  function create(TokenType tokenType, uint256 depositAmount, uint256 minAmount) external whenNotPaused() returns(uint256) {
    // Get amount to mint
    uint256 amount = simulateCreate(tokenType, depositAmount);

    // @todo: replace with safeTransfer  
    require(ERC20(reserveToken).transferFrom(msg.sender, address(this), depositAmount), "failed to deposit");
    
    // Check slippage
    if (amount < minAmount) {
      revert MinAmount();
    }

    // Mint amount should be higher than zero
    if (amount == 0) {
      revert ZeroAmount();
    }

    // Mint tokens
    if (tokenType == TokenType.DEBT) {
      dToken.mint(msg.sender, amount);
    } else {
      lToken.mint(msg.sender, amount);
    }

    emit TokensCreated(msg.sender, tokenType, depositAmount, amount);
    return amount;
  }

  function simulateCreate(TokenType tokenType, uint256 depositAmount) public view returns(uint256) {
    return getCreateAmount(
      tokenType,
      depositAmount,
      dToken.totalSupply(),
      lToken.totalSupply(),
      ERC20(reserveToken).balanceOf(address(this)),
      ETH_PRICE
    );
  }

  function getCreateAmount(
    TokenType tokenType,
    uint256 depositAmount,
    uint256 debtSupply, 
    uint256 levSupply, 
    uint256 poolReserves, 
    uint256 ethPrice) public pure returns(uint256) {
    if (debtSupply == 0) {
      revert ZeroDebtSupply();
    }

    uint256 assetSupply = debtSupply;
    uint256 multiplier = POINT_EIGHT;
    if (tokenType == TokenType.LEVERAGE) {
      multiplier = POINT_TWO;
      assetSupply = levSupply;
    }

    uint256 tvl = ethPrice * poolReserves;
    uint256 collateralLevel = (tvl * PRECISION) / (debtSupply * BOND_TARGET_PRICE);
    uint256 creationRate = BOND_TARGET_PRICE * PRECISION;

    if (collateralLevel <= COLLATERAL_THRESHOLD) {
      creationRate = (tvl * multiplier) / assetSupply;
    } else if (tokenType == TokenType.LEVERAGE) {
      if (assetSupply == 0) {
        revert ZeroLeverageSupply();
      }

      uint256 adjustedValue = tvl - (BOND_TARGET_PRICE * debtSupply);
      creationRate = (adjustedValue * PRECISION) / assetSupply;
    }
    
    return (depositAmount * ethPrice * PRECISION) / creationRate;
  }

  function redeem(TokenType tokenType, uint256 depositAmount, uint256 minAmount) external whenNotPaused() returns(uint256) {
    // Get amount to mint
    uint256 reserveAmount = simulateRedeem(tokenType, depositAmount);

    // Check slippage
    if (reserveAmount < minAmount) {
      revert MinAmount();
    }

    // Reserve amount should be higher than zero
    if (reserveAmount == 0) {
      revert ZeroAmount();
    }

    // Burn tokens
    if (tokenType == TokenType.DEBT) {
      dToken.burn(msg.sender, depositAmount);
    } else {
      lToken.burn(msg.sender, depositAmount);
    }

    emit TokensRedeemed(msg.sender, tokenType, depositAmount, reserveAmount);
    return reserveAmount;
  }

  function simulateRedeem(TokenType tokenType, uint256 depositAmount) public view whenNotPaused() returns(uint256) {
    return getRedeemAmount(
      tokenType,
      depositAmount,
      dToken.totalSupply(),
      lToken.totalSupply(),
      ERC20(reserveToken).balanceOf(address(this)),
      ETH_PRICE
    );
  }

  function getRedeemAmount(
    TokenType tokenType,
    uint256 depositAmount,
    uint256 debtSupply,
    uint256 levSupply,
    uint256 poolReserves,
    uint256 ethPrice) public pure returns(uint256) {
    if (debtSupply == 0) {
      revert ZeroDebtSupply();
    }

    uint256 tvl = ethPrice * poolReserves;
    uint256 assetSupply = debtSupply;
    uint256 multiplier = POINT_EIGHT;

    // @todo: is '100' the BOND_TARGET_PRICE?
    uint256 collateralLevel = ((tvl - (depositAmount * 100)) * PRECISION) / ((debtSupply - depositAmount) * BOND_TARGET_PRICE);

    if (tokenType == TokenType.LEVERAGE) {
      multiplier = POINT_TWO;
      assetSupply = levSupply;
      collateralLevel = (tvl * PRECISION) / (debtSupply * BOND_TARGET_PRICE);

      if (assetSupply == 0) {
        revert ZeroLeverageSupply();
      }
    }
    
    uint256 redeemRate = BOND_TARGET_PRICE * PRECISION;

    if (collateralLevel <= COLLATERAL_THRESHOLD) {
      redeemRate = ((tvl * multiplier) / assetSupply);
    } else if (tokenType == TokenType.LEVERAGE) {
      // @todo: is this BOND_TARGET_PRICE?
      redeemRate = ((tvl - (debtSupply * 100)) / assetSupply) * PRECISION;
    }
    
    return ((depositAmount * redeemRate) / ethPrice) / PRECISION;
  }

  function swap(TokenType tokenType, uint256 depositAmount, uint256 minAmount) external whenNotPaused() returns(uint256) {
    uint256 mintAmount = simulateSwap(tokenType, depositAmount);

    if (mintAmount < minAmount) {
      revert MinAmount();
    }

    if (tokenType == TokenType.DEBT) {
      dToken.burn(msg.sender, depositAmount);
      lToken.mint(msg.sender, mintAmount);
    } else {
      lToken.burn(msg.sender, depositAmount);
      dToken.mint(msg.sender, mintAmount);
    }
    
    return mintAmount;
  }

  function simulateSwap(TokenType tokenType, uint256 depositAmount) public view whenNotPaused() returns(uint256) {
    uint256 debtSupply = dToken.totalSupply();
    uint256 levSupply = lToken.totalSupply();
    uint256 poolReserves = ERC20(reserveToken).totalSupply();
    TokenType createType = TokenType.DEBT;

    uint256 redeemAmount = getRedeemAmount(
      tokenType,
      depositAmount,
      debtSupply,
      levSupply,
      poolReserves,
      ETH_PRICE
    );
    
    poolReserves = poolReserves - redeemAmount;
    if (tokenType == TokenType.DEBT) {
      createType = TokenType.LEVERAGE;
      debtSupply = debtSupply - depositAmount; 
    } else {
      levSupply = levSupply - depositAmount; 
    }

    return getCreateAmount(
      createType,
      redeemAmount,
      debtSupply,
      levSupply,
      poolReserves,
      ETH_PRICE
    );
  }

  function setFee(uint256 _fee) external whenNotPaused() onlyRole(poolFactory.GOV_ROLE()) {
    fee = _fee;
  }

  /**
   * @dev Pauses contract. Reverts any interaction expect upgrade.
   */
  function pause() external onlyRole(poolFactory.GOV_ROLE()) {
    _pause();
  }

  /**
   * @dev Unpauses contract.
   */
  function unpause() external onlyRole(poolFactory.GOV_ROLE()) {
    _unpause();
  }

  modifier onlyRole(bytes32 role) {
    if (!poolFactory.hasRole(role, msg.sender)) {
      revert AccessDenied();
    }
    _;
  }

  // @todo: owner will be PoolFactory, make sure we can upgrade
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
