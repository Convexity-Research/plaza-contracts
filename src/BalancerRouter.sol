// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {PreDeposit} from "./PreDeposit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IAsset} from "@balancer/contracts/interfaces/contracts/vault/IAsset.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BalancerRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IVault public immutable balancerVault;
    IERC20 public immutable balancerPoolToken;

    constructor(address _balancerVault, address _balancerPoolToken) {
        balancerVault = IVault(_balancerVault);
        balancerPoolToken = IERC20(_balancerPoolToken);
    }

    function joinBalancerAndPredeposit(
        bytes32 balancerPoolId,
        address _predeposit,
        IAsset[] memory assets,
        uint256[] memory maxAmountsIn,
        bytes memory userData
    ) external nonReentrant returns (uint256) {
        // Step 1: Join Balancer Pool
        uint256 balancerPoolTokenReceived = joinBalancerPool(balancerPoolId, assets, maxAmountsIn, userData);

        // Step 2: Approve balancerPoolToken for PreDeposit
        balancerPoolToken.safeIncreaseAllowance(_predeposit, balancerPoolTokenReceived);

        // Step 3: Deposit to PreDeposit
        PreDeposit(_predeposit).deposit(balancerPoolTokenReceived, msg.sender);

        return balancerPoolTokenReceived;
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
        balancerPoolToken.safeIncreaseAllowance(_plazaPool, balancerPoolTokenReceived);

        // Step 3: Join Plaza Pool
        uint256 plazaTokens = Pool(_plazaPool).create(plazaTokenType, balancerPoolTokenReceived, minPlazaTokens, deadline, msg.sender);

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
        uint256 balancerPoolTokenBalanceBefore = balancerPoolToken.balanceOf(address(this));
        balancerVault.joinPool(poolId, address(this), address(this), request);
        uint256 balancerPoolTokenBalanceAfter = balancerPoolToken.balanceOf(address(this));

        return balancerPoolTokenBalanceAfter - balancerPoolTokenBalanceBefore;
    }

    function exitPlazaAndBalancer(
        bytes32 balancerPoolId,
        address _plazaPool,
        IAsset[] memory assets,
        uint256 plazaTokenAmount,
        uint256[] memory minAmountsOut,
        bytes memory userData,
        Pool.TokenType plazaTokenType,
        uint256 minbalancerPoolTokenOut
    ) external nonReentrant {
        // Step 1: Exit Plaza Pool
        uint256 balancerPoolTokenReceived = exitPlazaPool(plazaTokenType, _plazaPool, plazaTokenAmount, minbalancerPoolTokenOut);

        // Step 2: Exit Balancer Pool
        exitBalancerPool(balancerPoolId, assets, balancerPoolTokenReceived, minAmountsOut, userData, msg.sender);
    }
    
    function exitPlazaPool(
        Pool.TokenType tokenType,
        address _plazaPool,
        uint256 tokenAmount,
        uint256 minbalancerPoolTokenOut
    ) internal returns (uint256) {
        // Transfer Plaza tokens from user to this contract
        Pool plazaPool = Pool(_plazaPool);
        IERC20 plazaToken = tokenType == Pool.TokenType.BOND ? IERC20(address(plazaPool.bondToken())) : IERC20(address(plazaPool.lToken()));
        plazaToken.safeTransferFrom(msg.sender, address(this), tokenAmount);
        plazaToken.safeIncreaseAllowance(_plazaPool, tokenAmount);

        // Exit Plaza pool
        return plazaPool.redeem(tokenType, tokenAmount, minbalancerPoolTokenOut);
    }

    function exitBalancerPool(
        bytes32 poolId,
        IAsset[] memory assets,
        uint256 balancerPoolTokenIn,
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

        balancerPoolToken.safeIncreaseAllowance(address(balancerVault), balancerPoolTokenIn);
        balancerVault.exitPool(poolId, address(this), payable(to), request);
    }
}