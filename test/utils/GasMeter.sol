// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GasMeter {
  uint256 private meter;
  error MeterAlreadyStarted();

  function gasMeterStart() internal {
    if (meter != 0) {
      revert MeterAlreadyStarted();
    }
    
    // -100 ~accounts for this call itself
    meter = gasleft() - 100;
  }

  function gasMeterStop() internal returns (uint256 usage) {
    usage = meter - gasleft();
    meter = 0;
    return usage;
  }
}
