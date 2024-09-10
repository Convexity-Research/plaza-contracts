// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract OracleReader {

  // arbitrum sepolia
  // address private constant ETH_PRICE_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;

  // arbitrum mainnet
  // address private constant ETH_PRICE_FEED = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

  // base mainnet
  address private ethPriceFeed;

  function __OracleReader_init(address _ethPriceFeed) internal {
    require(ethPriceFeed == address(0), "Already initialized");
    ethPriceFeed = _ethPriceFeed;
  }

  error NoPriceFound();

  function getOraclePrice(address /*quote*/) public view returns(uint256) {
    (,int256 answer,,uint256 updatedTimestamp,) = AggregatorV3Interface(ethPriceFeed).latestRoundData();

    if (updatedTimestamp + 1 days <= block.timestamp) {
      revert NoPriceFound();
    }

    return uint256(answer);
  }

  function getOracleDecimals(address /*quote*/) public view returns(uint8 decimals) {
    return AggregatorV3Interface(ethPriceFeed).decimals();
  }
}
