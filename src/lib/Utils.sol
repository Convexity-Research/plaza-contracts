// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

library Utils {
  function deploy(address implementation, bytes memory initialize) internal returns (address) {
    ERC1967Proxy proxy = new ERC1967Proxy(
      implementation, 
      initialize
    );

    return address(proxy);
  }
}
