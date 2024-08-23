// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockPriceFeed is AggregatorV3Interface {
  int256 private price;
  uint8 private priceDecimals;

  function setMockPrice(int256 _initialPrice, uint8 _decimals) external {
    price = _initialPrice;
    priceDecimals = _decimals;
  }

  function setPrice(int256 _newPrice) external {
    price = _newPrice;
  }

  function decimals() external view override returns (uint8) {
    return priceDecimals;
  }

  function description() external pure override returns (string memory) {
    return "Mock Price Feed";
  }

  function version() external pure override returns (uint256) {
    return 1;
  }

  function getRoundData(uint80 _roundId)
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return (_roundId, price, block.timestamp, block.timestamp, _roundId);
  }

  function latestRoundData()
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return (0, price, block.timestamp, block.timestamp, 0);
  }
}
