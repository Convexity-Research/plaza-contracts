// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {BondToken} from "../src/BondToken.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BondTokenScript is Script {
  // @todo: update these
  address private constant minter = address(0);
  address private constant governance = address(0);
  address private constant distributor = address(0);

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    // Deploy and initialize BondToken
    BondToken implementation = new BondToken();

    // Deploy the proxy and initialize the contract through the proxy
    ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(implementation.initialize, ("BondToken", "BOND", minter, governance, distributor)));

    // BondToken token = BondToken(address(proxy));
    vm.stopBroadcast();
  }
}
