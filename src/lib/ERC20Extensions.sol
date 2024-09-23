// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface that includes the decimals method
interface IERC20WithDecimals is IERC20 {
  function decimals() external view returns (uint8);
}

// Library to extend the functionality of IERC20
library ERC20Extensions {
  function safeDecimals(IERC20 token) internal view returns (uint8) {
    // Try casting the token to the extended interface with decimals()
    try IERC20WithDecimals(address(token)).decimals() returns (uint8 tokenDecimals) {
      return tokenDecimals;
    } catch {
      // Return a default value if decimals() is not implemented
      return 18;
    }
  }
}
