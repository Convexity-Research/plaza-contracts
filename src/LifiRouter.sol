// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LifiRouter {
  using SafeERC20 for IERC20;

  function create(
    address _pool,
    Pool.TokenType tokenType,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf) external {
    address reserveToken = Pool(_pool).reserveToken();
    Pool(_pool).create(tokenType, IERC20(reserveToken).allowance(msg.sender, address(this)), minAmount, deadline, onBehalfOf);
  }
}
