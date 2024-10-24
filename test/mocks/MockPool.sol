// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "../../src/Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockPool is Pool {
  uint256 time;

  function _blockTimestamp() internal view override returns (uint256) {
      return time;
  }

  function setTime(uint256 _time) external {
      time = _time;
  }

  function transferReserveToAuction(uint256 amount) external override {
    IERC20(reserveToken).transfer(msg.sender, amount);
  }
}
