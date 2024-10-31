// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolFactory} from "../../src/PoolFactory.sol";

contract MockPoolFactory {
  function createPool(
    PoolFactory.PoolParams calldata /*params*/,
    uint256 /*reserveAmount*/,
    uint256 /*bondAmount*/, 
    uint256 /*leverageAmount*/,
    string memory /*bondName*/,
    string memory /*bondSymbol*/,
    string memory /*leverageName*/,
    string memory /*leverageSymbol*/
  ) external pure returns (address) {
    return address(0x1234567890123456789012345678901234567890);
  }
}
