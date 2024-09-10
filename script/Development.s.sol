// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Distributor} from "../src/Distributor.sol";

import {Utils} from "../src/lib/Utils.sol";
import {Token} from "../test/mocks/Token.sol";
import {BondToken} from "../src/BondToken.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {TokenDeployer} from "../src/utils/TokenDeployer.sol";

contract DevelopmentScript is Script {

  // Arbitrum Sepolia addresses
  address public constant reserveToken = address(0xDc00b8C3857320B2ba9A069cFcB8Cd01788FEea7);
  address public constant couponToken = address(0x4FCE2AFA415Ff70794d2CC6F7820Ea09dC876a7b);

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));
    
    address tokenDeployer = address(new TokenDeployer());
    address distributor = Utils.deploy(address(new Distributor()), abi.encodeCall(Distributor.initialize, (deployerAddress)));
    PoolFactory factory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize,
      (deployerAddress, tokenDeployer, distributor)
    )));

    // Grant pool factory role to factory
    Distributor(distributor).grantRole(Distributor(distributor).POOL_FACTORY_ROLE(), address(factory));

    // @todo: remove - marion address
    factory.grantRole(factory.GOV_ROLE(), 0x11cba1EFf7a308Ac2cF6a6Ac2892ca33fabc3398);
    factory.grantRole(factory.GOV_ROLE(), 0x56B0a1Ec5932f6CF6662bF85F9099365FaAf3eCd);

    address pool;
    uint256 reserveAmount = 1000000000000000000000000;
    uint256 debtAmount = 25000000000000000000000000;
    uint256 leverageAmount = 1000000000000000000000000;

    PoolFactory.PoolParams memory params;
    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH"));
    params.sharesPerToken = 2500000;
    params.distributionPeriod = 7776000; // 3 months in seconds (90 days * 24 hours * 60 minutes * 60 seconds)
    params.couponToken = address(0);

    Token(params.reserveToken).mint(deployerAddress, reserveAmount);
    Token(params.reserveToken).approve(address(factory), reserveAmount);

    // // @todo: not for prod
    // BondToken(dToken).grantRole(BondToken(dToken).MINTER_ROLE(), address(factory));
    // BondToken(lToken).grantRole(BondToken(lToken).MINTER_ROLE(), address(factory));

    // // @todo: not for prod
    // BondToken(dToken).grantRole(BondToken(dToken).GOV_ROLE(), address(factory));
    // BondToken(lToken).grantRole(BondToken(lToken).GOV_ROLE(), address(factory));

    // // @todo: not for prod
    // BondToken(dToken).grantRole(BondToken(dToken).DEFAULT_ADMIN_ROLE(), address(factory));
    // BondToken(lToken).grantRole(BondToken(lToken).DEFAULT_ADMIN_ROLE(), address(factory));

    pool = factory.CreatePool(params, reserveAmount, debtAmount, leverageAmount);
    
    vm.stopBroadcast();
  }
}
