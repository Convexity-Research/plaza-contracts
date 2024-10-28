// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IAsset} from "@balancer/contracts/interfaces/contracts/vault/IAsset.sol";
import {Pool} from "./Pool.sol";
import {PreDeposit} from "./PreDeposit.sol";

contract BalancerRouter is ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    IVault public immutable balancerVault;
    Pool public immutable plazaPool;
    PreDeposit public immutable predeposit;
    IERC20 public immutable bpt;

    constructor(address _balancerVault, address _plazaPool, address _predeposit, address _bpt) {
        balancerVault = IVault(_balancerVault);
        plazaPool = Pool(_plazaPool);
        predeposit = PreDeposit(_predeposit);
        bpt = IERC20(_bpt);
    }

    function joinBalancerAndPredeposit(
        bytes32 balancerPoolId,
        IAsset[] memory assets,
        uint256[] memory maxAmountsIn,
        bytes memory userData,
        uint256 amount
    ) external nonReentrant returns (uint256) {
        // Step 1: Join Balancer Pool
        uint256 bptReceived = joinBalancerPool(balancerPoolId, assets, maxAmountsIn, userData);

        // Step 2: Approve BPT for PreDeposit
        bpt.safeIncreaseAllowance(address(predeposit), bptReceived);

        // Step 3: Deposit to PreDeposit
        predeposit.deposit(bptReceived, msg.sender);

        return bptReceived;
    }

    function joinBalancerAndPlaza(
        bytes32 balancerPoolId,
        IAsset[] memory assets,
        uint256[] memory maxAmountsIn,
        bytes memory userData,
        Pool.TokenType plazaTokenType,
        uint256 minPlazaTokens,
        uint256 deadline
    ) external nonReentrant returns (uint256) {
        // Step 1: Join Balancer Pool
        uint256 bptReceived = joinBalancerPool(balancerPoolId, assets, maxAmountsIn, userData);

        // Step 2: Approve BPT for Plaza Pool
        bpt.safeIncreaseAllowance(address(plazaPool), bptReceived);

        // Step 3: Join Plaza Pool
        uint256 plazaTokens = plazaPool.create(plazaTokenType, bptReceived, minPlazaTokens, deadline, msg.sender);

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
            if (address(assets[i]) != address(0)) { // Skip ETH
                IERC20(address(assets[i])).safeTransferFrom(msg.sender, address(this), maxAmountsIn[i]);
                IERC20(address(assets[i])).safeIncreaseAllowance(address(balancerVault), maxAmountsIn[i]);
            }
        }

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: maxAmountsIn,
            userData: userData,
            fromInternalBalance: false
        });

        // Join Balancer pool
        uint256 bptBalanceBefore = bpt.balanceOf(address(this));
        balancerVault.joinPool(poolId, address(this), address(this), request);
        uint256 bptBalanceAfter = bpt.balanceOf(address(this));

        return bptBalanceAfter - bptBalanceBefore;
    }

    function exitBalancerAndPredeposit(
        bytes32 balancerPoolId,
        IAsset[] memory assets,
        uint256 bptIn,
        uint256 minAmountOut,
        bytes memory userData
    ) external nonReentrant {
        // Step 1: Withdraw from PreDeposit
        predeposit.withdraw(bptIn, msg.sender);

        // Step 2: Exit Balancer Pool
        exitBalancerPool(balancerPoolId, assets, bptIn, minAmountOut, userData, msg.sender);
    }

    function exitPlazaAndBalancer(
        bytes32 balancerPoolId,
        IAsset[] memory assets,
        uint256 plazaTokenAmount,
        uint256[] memory minAmountsOut,
        bytes memory userData,
        Pool.TokenType plazaTokenType,
        uint256 minBptOut,
        uint256 deadline
    ) external nonReentrant {
        // Step 1: Exit Plaza Pool
        uint256 bptReceived = exitPlazaPool(plazaTokenType, plazaTokenAmount, minBptOut, deadline);

        // Step 2: Exit Balancer Pool
        exitBalancerPool(balancerPoolId, assets, bptReceived, minAmountsOut, userData, msg.sender);
    }
    
    function exitPlazaPool(
        Pool.TokenType tokenType,
        uint256 tokenAmount,
        uint256 minBptOut,
        uint256 deadline
    ) internal returns (uint256) {
        // Transfer Plaza tokens from user to this contract
        IERC20 plazaToken = tokenType == Pool.TokenType.BOND ? IERC20(address(plazaPool.bondToken())) : IERC20(address(plazaPool.lToken()));
        plazaToken.safeTransferFrom(msg.sender, address(this), tokenAmount);
        plazaToken.safeIncreaseAllowance(address(plazaPool), tokenAmount);

        // Exit Plaza pool
        return plazaPool.redeem(tokenType, tokenAmount, minBptOut, deadline);
    }

    function exitBalancerPool(
        bytes32 poolId,
        IAsset[] memory assets,
        uint256 bptIn,
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

        bpt.safeIncreaseAllowance(address(balancerVault), bptIn);
        balancerVault.exitPool(poolId, address(this), payable(to), request);
    }
}