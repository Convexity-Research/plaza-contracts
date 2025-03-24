// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {PreDeposit} from "./PreDeposit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IAsset} from "@balancer/contracts/interfaces/contracts/vault/IAsset.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {WeightedPoolUserData} from "@balancer/contracts/interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

contract BalancerRouter is ReentrancyGuard {
  using SafeERC20 for IERC20;

  IVault public immutable balancerVault;

  event TokensRedeemed(
    address indexed plazaPool,
    address caller,
    address indexed onBehalfOf,
    Pool.TokenType tokenType,
    uint256 depositedAmount,
    uint256 redeemedAmount
  );

  constructor(address _balancerVault) {
    balancerVault = IVault(_balancerVault);
  }

  function joinBalancerAndPlaza(
    bytes32 balancerPoolId,
    address _plazaPool,
    IAsset[] memory assets,
    uint256[] memory maxAmountsIn,
    bytes memory userData,
    Pool.TokenType plazaTokenType,
    uint256 minPlazaTokens,
    uint256 deadline
  ) external nonReentrant returns (uint256) {
    // Step 1: Join Balancer Pool
    uint256 balancerPoolTokenReceived = joinBalancerPool(balancerPoolId, assets, maxAmountsIn, userData);

    // Step 2: Approve balancerPoolToken for Plaza Pool
    (address balancerPoolToken,) = balancerVault.getPool(balancerPoolId);
    IERC20(balancerPoolToken).safeIncreaseAllowance(_plazaPool, balancerPoolTokenReceived);

    // Step 3: Join Plaza Pool
    uint256 plazaTokens =
      Pool(_plazaPool).create(plazaTokenType, balancerPoolTokenReceived, minPlazaTokens, deadline, msg.sender);

    return plazaTokens;
  }

  function joinBalancerPool(
    bytes32 poolId,
    IAsset[] memory assets,
    uint256[] memory maxAmountsIn,
    bytes memory userData
  ) internal returns (uint256) {
    // Transfer assets from user to this contract
    for (uint256 i = 0; i < assets.length; i++) {
      IERC20(address(assets[i])).safeTransferFrom(msg.sender, address(this), maxAmountsIn[i]);
      IERC20(address(assets[i])).safeIncreaseAllowance(address(balancerVault), maxAmountsIn[i]);
    }

    IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
      assets: assets,
      maxAmountsIn: maxAmountsIn,
      userData: userData,
      fromInternalBalance: false
    });

    // Join Balancer pool
    (address balancerPoolToken,) = balancerVault.getPool(poolId);
    uint256 balancerPoolTokenBalanceBefore = IERC20(balancerPoolToken).balanceOf(address(this));
    balancerVault.joinPool(poolId, address(this), address(this), request);

    // Send back any remaining assets to user
    for (uint256 i = 1; i < assets.length; i++) {
      // index 0 is the balancer pool token in ManagedPools
      uint256 assetBalance = IERC20(address(assets[i])).balanceOf(address(this));
      if (assetBalance > 0) IERC20(address(assets[i])).safeTransfer(msg.sender, assetBalance);
    }

    uint256 balancerPoolTokenBalanceAfter = IERC20(balancerPoolToken).balanceOf(address(this));

    return balancerPoolTokenBalanceAfter - balancerPoolTokenBalanceBefore;
  }

  function exitPlazaAndBalancer(
    bytes32 balancerPoolId,
    address _plazaPool,
    IAsset[] memory assets,
    uint256 plazaTokenAmount,
    uint256[] memory minAmountsOut,
    bytes calldata userData,
    Pool.TokenType plazaTokenType,
    uint256 minbalancerPoolTokenOut
  ) external nonReentrant {
    // Step 1: Exit Plaza Pool
    uint256 balancerPoolTokenReceived =
      exitPlazaPool(plazaTokenType, _plazaPool, plazaTokenAmount, minbalancerPoolTokenOut);

    // Decode userData to get format and bptAmountIn
    (uint256 exitKind) = abi.decode(userData[:32], (uint256));

    bytes memory newUserData;
    if (exitKind == 0) {
      // EXACT_BPT_IN_FOR_ONE_TOKEN_OUT
      uint256 exitTokenIndex;
      (,, exitTokenIndex) = abi.decode(userData, (uint256, uint256, uint256));
      newUserData = abi.encode(uint256(0), balancerPoolTokenReceived, exitTokenIndex);
    } else if (exitKind == 1) {
      // EXACT_BPT_IN_FOR_TOKENS_OUT
      newUserData = abi.encode(uint256(1), balancerPoolTokenReceived);
    }

    // Step 2: Exit Balancer Pool
    exitBalancerPool(balancerPoolId, assets, minAmountsOut, newUserData, msg.sender);
  }

  function exitPlazaPool(
    Pool.TokenType tokenType,
    address _plazaPool,
    uint256 tokenAmount,
    uint256 minbalancerPoolTokenOut
  ) internal returns (uint256) {
    // Transfer Plaza tokens from user to this contract
    Pool plazaPool = Pool(_plazaPool);
    IERC20 plazaToken =
      tokenType == Pool.TokenType.BOND ? IERC20(address(plazaPool.bondToken())) : IERC20(address(plazaPool.lToken()));
    plazaToken.safeTransferFrom(msg.sender, address(this), tokenAmount);
    plazaToken.safeIncreaseAllowance(_plazaPool, tokenAmount);

    // Exit Plaza pool
    uint256 reservesRedeemedAmount = plazaPool.redeem(tokenType, tokenAmount, minbalancerPoolTokenOut);

    emit TokensRedeemed(_plazaPool, address(this), msg.sender, tokenType, tokenAmount, reservesRedeemedAmount);

    return reservesRedeemedAmount;
  }

  function exitBalancerPool(
    bytes32 poolId,
    IAsset[] memory assets,
    uint256[] memory minAmountsOut,
    bytes memory userData,
    address to
  ) internal {
    IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
      assets: assets,
      minAmountsOut: minAmountsOut,
      userData: userData,
      toInternalBalance: false
    });

    balancerVault.exitPool(poolId, address(this), payable(to), request);
  }
}
