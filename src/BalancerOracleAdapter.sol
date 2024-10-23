// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Decimals} from "./lib/Decimals.sol";
import {IERC20} from "@balancer/contracts/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {OracleReader} from "./OracleReader.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract BalancerOracleAdapter is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable, AggregatorV3Interface, OracleReader {
  using Decimals for uint256;

  address public vaultAddress;
  bytes32 public poolId;
  uint8 DECIMALS;

  error PriceTooLargeForIntConversion();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _vaultAddress,
    bytes32 _poolId,
    uint8 _decimals,
    address _oracleFeeds
  ) initializer public {
    __OracleReader_init(_oracleFeeds);
    __ReentrancyGuard_init();
    __Pausable_init();
    vaultAddress = _vaultAddress;
    poolId = _poolId;
    DECIMALS = _decimals;
  }

  function decimals() external view returns (uint8){
    return DECIMALS;
  }

  function description() external view returns (string memory){
    return "Balancer Pool Chainlink Adapter";
  }

  function version() external view returns (uint256){
    return 1;
  }

  function getRoundData(
    uint80 _roundId
  ) public view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
    (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangedBlock) = IVault(vaultAddress).getPoolTokens(poolId);
    
    uint256 totalPriceWeight = 0;
    uint256 totalWeight = 0;
    for(uint256 i = 0; i < tokens.length; i++) {
      uint8 oracleDecimals = getOracleDecimals(address(tokens[i]), USD);
      // this already handles all errors that have to do with price freshness
      totalPriceWeight += (getOraclePrice(address(tokens[i]), USD) * balances[i]).normalizeAmount(oracleDecimals, DECIMALS);
      totalWeight += balances[i].normalizeAmount(oracleDecimals, DECIMALS);
    }

    uint256 uintPrice = totalPriceWeight/totalWeight;
    if (uintPrice > (2^256>>1)-1) {
      revert PriceTooLargeForIntConversion();
    }

    return (uint80(0), int256(uintPrice), block.timestamp, block.timestamp, uint80(0));
  }

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
      return getRoundData(0);
    }
}