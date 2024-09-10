// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BondToken} from "./BondToken.sol";
import {Decimals} from "./lib/Decimals.sol";
import {Distributor} from "./Distributor.sol";
import {PoolFactory} from "./PoolFactory.sol";
import {Validator} from "./utils/Validator.sol";
import {OracleReader} from "./OracleReader.sol";
import {LeverageToken} from "./LeverageToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract Pool is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable, OracleReader, Validator {
  using Decimals for uint256;
  
  // uint public constant MINIMUM_LIQUIDITY = 10**3;
  uint256 private constant POINT_EIGHT = 800000; // 1000000 precision | 800000=0.8
  uint256 private constant POINT_TWO = 200000;
  uint256 private constant COLLATERAL_THRESHOLD = 1200000;
  uint256 private constant PRECISION = 1000000;
  uint256 private constant BOND_TARGET_PRICE = 100;
  uint8 private constant COMMON_DECIMALS = 18;

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

  struct PoolInfo {
    uint256 reserve;
    uint256 debtSupply;
    uint256 levSupply;
  }

  error MinAmount();
  error ZeroAmount();
  error AccessDenied();
  error ZeroDebtSupply();
  error ZeroLeverageSupply();
  error DistributionPeriod();

  event TokensCreated(address caller, address onBehalfOf, TokenType tokenType, uint256 depositedAmount, uint256 mintedAmount);
  event TokensRedeemed(address caller, address onBehalfOf, TokenType tokenType, uint256 depositedAmount, uint256 redeemedAmount);
  event TokensSwapped(address caller, address onBehalfOf, TokenType tokenType, uint256 depositedAmount, uint256 redeemedAmount);
  event Distributed(uint256 amount);
  
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
    uint256 _distributionPeriod
  ) initializer public {
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
  
  function create(TokenType tokenType, uint256 depositAmount, uint256 minAmount) external whenNotPaused() returns(uint256) {
    return create(tokenType, depositAmount, minAmount, block.timestamp, address(0));
  }

  function create(
    TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf) public whenNotPaused() checkDeadline(deadline) returns(uint256) {
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

    address recipient = onBehalfOf == address(0) ? msg.sender : onBehalfOf;

    // Mint tokens
    if (tokenType == TokenType.DEBT) {
      dToken.mint(recipient, amount);
    } else {
      lToken.mint(recipient, amount);
    }

    emit TokensCreated(msg.sender, recipient, tokenType, depositAmount, amount);
    return amount;
  }

  function simulateCreate(TokenType tokenType, uint256 depositAmount) public view returns(uint256) {

    uint256 debtSupply = dToken.totalSupply()
                          .normalizeTokenAmount(address(dToken), COMMON_DECIMALS);
    uint256 levSupply = lToken.totalSupply()
                          .normalizeTokenAmount(address(lToken), COMMON_DECIMALS);
    uint256 poolReserves = ERC20(reserveToken).balanceOf(address(this))
                          .normalizeTokenAmount(reserveToken, COMMON_DECIMALS);
    depositAmount = depositAmount.normalizeTokenAmount(reserveToken, COMMON_DECIMALS);

    uint8 assetDecimals = 0;
    if (tokenType == TokenType.LEVERAGE) {
      assetDecimals = lToken.decimals();
    } else {
      assetDecimals = dToken.decimals();
    }

    return getCreateAmount(
      tokenType,
      depositAmount,
      debtSupply,
      levSupply,
      poolReserves,
      getOraclePrice(address(0)),
      getOracleDecimals(address(0))
    ).normalizeAmount(COMMON_DECIMALS, assetDecimals);
  }

  function getCreateAmount(
    TokenType tokenType,
    uint256 depositAmount,
    uint256 debtSupply, 
    uint256 levSupply, 
    uint256 poolReserves, 
    uint256 ethPrice,
    uint8 oracleDecimals) public pure returns(uint256) {
    if (debtSupply == 0) {
      revert ZeroDebtSupply();
    }

    uint256 assetSupply = debtSupply;
    uint256 multiplier = POINT_EIGHT;
    if (tokenType == TokenType.LEVERAGE) {
      multiplier = POINT_TWO;
      assetSupply = levSupply;
    }

    uint256 tvl = (ethPrice * poolReserves).toBaseUnit(oracleDecimals);
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
    
    return ((depositAmount * ethPrice * PRECISION) / creationRate).toBaseUnit(oracleDecimals);
  }

  function redeem(TokenType tokenType, uint256 depositAmount, uint256 minAmount) public whenNotPaused() returns(uint256) {
    return redeem(tokenType, depositAmount, minAmount, block.timestamp, address(0));
  }

  function redeem(
    TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf) public whenNotPaused() checkDeadline(deadline) returns(uint256) {
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

    address recipient = onBehalfOf == address(0) ? msg.sender : onBehalfOf;

    // @todo: replace with safeTransfer
    if (!ERC20(reserveToken).transfer(recipient, reserveAmount)) {
      revert("not enough funds");
    }

    emit TokensRedeemed(msg.sender, recipient, tokenType, depositAmount, reserveAmount);
    return reserveAmount;
  }

  function simulateRedeem(TokenType tokenType, uint256 depositAmount) public view whenNotPaused() returns(uint256) {

    uint256 debtSupply = dToken.totalSupply()
                          .normalizeTokenAmount(address(dToken), COMMON_DECIMALS);
    uint256 levSupply = lToken.totalSupply()
                          .normalizeTokenAmount(address(lToken), COMMON_DECIMALS);
    uint256 poolReserves = ERC20(reserveToken).balanceOf(address(this))
                          .normalizeTokenAmount(reserveToken, COMMON_DECIMALS);

    if (tokenType == TokenType.LEVERAGE) {
      depositAmount = depositAmount.normalizeTokenAmount(address(lToken), COMMON_DECIMALS);
    } else {
      depositAmount = depositAmount.normalizeTokenAmount(address(dToken), COMMON_DECIMALS);
    }

    return getRedeemAmount(
      tokenType,
      depositAmount,
      debtSupply,
      levSupply,
      poolReserves,
      getOraclePrice(address(0)),
      getOracleDecimals(address(0))
    ).normalizeAmount(COMMON_DECIMALS, ERC20(reserveToken).decimals());
  }

  function getRedeemAmount(
    TokenType tokenType,
    uint256 depositAmount,
    uint256 debtSupply,
    uint256 levSupply,
    uint256 poolReserves,
    uint256 ethPrice,
    uint8 oracleDecimals) public pure returns(uint256) {
    if (debtSupply == 0) {
      revert ZeroDebtSupply();
    }

    uint256 tvl = (ethPrice * poolReserves).toBaseUnit(oracleDecimals);
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
    
    return ((depositAmount * redeemRate).fromBaseUnit(oracleDecimals) / ethPrice) / PRECISION;
  }

  function swap(TokenType tokenType, uint256 depositAmount, uint256 minAmount) public whenNotPaused() returns(uint256) {
    return swap(tokenType, depositAmount, minAmount, block.timestamp, address(0));
  }

  function swap(
    TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf) public whenNotPaused() checkDeadline(deadline) returns(uint256) {
    uint256 mintAmount = simulateSwap(tokenType, depositAmount);

    if (mintAmount < minAmount) {
      revert MinAmount();
    }

    address recipient = onBehalfOf == address(0) ? msg.sender : onBehalfOf;

    if (tokenType == TokenType.DEBT) {
      dToken.burn(msg.sender, depositAmount);
      lToken.mint(recipient, mintAmount);
    } else {
      lToken.burn(msg.sender, depositAmount);
      dToken.mint(recipient, mintAmount);
    }

    emit TokensSwapped(msg.sender, recipient, tokenType, depositAmount, mintAmount);
    return mintAmount;
  }

  function simulateSwap(TokenType tokenType, uint256 depositAmount) public view whenNotPaused() returns(uint256) {
    uint256 debtSupply = dToken.totalSupply()
                          .normalizeTokenAmount(address(dToken), COMMON_DECIMALS);
    uint256 levSupply = lToken.totalSupply()
                          .normalizeTokenAmount(address(lToken), COMMON_DECIMALS);
    uint256 poolReserves = ERC20(reserveToken).balanceOf(address(this))
                          .normalizeTokenAmount(reserveToken, COMMON_DECIMALS);

    if (tokenType == TokenType.LEVERAGE) {
      depositAmount = depositAmount.normalizeTokenAmount(address(lToken), COMMON_DECIMALS);
    } else {
      depositAmount = depositAmount.normalizeTokenAmount(address(dToken), COMMON_DECIMALS);
    }

    uint256 redeemAmount = getRedeemAmount(
      tokenType,
      depositAmount,
      debtSupply,
      levSupply,
      poolReserves,
      getOraclePrice(address(0)),
      getOracleDecimals(address(0))
    );
    
    uint8 assetDecimals = 0;
    TokenType createType = TokenType.DEBT;
    poolReserves = poolReserves - redeemAmount;

    if (tokenType == TokenType.DEBT) {
      createType = TokenType.LEVERAGE;
      debtSupply = debtSupply - depositAmount; 
      assetDecimals = lToken.decimals();
    } else {
      levSupply = levSupply - depositAmount; 
      assetDecimals = dToken.decimals();
    }

    return getCreateAmount(
      createType,
      redeemAmount,
      debtSupply,
      levSupply,
      poolReserves,
      getOraclePrice(address(0)),
      getOracleDecimals(address(0))
    ).normalizeAmount(COMMON_DECIMALS, assetDecimals);
  }

  function distribute() external whenNotPaused() {
    if (block.timestamp - lastDistributionTime < distributionPeriod) {
      revert DistributionPeriod();
    }

    Distributor distributor = Distributor(poolFactory.distributor());

    //calculate last distribution time
    lastDistributionTime = block.timestamp + distributionPeriod;

    // calculate the coupon to distribute. all issued bond tokens times the sharesPerToken (this will need to be adjusted when we go cross-chain)
    uint256 couponAmountToDistribute = (dToken.totalSupply() * sharesPerToken).toBaseUnit(dToken.SHARES_DECIMALS());

    // increase the bond token period
    dToken.increaseIndexedAssetPeriod(sharesPerToken);

    // send the coupon token to the distributor, here we assume that the merchant has already sent the total amount of coupon token to this contract
    // @todo: replace with safeTransfer
    ERC20(couponToken).transfer(address(distributor), couponAmountToDistribute);

    // @todo: update distributor with the amount to distribute
    distributor.allocate(address(this), couponAmountToDistribute);

    emit Distributed(couponAmountToDistribute);
  }

  function getPoolInfo() external view returns (PoolInfo memory info) {
    info = PoolInfo({
      reserve: ERC20(reserveToken).balanceOf(address(this)),
      debtSupply: dToken.totalSupply(),
      levSupply: lToken.totalSupply()
    });
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
