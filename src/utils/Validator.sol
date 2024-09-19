// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import './BlockTimestamp.sol';

/**
 * @title Validator
 * @dev Abstract contract that provides a modifier to check transaction deadlines.
 */
abstract contract Validator is BlockTimestamp {
    /**
     * @dev Custom error to be thrown when a transaction is submitted after its deadline.
     */
    error TransactionTooOld();

    /**
     * @dev Modifier to check if the current block timestamp is before or equal to the given deadline.
     * @param deadline The timestamp by which the transaction must be executed.
     * @notice This modifier will revert the transaction if the current block timestamp is after the deadline.
     */
    modifier checkDeadline(uint256 deadline) {
        if (_blockTimestamp() > deadline) revert TransactionTooOld();
        _;
    }
}
