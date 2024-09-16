// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

/**
 * @title BlockTimestamp
 * @dev Abstract contract providing a function to get the current block timestamp.
 */
abstract contract BlockTimestamp {
    /**
     * @notice Returns the current block timestamp
     * @return uint256 The current block timestamp
     */
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
