// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Utils} from "../lib/Utils.sol";
import {BondToken} from "../BondToken.sol";
import {LeverageToken} from "../LeverageToken.sol";

/**
 * @title TokenDeployer
 * @dev Contract for deploying BondToken and LeverageToken instances
 */
contract TokenDeployer {
  /**
   * @dev Deploys a new BondToken contract
   * @param minter The address with minting privileges
   * @param governance The address with governance privileges
   * @param distributor The address with distributor privileges
   * @param sharesPerToken The initial number of shares per token
   * @return address of the deployed BondToken contract
   */
  function deployDebtToken(
    string memory name,
    string memory symbol,
    address minter,
    address governance,
    address distributor,
    uint256 sharesPerToken
  ) external returns(address) {
    return Utils.deploy(address(new BondToken()), abi.encodeCall(
      BondToken.initialize, (name, symbol, minter, governance, distributor, sharesPerToken)
    ));
  }

  /**
   * @dev Deploys a new LeverageToken contract
   * @param minter The address with minting privileges
   * @param governance The address with governance privileges
   * @return address of the deployed LeverageToken contract
   */
  function deployLeverageToken(
    string memory name,
    string memory symbol,
    address minter,
    address governance
  ) external returns(address) {
    return Utils.deploy(address(new LeverageToken()), abi.encodeCall(
      LeverageToken.initialize, (name, symbol, minter, governance)
    ));
  }
}
