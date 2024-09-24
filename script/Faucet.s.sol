// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Faucet} from "../src/Faucet.sol";

contract FaucetScript is Script {
  address constant private mockMerchant = address(0x0000000000000000000000000000000000000000);
  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    require(mockMerchant != address(0), "Mock merchant address is not set");
    
    Faucet f = new Faucet(mockMerchant);
    // Marion
    f.addToWhitelist(address(0x1FaE1550229fE09ef3e266d8559acdcFC154e72f));
    // Vlad
    f.addToWhitelist(address(0x56B0a1Ec5932f6CF6662bF85F9099365FaAf3eCd));
    // Neeel
    f.addToWhitelist(address(0x5dbAb2D4a3aea73CD6c6C2494A062E07a630430f));

    vm.stopBroadcast();
  }
}
