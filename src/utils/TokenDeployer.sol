// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Utils} from "../lib/Utils.sol";
import {BondToken} from "../BondToken.sol";
import {LeverageToken} from "../LeverageToken.sol";

contract TokenDeployer {
  function deployDebtToken(
    string memory name,
    string memory symbol,
    address minter,
    address governance,
    address distributor) external returns(address) {
    return Utils.deploy(address(new BondToken()), abi.encodeCall(
      BondToken.initialize, (name, symbol, minter, governance, distributor)
    ));
  }

  function deployLeverageToken(
    string memory name,
    string memory symbol,
    address minter,
    address governance) external returns(address) {
    return Utils.deploy(address(new LeverageToken()), abi.encodeCall(
      LeverageToken.initialize, (name, symbol, minter, governance)
    ));
  }
}