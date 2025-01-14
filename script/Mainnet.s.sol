// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Pool} from "../src/Pool.sol";
import {BondToken} from "../src/BondToken.sol";
import {LifiRouter} from "../src/LifiRouter.sol";
import {Distributor} from "../src/Distributor.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {PreDepositScript} from "./PreDeposit.s.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract MainnetScript is Script {

  // Base Mainnet addresses
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
    PreDepositScript preDepositScript = new PreDepositScript();
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));
    
    // Deploys LifiRouter
    new LifiRouter();

    // Deploys Deployer
    address contractDeployer = address(new Deployer());

    // Deploys OracleFeeds
    address oracleFeeds = address(new OracleFeeds());

    // Pool, Bond & Leverage Beacon Deploy
    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), deployerAddress));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), deployerAddress));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), deployerAddress));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), deployerAddress));

    // Deploys PoolFactory
    PoolFactory factory = PoolFactory(Upgrades.deployUUPSProxy("PoolFactory.sol", abi.encodeCall(
      PoolFactory.initialize,
      (deployerAddress, contractDeployer, oracleFeeds, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
    )));

    PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
      fee: fee,
      reserveToken: reserveToken,
      couponToken: couponToken,
      sharesPerToken: sharesPerToken,
      distributionPeriod: distributionPeriod,
      feeBeneficiary: deployerAddress
    });

    // Set price feed
    OracleFeeds(oracleFeeds).setPriceFeed(params.reserveToken, address(0), ethPriceFeed, 1 days);

    // Approve the factory the seed deposit
    IERC20(reserveToken).approve(address(factory), reserveAmount);

    factory.createPool(params, reserveAmount, bondAmount, leverageAmount, "Bond ETH", "bondETH", "Levered ETH", "levETH", false);

    preDepositScript.run(reserveToken, couponToken, address(factory), deployerAddress, distributionPeriod, sharesPerToken);
    
    vm.stopBroadcast();
  }
}
