// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract OracleReader {

  // arbitrum sepolia
  address private constant ETH_PRICE_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
  address private constant WETH = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;

  // arbitrum mainnet
  // address private constant ETH_PRICE_FEED = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
  // address private constant WETH = 0x82af49447d8a07e3bd95bd0d56f35241523fbab1;

  error NoPriceFound();

  function getOraclePrice(address quote) public view returns(uint256) {
    (,int256 answer,,uint256 updatedTimestamp,) = AggregatorV3Interface(ETH_PRICE_FEED).latestRoundData();

    if (updatedTimestamp + 1 days <= block.timestamp) {
      revert NoPriceFound();
    }

    return uint256(answer);
  }

  function getOracleDecimals(address quote) public view returns(uint256 decimals) {
    return uint256(AggregatorV3Interface(ETH_PRICE_FEED).decimals());
  }
}
