// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Faucet} from "../src/Faucet.sol";

contract FaucetScript is Script {
  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    Faucet f = new Faucet();
    f.addToWhitelist(address(0x11cba1EFf7a308Ac2cF6a6Ac2892ca33fabc3398));
    f.addToWhitelist(address(0x56B0a1Ec5932f6CF6662bF85F9099365FaAf3eCd));
    vm.stopBroadcast();
  }
}
