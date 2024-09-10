// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "../../src/Pool.sol";

contract MockPool is Pool {
  uint256 time;

  function _blockTimestamp() internal view override returns (uint256) {
      return time;
  }

  function setTime(uint256 _time) external {
      time = _time;
  }
}
