// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {OracleFeeds} from "./OracleFeeds.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleReader
 * @dev Contract for reading price data from Chainlink oracles
 */
contract OracleReader {

  address public oracleFeeds;
  uint256[49] private __gap;

  // @note: address(0) is a special address that represents USD (IRL asset)
  address public constant USD = address(0);
  // @note: special address that represents ETH (Chainlink asset)
  address public constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  /**
   * @dev Error thrown when no valid price is found
   */
  error NoPriceFound();

  /**
   * @dev Error thrown when no valid feed is found
   */ 
  error NoFeedFound();

  /**
   * @dev Error thrown when the price is stale
   */
  error StalePrice();

  /**
   * @dev Error thrown when oracle feeds are aready initialized
   */
  error AlreadyInitialized();

  /**
   * @dev Initializes the contract with the OracleFeeds address
   * @param _oracleFeeds Address of the OracleFeeds contract
   */
  function __OracleReader_init(address _oracleFeeds) internal {
    require(oracleFeeds == address(0), AlreadyInitialized());
    oracleFeeds = _oracleFeeds;
  }

  /**
   * @dev Retrieves the latest price from the oracle
   * @return price from the oracle
   * @dev Reverts if the price data is older than chainlink's heartbeat
   */
  function getOraclePrice(address quote, address base) public view returns(uint256) {
    bool isInverted = false;
    address feed = OracleFeeds(oracleFeeds).priceFeeds(quote, base);
    
    if (feed == address(0)) {
      feed = OracleFeeds(oracleFeeds).priceFeeds(base, quote);
      if (feed == address(0)) {
        revert NoFeedFound();
      }

      // Invert the price
      isInverted = true;
    }
    (,int256 answer,,uint256 updatedTimestamp,) = AggregatorV3Interface(feed).latestRoundData();
    
    if (updatedTimestamp + OracleFeeds(oracleFeeds).feedHeartbeats(feed) < block.timestamp) {
      revert StalePrice();
    }

    uint256 decimals = uint256(AggregatorV3Interface(feed).decimals());
    return isInverted ? (10 ** decimals * 10 ** decimals) / uint256(answer) : uint256(answer);
  }

  /**
   * @dev Retrieves the number of decimals used in the oracle's price data
   * @return decimals Number of decimals used in the price data
   */
  function getOracleDecimals(address quote, address base) public view returns(uint8 decimals) {
    address feed = OracleFeeds(oracleFeeds).priceFeeds(quote, base);

    if (feed == address(0)) {
      feed = OracleFeeds(oracleFeeds).priceFeeds(base, quote);
      if (feed == address(0)) {
        revert NoFeedFound();
      }
    }

    return AggregatorV3Interface(feed).decimals();
  }
}
