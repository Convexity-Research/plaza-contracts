// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Decimals} from "./lib/Decimals.sol";
import {ERC20Extensions} from "./lib/ERC20Extensions.sol";
import {ICLPool} from "./lib/concentrated-liquidity/ICLPool.sol";
import {FullMath} from "./lib/concentrated-liquidity/FullMath.sol";
import {TickMath} from "./lib/concentrated-liquidity/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICLFactory} from "./lib/concentrated-liquidity/ICLFactory.sol";
import {FixedPoint96} from "./lib/concentrated-liquidity/FixedPoint96.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract BondOracleAdapter is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable, AggregatorV3Interface {
  using Decimals for uint256;
  using ERC20Extensions for IERC20;

  address public dexFactory;
  address public dexPool;
  uint32 public twapInterval;

  address private bondToken;
  address private liquidityToken;

  uint8 public decimals;

  error NoPoolFound();
  error NotImplemented();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the BalancerOracleAdapter.
   * This function is called once during deployment or upgrading to initialize state variables.
   * @param _bondToken Address of the bond token used for the oracle.
   * @param _liquidityToken Address of the liquidity token used for the oracle.
   * @param _twapInterval The time interval for the TWAP calculation.
   * @param _dexFactory Address of the Concentrated Liquidity factory.
   * @param _owner Address of the owner of the contract.
   */
  function initialize(
    address _bondToken,
    address _liquidityToken,
    uint32 _twapInterval,
    address _dexFactory,
    address _owner
  ) initializer external {
    __Ownable_init(_owner);
    __Pausable_init();
    bondToken = _bondToken;
    liquidityToken = _liquidityToken;
    dexFactory = _dexFactory;
    (dexPool,,) = getPool(bondToken, liquidityToken);

    decimals = IERC20(_bondToken).safeDecimals();
    twapInterval = _twapInterval;
  }

  /**
   * @dev Returns the description of the oracle.
   * @return string The description.
   */
  function description() external view returns (string memory){
    return string(abi.encodePacked(IERC20(bondToken).safeSymbol(), "/", IERC20(liquidityToken).safeSymbol(), " Oracle Price"));
  }

  /**
   * @dev Returns the version of the oracle.
   * @return uint256 The version.
   */
  function version() external pure returns (uint256){
    return 1;
  }

  /**
   * @dev Not implemented.
   */
  function getRoundData(
    uint80 /*_roundId*/
  ) public pure returns (uint80, int256, uint256, uint256, uint80) {
    revert NotImplemented();
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
    returns (uint80, int256, uint256, uint256, uint80){
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = twapInterval; // from (before)
    secondsAgos[1] = 0; // to (now)

    (int56[] memory tickCumulatives, ) = ICLPool(dexPool).observe(secondsAgos);

    uint160 getSqrtTwapX96 = TickMath.getSqrtRatioAtTick(
      int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)))
    );

    return (uint80(0), int256(getPriceX96FromSqrtPriceX96(getSqrtTwapX96)), block.timestamp, block.timestamp, uint80(0));
  }

  function getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96) public pure returns(uint256) {
    return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
  }

  function getPool(address tokenA, address tokenB) private view returns (address, uint24, int24) {
    // this only works for Aerodrome, they decided to break compatibility with getPool mapping
    int24[5] memory spacing = [int24(1), int24(50), int24(100), int24(200), int24(2000)];

    for (uint24 i = 0; i < spacing.length; i++) {
      try ICLFactory(dexFactory).getPool(tokenA, tokenB, spacing[i]) returns (address _pool) {
        if (_pool == address(0)) continue;
        
        // Aerodrome CL specific
        (bool success, bytes memory data) = dexFactory.staticcall(abi.encodeWithSignature("tickSpacingToFee(int24)", spacing[i]));
        if (!success) continue;
        
        return (_pool, abi.decode(data, (uint24)), spacing[i]);

      } catch {}
    }

    revert NoPoolFound();
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
