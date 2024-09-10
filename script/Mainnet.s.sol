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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MainnetScript is Script {

  // Arbitrum Sepolia addresses
  address public constant reserveToken = address(0x4200000000000000000000000000000000000006);
  address public constant couponToken = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

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

    uint256 reserveAmount = 1000000000000000; // 0.001 ETH
    uint256 debtAmount = 25000000000000000;
    uint256 leverageAmount = 1000000000000000;

    PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: reserveToken,
      couponToken: couponToken,
      sharesPerToken: 2500000,
      distributionPeriod: 7776000 // 3 months in seconds (90 days * 24 hours * 60 minutes * 60 seconds)
    });

    // Approve the factory the seed deposit
    IERC20(reserveToken).approve(address(factory), reserveAmount);

    factory.CreatePool(params, reserveAmount, debtAmount, leverageAmount);
    vm.stopBroadcast();
  }
}
