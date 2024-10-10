// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Utils
 * @dev Library containing utility functions for contract deployment
 */
library Utils {
  /**
    * @dev Deploys a new upgradeable proxy contract
    * @param implementation The address of the implementation contract
    * @param initialize The initialization data for the proxy contract
    * @return address The address of the newly deployed proxy contract
    */
  function deploy(address implementation, bytes memory initialize) internal returns (address) {
    ERC1967Proxy proxy = new ERC1967Proxy(
      implementation, 
      initialize
    );

    return address(proxy);
  }
}
