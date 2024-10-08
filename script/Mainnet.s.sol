// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Utils} from "../src/lib/Utils.sol";
import {BondToken} from "../src/BondToken.sol";
import {LifiRouter} from "../src/LifiRouter.sol";
import {Distributor} from "../src/Distributor.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {TokenDeployer} from "../src/utils/TokenDeployer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MainnetScript is Script {

  // Arbitrum Sepolia addresses
  address public constant reserveToken = address(0x4200000000000000000000000000000000000006);
  address public constant couponToken = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);

  uint256 private constant distributionPeriod = 7776000; // 3 months in seconds (90 days * 24 hours * 60 minutes * 60 seconds)
  uint256 private constant reserveAmount = 0.001 ether;
  uint256 private constant bondAmount = 0.025 ether;
  uint256 private constant leverageAmount = 0.001 ether;
  uint256 private constant sharesPerToken = 2_500_000;
  uint256 private constant fee = 0;

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));
    
    // Deploys LifiRouter
    new LifiRouter();

    // Deploys TokenDeployer
    address tokenDeployer = address(new TokenDeployer());

    // Deploys Distributor
    address distributor = Utils.deploy(address(new Distributor()), abi.encodeCall(Distributor.initialize, (deployerAddress)));

    // Deploys PoolFactory
    PoolFactory factory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize,
      (deployerAddress, tokenDeployer, distributor, ethPriceFeed)
    )));

    // Grant pool factory role to factory
    Distributor(distributor).grantRole(Distributor(distributor).POOL_FACTORY_ROLE(), address(factory));

    PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
      fee: fee,
      reserveToken: reserveToken,
      couponToken: couponToken,
      sharesPerToken: sharesPerToken,
      distributionPeriod: distributionPeriod
    });

    // Approve the factory the seed deposit
    IERC20(reserveToken).approve(address(factory), reserveAmount);

    factory.CreatePool(params, reserveAmount, bondAmount, leverageAmount);
    vm.stopBroadcast();
  }
}
