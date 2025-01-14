// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BondToken} from "../BondToken.sol";
import {Distributor} from "../Distributor.sol";
import {LeverageToken} from "../LeverageToken.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

/**
 * @title Deployer
 * @dev Contract for deploying BondToken and LeverageToken instances
 */
contract Deployer {
  /**
   * @dev Deploys a new BondToken contract
   * @param bondBeacon The address of the beacon for the BondToken
   * @param minter The address with minting privileges
   * @param governance The address with governance privileges
   * @param sharesPerToken The initial number of shares per token
   * @return address of the deployed BondToken contract
   */
  function deployBondToken(
    address bondBeacon,
    string memory name,
    string memory symbol,
    address minter,
    address governance,
    address poolFactory,
    uint256 sharesPerToken
  ) external returns(address) {
    return address(new BeaconProxy(
      address(bondBeacon),
      abi.encodeCall(
        BondToken.initialize, (name, symbol, minter, governance, poolFactory, sharesPerToken)
      )
    ));
  }

  /**
   * @dev Deploys a new LeverageToken contract
   * @param minter The address with minting privileges
   * @param governance The address with governance privileges
   * @return address of the deployed LeverageToken contract
   */
  function deployLeverageToken(
    address leverageBeacon,
    string memory name,
    string memory symbol,
    address minter,
    address governance,
    address poolFactory
  ) external returns(address) {

    return address(new BeaconProxy(
      address(leverageBeacon),
      abi.encodeCall(
        LeverageToken.initialize, (name, symbol, minter, governance, poolFactory)
      )
    ));
  }

  /**
   * @dev Deploys a new Distributor contract
   * @param pool The address of the pool
   * @return address of the deployed Distributor contract
   */
  function deployDistributor(
    address distributorBeacon,
    address pool,
    address poolFactory
  ) external returns(address) {

    return address(new BeaconProxy(
      address(distributorBeacon),
      abi.encodeCall(
        Distributor.initialize, (pool, poolFactory)
      )
    ));
  }
}
