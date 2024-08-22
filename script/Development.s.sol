// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {BondToken} from "../src/BondToken.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Token} from "../test/mocks/Token.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DevelopmentScript is Script {
  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));
    
    address dToken = Utils.deploy(address(new BondToken()), abi.encodeCall(
      BondToken.initialize, 
      (
        "bondETH",
        "BOND-ETH",
        deployerAddress,
        deployerAddress,
        deployerAddress
      )
    ));

    address lToken = Utils.deploy(address(new LeverageToken()), abi.encodeCall(
      LeverageToken.initialize, 
      (
        "levETH",
        "LVRG-ETH",
        deployerAddress,
        deployerAddress
      )
    ));

    PoolFactory factory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize,
      (deployerAddress)
    )));

    address pool;
    uint256 reserveAmount = 1000000000000000000000000;
    uint256 debtAmount = 25000000000000000000000000;
    uint256 leverageAmount = 1000000000000000000000000;

    PoolFactory.PoolParams memory params;
    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH"));
    params.sharesPerToken = 50000000;
    params.distributionPeriod = 7776000;
    params.couponToken = address(0);

    Token(params.reserveToken).mint(deployerAddress, reserveAmount);
    Token(params.reserveToken).approve(address(factory), reserveAmount);

    // @todo: not for prod
    BondToken(dToken).grantRole(BondToken(dToken).MINTER_ROLE(), address(factory));
    BondToken(lToken).grantRole(BondToken(lToken).MINTER_ROLE(), address(factory));

    // @todo: not for prod
    BondToken(dToken).grantRole(BondToken(dToken).GOV_ROLE(), address(factory));
    BondToken(lToken).grantRole(BondToken(lToken).GOV_ROLE(), address(factory));

    // @todo: not for prod
    BondToken(dToken).grantRole(BondToken(dToken).DEFAULT_ADMIN_ROLE(), address(factory));
    BondToken(lToken).grantRole(BondToken(lToken).DEFAULT_ADMIN_ROLE(), address(factory));

    pool = factory.CreatePool(params, reserveAmount, debtAmount, leverageAmount, dToken, lToken);
    
    vm.stopBroadcast();
  }
}
