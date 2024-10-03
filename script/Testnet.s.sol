// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Distributor} from "../src/Distributor.sol";

import {Pool} from "../src/Pool.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Token} from "../test/mocks/Token.sol";
import {BondToken} from "../src/BondToken.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {TokenDeployer} from "../src/utils/TokenDeployer.sol";

contract TestnetScript is Script {

  // Base Sepolia addresses
  address public constant merchant = address(0);
  address public constant reserveToken = address(0x0a38120534DA7Df6A52138926f3ceC7C970B14a1);
  address public constant couponToken = address(0xa31577f757f371436373415F6894Cc7E37FD9D1D);

  address public constant ethPriceFeed = address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);

  uint256 private constant distributionPeriod = 7776000; // 3 months in seconds (90 days * 24 hours * 60 minutes * 60 seconds)
  uint256 private constant reserveAmount = 1_000_000 ether;
  uint256 private constant bondAmount = 25_000_000 ether;
  uint256 private constant leverageAmount = 1_000_000 ether;
  uint256 private constant sharesPerToken = 2_500_000;
  uint256 private constant fee = 0;

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));
    
    address tokenDeployer = address(new TokenDeployer());
    address distributor = Utils.deploy(address(new Distributor()), abi.encodeCall(Distributor.initialize, (deployerAddress)));
    PoolFactory factory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize,
      (deployerAddress, tokenDeployer, distributor, ethPriceFeed)
    )));

    // Grant pool factory role to factory
    Distributor(distributor).grantRole(Distributor(distributor).POOL_FACTORY_ROLE(), address(factory));

    // @todo: remove - marion address
    factory.grantRole(factory.GOV_ROLE(), 0x11cba1EFf7a308Ac2cF6a6Ac2892ca33fabc3398);
    factory.grantRole(factory.GOV_ROLE(), 0x56B0a1Ec5932f6CF6662bF85F9099365FaAf3eCd);

    PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
      fee: fee,
      reserveToken: reserveToken,
      sharesPerToken: sharesPerToken,
      distributionPeriod: distributionPeriod,
      couponToken: couponToken
    });

    Token(params.reserveToken).mint(deployerAddress, reserveAmount);
    Token(params.reserveToken).approve(address(factory), reserveAmount);

    address _pool = factory.CreatePool(params, reserveAmount, bondAmount, leverageAmount);
    Pool(_pool).setMerchant(merchant);
    
    vm.stopBroadcast();
  }
}
