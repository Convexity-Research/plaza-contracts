// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {PoolFactory} from "../src/PoolFactory.sol";
// import {PoolFactoryV2} from "../src/PoolFactoryV2.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";

contract UpgradePoolFactoryScript is Script {
  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    Options memory opts;
    opts.referenceContract = "PoolFactory.sol";

    Upgrades.upgradeProxy(
      address(0x791655c9DC561Fae3c46926815f5d75a7200D827),
      "PoolFactoryV2.sol",
      bytes(""),
      opts
    );

    vm.stopBroadcast();
  }
}
