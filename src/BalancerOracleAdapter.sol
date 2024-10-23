// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OracleReader} from "./OracleReader.sol";
import {Vault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract BalancerOracleAdapter is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable, AggregatorV3Interface, OracleReader {

  address public vaultAddress;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _vaultAddress,
    address _oracleFeeds
  ) initializer public {
    __OracleReader_init(_oracleFeeds);
    __ReentrancyGuard_init();
    __Pausable_init();
    vaultAddress = _vaultAddress;
  }

  function decimals() external view returns (uint8){
    return 18;
  }

  function description() external view returns (string memory){
    return "Balancer Pool Chainlink Adapter";
  }

  function version() external view returns (uint256){
    return 1;
  }

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
    (IERC20[] tokens, uint256[] balances, uint256 lastChangedBlock) = IVault(vaultAddress).getPoolTokens(poolId);
    
    uint256 totalPriceWeight = 0;
    uint256 totalWeight = 0;
    for(i = 0; i < tokens.length; i++) {
      totalPriceWeight += getOraclePrice(tokens[i], USD); // this already handles all errors, todo: handle all different decimals
      totalWeight += balances[i];
    }

    return (0, totalPriceWeight/totalWeight, block.timestamp, block.timestamp, 0);
  }

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
      return getRoundData(0);
    }
}