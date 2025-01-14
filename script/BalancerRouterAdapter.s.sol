// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {Utils} from "../src/lib/Utils.sol";
import {BalancerOracleAdapter} from "../src/BalancerOracleAdapter.sol";

contract BalancerOracleAdapterScript is Script {
  address public constant poolAddress = 0x8fF5Fec90944460756168f764FD546ef8C8d2162;
  address public constant oracleFeeds = 0x756Bf9deABd6a29Fb2D666b49b6eE1022f56296d;

  function setUp() public {}

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));

    BalancerOracleAdapter(Utils.deploy(
      address(new BalancerOracleAdapter()),
      abi.encodeWithSelector(
        BalancerOracleAdapter.initialize.selector,
        poolAddress,
        18,
        oracleFeeds,
        deployerAddress
      )
    ));

    vm.stopBroadcast();
  }
}
