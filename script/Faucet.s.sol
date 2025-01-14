// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Faucet} from "../src/Faucet.sol";
import {Token} from "../test/mocks/Token.sol";

contract FaucetScript is Script {
  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    Faucet f = new Faucet(address(0), address(0), address(0));
    
    f.addToWhitelist(address(0x1FaE1550229fE09ef3e266d8559acdcFC154e72f)); // Marion
    f.addToWhitelist(address(0x56B0a1Ec5932f6CF6662bF85F9099365FaAf3eCd)); // Vlad
    f.addToWhitelist(address(0x5dbAb2D4a3aea73CD6c6C2494A062E07a630430f)); // Neeel
    f.addToWhitelist(address(0x316778512b7a2ea2e923A99F4E7257C837a7123b)); // Illia
    f.addToWhitelist(address(0x1dabd8c1c485D00E64874d40098747573ae79665)); // Ryan
    f.addToWhitelist(address(0xE7Bc1Ed115b368B946d97e45eE79f47a14eBF179)); // Luk
    f.addToWhitelist(address(0xD1c67cC3E3A3FF83A7a75fAC21C6663004cDf684)); // Faucet API

    Token(f.couponToken()).addToWhitelist(address(f));
    Token(f.wstETH()).addToWhitelist(address(f));
    Token(f.cbETH()).addToWhitelist(address(f));

    vm.stopBroadcast();
  }
}
