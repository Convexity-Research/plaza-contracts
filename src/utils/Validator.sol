// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import './BlockTimestamp.sol';

abstract contract Validator is BlockTimestamp {
  error TransactionTooOld();
  modifier checkDeadline(uint256 deadline) {
    require(_blockTimestamp() <= deadline, TransactionTooOld());
    _;
  }
}
