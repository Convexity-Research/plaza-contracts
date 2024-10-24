// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Decimals} from "./lib/Decimals.sol";
import {IERC20} from "@balancer/contracts/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {OracleReader} from "./OracleReader.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IBalancerV2WeightedPool} from "./lib/balancer/IBalancerV2WeightedPool.sol";
import {FixedPoint} from "./lib/balancer/FixedPoint.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {VaultReentrancyLib} from "./lib/balancer/VaultReentrancyLib.sol";

contract BalancerOracleAdapter is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, AggregatorV3Interface, OracleReader {
  using Decimals for uint256;
  using FixedPoint for uint256;

  address public poolAddress;
  uint8 public DECIMALS;

  error PriceTooLargeForIntConversion();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the BalancerOracleAdapter.
   * This function is called once during deployment or upgrading to initialize state variables.
   * @param _poolAddress Address of the BALANCER Pool used for the oracle.
   * @param _decimals Number of decimals returned by the oracle.
   * @param _oracleFeeds Address of the OracleReader feeds contract, containing the Chainlink price feeds for each asset in the pool.
   */
  function initialize(
    address _poolAddress,
    uint8 _decimals,
    address _oracleFeeds
  ) initializer external {
    __OracleReader_init(_oracleFeeds);
    __ReentrancyGuard_init();
    __Pausable_init();
    poolAddress = _poolAddress;
    DECIMALS = _decimals;
  }

  /**
   * @dev Returns the number of decimals used by the oracle.
   * @return uint8 The number of decimals.
   */
  function decimals() external view returns (uint8){
    return DECIMALS;
  }

  /**
   * @dev Returns the description of the oracle.
   * @return string The description.
   */
  function description() external pure returns (string memory){
    return "Balancer Pool Chainlink Adapter";
  }

  /**
   * @dev Returns the version of the oracle.
   * @return uint256 The version.
   */
  function version() external pure returns (uint256){
    return 1;
  }

  /**
   * @dev Returns the round data for a given round ID. The errors for this portion of the oracle regarding freshness are handled in the OracleReader contract.
   * @param _roundId The round ID. Always 0 for this oracle.
   * @return roundId The round ID.
   * @return answer The price.
   * @return startedAt The timestamp of the round.
   * @return updatedAt The timestamp of the round.
   * @return answeredInRound The round ID.
   */
  function getRoundData(
    uint80 _roundId
  ) public view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
    IBalancerV2WeightedPool pool = IBalancerV2WeightedPool(poolAddress);
    VaultReentrancyLib.ensureNotInVaultContext(IVault(pool.getVault()));
    (IERC20[] memory tokens,,) = IVault(pool.getVault()).getPoolTokens(pool.getPoolId());
    //get weights
    uint256[] memory weights = pool.getNormalizedWeights(); // 18 dec fractions
    uint256[] memory prices = new uint256[](tokens.length);
    for(uint8 i = 0; i < tokens.length; i++) {
      getOraclePrice(address(tokens[i]), ETH).toBaseUnit(DECIMALS); // balancer math works with 18 dec
    }

    uint256 fairUintETHPrice = _calculateFairUintPrice(prices, weights, pool.getInvariant(), pool.getActualSupply());
    uint256 fairUintUSDPrice = fairUintETHPrice.mulDown(getOraclePrice(ETH, USD));

    if (fairUintUSDPrice > (2^256>>1)-1) {
      revert PriceTooLargeForIntConversion();
    }

    return (uint80(0), int256(fairUintUSDPrice), block.timestamp, block.timestamp, uint80(0));
  }

  /**
   * @dev Returns the latest round data. Calls getRoundData with round ID 0.
   * @return roundId The round ID. Always 0 for this oracle.
   * @return answer The price.
   * @return startedAt The timestamp of the round.
   * @return updatedAt The timestamp of the round.
   * @return answeredInRound The round ID. Always 0 for this oracle.
   */
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
      return getRoundData(0);
    }

  /**
   * @dev Calculates the fair price of the pool in USD using the Balancer invariant formula: https://docs.balancer.fi/concepts/advanced/valuing-bpt/valuing-bpt.html#on-chain-price-evaluation.
   * @param prices Array of prices of the assets in the pool.
   * @param weights Array of weights of the assets in the pool.
   * @param invariant The invariant of the pool.
   * @param totalBPTSupply The total supply of BPT in the pool.
   * @return uint256 The fair price of the pool in USD.
   */
  function _calculateFairUintPrice(
    uint256[] memory prices,
    uint256[] memory weights,
    uint256 invariant,
    uint256 totalBPTSupply
    ) internal view returns (uint256) {
    uint256 priceWeightPower = FixedPoint.ONE;
    for(uint8 i = 0; i < prices.length; i ++) {
      priceWeightPower = priceWeightPower.mulDown(prices[i].divDown(weights[i]).powDown(weights[i]));
    }
    return invariant.mulDown(priceWeightPower).divDown(totalBPTSupply);
  }

  /**
   * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
   * {upgradeTo} and {upgradeToAndCall}.
   * @param newImplementation Address of the new implementation contract
   */
  function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
  {}
}