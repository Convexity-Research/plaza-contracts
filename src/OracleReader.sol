// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleReader
 * @dev Contract for reading price data from Chainlink oracles
 */
contract OracleReader {

  // Address of the ETH price feed oracle
  address private ethPriceFeed;

  /**
   * @dev Error thrown when no valid price is found
   */
  error NoPriceFound();

  /**
   * @dev Initializes the contract with the ETH price feed address
   * @param _ethPriceFeed Address of the ETH price feed oracle
   */
  function __OracleReader_init(address _ethPriceFeed) internal {
    require(ethPriceFeed == address(0), "Already initialized");
    ethPriceFeed = _ethPriceFeed;
  }

  /**
   * @dev Retrieves the latest price from the oracle
   * @return price from the oracle
   * @dev Reverts if the price data is older than 1 day
   */
  function getOraclePrice(address /*quote*/) public view returns(uint256) {
    (,int256 answer,,uint256 updatedTimestamp,) = AggregatorV3Interface(ethPriceFeed).latestRoundData();

    if (updatedTimestamp + 1 days <= block.timestamp) {
      revert NoPriceFound();
    }

    return uint256(answer);
  }

  /**
   * @dev Retrieves the number of decimals used in the oracle's price data
   * @return decimals Number of decimals used in the price data
   */
  function getOracleDecimals(address /*quote*/) public view returns(uint8 decimals) {
    return AggregatorV3Interface(ethPriceFeed).decimals();
  }
}
