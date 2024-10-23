// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library Decimals {
  /**
   * @dev Converts a token amount to its base unit representation.
   * @param amount The token amount.
   * @param decimals The number of decimals the token uses.
   * @return The base unit representation of the token amount.
   */
  function toBaseUnit(uint256 amount, uint8 decimals) internal pure returns (uint256) {
    return amount / (10 ** decimals);
  }

  /**
   * @dev Converts a base unit representation to a token amount.
   * @param baseUnitAmount The base unit representation of the token amount.
   * @param decimals The number of decimals the token uses.
   * @return The token amount.
   */
  function fromBaseUnit(uint256 baseUnitAmount, uint8 decimals) internal pure returns (uint256) {
    return baseUnitAmount * (10 ** decimals);
  }

  /**
   * @dev Normalizes a token amount to a common decimal base.
   * @param amount The token amount.
   * @param fromDecimals The number of decimals the token uses.
   * @param toDecimals The target number of decimals.
   * @return The normalized token amount.
   */
  function normalizeAmount(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
    if (fromDecimals > toDecimals) {
      return amount / (10 ** (fromDecimals - toDecimals));
    } else if (fromDecimals < toDecimals) {
      return amount * (10 ** (toDecimals - fromDecimals));
    } else {
      return amount;
    }
  }

  /**
   * @dev Normalizes a token amount to a specified decimal base.
   * @param token The ERC20 token.
   * @param amount The token amount to normalize.
   * @param toDecimals The target number of decimals.
   * @return The normalized token amount.
   */
  function normalizeTokenAmount(uint256 amount, address token, uint8 toDecimals) internal view returns (uint256) {
    uint8 decimals = IERC20Metadata(token).decimals();
    return normalizeAmount(amount, decimals, toDecimals);
  }

  /**
   * @dev Adds two token amounts with different decimals.
   * @param amount1 The first token amount.
   * @param decimals1 The number of decimals for the first token.
   * @param amount2 The second token amount.
   * @param decimals2 The number of decimals for the second token.
   * @param resultDecimals The number of decimals for the result.
   * @return The sum of the two token amounts normalized to the result decimals.
   */
  function addAmounts(uint256 amount1, uint8 decimals1, uint256 amount2, uint8 decimals2, uint8 resultDecimals) internal pure returns (uint256) {
    uint256 normalizedAmount1 = normalizeAmount(amount1, decimals1, resultDecimals);
    uint256 normalizedAmount2 = normalizeAmount(amount2, decimals2, resultDecimals);
    return normalizedAmount1 + normalizedAmount2;
  }

  /**
   * @dev Subtracts two token amounts with different decimals.
   * @param amount1 The first token amount.
   * @param decimals1 The number of decimals for the first token.
   * @param amount2 The second token amount.
   * @param decimals2 The number of decimals for the second token.
   * @param resultDecimals The number of decimals for the result.
   * @return The difference of the two token amounts normalized to the result decimals.
   */
  function subtractAmounts(uint256 amount1, uint8 decimals1, uint256 amount2, uint8 decimals2, uint8 resultDecimals) internal pure returns (uint256) {
    uint256 normalizedAmount1 = normalizeAmount(amount1, decimals1, resultDecimals);
    uint256 normalizedAmount2 = normalizeAmount(amount2, decimals2, resultDecimals);
    return normalizedAmount1 - normalizedAmount2;
  }
}
