// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Utils} from "../lib/Utils.sol";
import {BondToken} from "../BondToken.sol";
import {LeverageToken} from "../LeverageToken.sol";

contract TokenDeployer {
  function deployDebtToken(
    string memory /*name*/,
    string memory /*symbol*/,
    address minter,
    address governance,
    address distributor,
    uint256 sharesPerToken
    ) external returns(address) {
    return Utils.deploy(address(new BondToken()), abi.encodeCall(
      // @todo: figure out naming convention
      BondToken.initialize, ("Bond ETH", "bondETH", minter, governance, distributor, sharesPerToken)
    ));
  }

  function deployLeverageToken(
    string memory /*name*/,
    string memory /*symbol*/,
    address minter,
    address governance) external returns(address) {
    return Utils.deploy(address(new LeverageToken()), abi.encodeCall(
      // @todo: figure out naming convention
      LeverageToken.initialize, ("Leverage ETH", "levETH", minter, governance)
    ));
  }
}
