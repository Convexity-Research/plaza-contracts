// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {BondToken} from "../src/BondToken.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Token} from "../test/mocks/Token.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DevelopmentScript is Script {
  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    
    address dToken = Utils.deploy(address(new BondToken()), abi.encodeCall(
      BondToken.initialize, 
      (
        "bondETH",
        "BOND-ETH",
        msg.sender,
        msg.sender,
        msg.sender
      )
    ));

    address lToken = Utils.deploy(address(new LeverageToken()), abi.encodeCall(
      LeverageToken.initialize, 
      (
        "levETH",
        "LVRG-ETH",
        msg.sender,
        msg.sender
      )
    ));

    PoolFactory factory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize,
      (msg.sender)
    )));

    address pool;
    uint256 reserveAmount = 1000000000000000000000;
    uint256 debtAmount = 1000000000000000000000000000000;
    uint256 leverageAmount = 1000000000000000000000000;

    PoolFactory.PoolParams memory params;
    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH"));
    params.sharesPerToken = 50000000;
    params.distributionPeriod = 7776000;

    pool = factory.CreatePool(params, reserveAmount, debtAmount, leverageAmount, dToken, lToken);

    // set minter roles
    BondToken(dToken).grantRole(BondToken(dToken).MINTER_ROLE(), pool);
    BondToken(lToken).grantRole(BondToken(lToken).MINTER_ROLE(), pool);

    vm.stopBroadcast();
  }
}
