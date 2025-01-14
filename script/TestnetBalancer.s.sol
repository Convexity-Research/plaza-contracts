// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Pool} from "../src/Pool.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Token} from "../test/mocks/Token.sol";
import {BondToken} from "../src/BondToken.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Distributor} from "../src/Distributor.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {BalancerRouter} from "../src/BalancerRouter.sol";
import {BalancerOracleAdapter} from "../src/BalancerOracleAdapter.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract TestnetBalancerScript is Script {

  // Base Sepolia addresses
  address private constant couponToken = address(0x8af55036DaCB876054E505d5bb76B2f8340060d5); // Fake USDC
  address private constant wstEthToken = address(0x92862aa1ccB2B399a6236A6C7165aC54F7cB7a91); // Fake wstETH
  address private constant cbEthToken = address(0x1197766B82Eee9c2e57674E53F0D961590e43769); // Fake cbETH
  
  address private constant ethPriceFeed = address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);
  address private constant cbEthPriceFeed = address(0x3c65e28D357a37589e1C7C86044a9f44dDC17134);

  address private constant balancerVault = address(0x8fF5Fec90944460756168f764FD546ef8C8d2162);
  address private constant balancerPoolToken = address(0x8fF5Fec90944460756168f764FD546ef8C8d2162);

  uint256 private constant distributionPeriod = 7776000; // 3 months in seconds (90 days * 24 hours * 60 minutes * 60 seconds)
  uint256 private constant reserveAmount = 1_000_000 ether;
  uint256 private constant bondAmount = 25_000_000 ether;
  uint256 private constant leverageAmount = 1_000_000 ether;
  uint256 private constant sharesPerToken = 2_500_000;
  uint256 private constant fee = 0;

  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));
    
    address contractDeployer = address(new Deployer());

    // Deploys OracleFeeds
    address oracleFeeds = address(new OracleFeeds());

    // Deploy Balancer Router
    new BalancerRouter(balancerVault, balancerPoolToken);

    // Deploy Balancer Oracle Adapter
    address balancerOracleAdapter = Utils.deploy(address(new BalancerOracleAdapter()), abi.encodeCall(
      BalancerOracleAdapter.initialize,
      (
        balancerPoolToken,
        18,
        oracleFeeds,
        msg.sender
      )
    ));
    
    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), deployerAddress));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), deployerAddress));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), deployerAddress));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), deployerAddress));

    PoolFactory factory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize,
      (deployerAddress, contractDeployer, oracleFeeds, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
    )));

    factory.grantRole(factory.POOL_ROLE(), deployerAddress);
    
    factory.grantRole(factory.GOV_ROLE(), 0x11cba1EFf7a308Ac2cF6a6Ac2892ca33fabc3398); // Marion
    factory.grantRole(factory.GOV_ROLE(), 0x5dbAb2D4a3aea73CD6c6C2494A062E07a630430f); // Neeel
    factory.grantRole(factory.GOV_ROLE(), 0x316778512b7a2ea2e923A99F4E7257C837a7123b); // Illia
    factory.grantRole(factory.GOV_ROLE(), 0x1dabd8c1c485D00E64874d40098747573ae79665); // Ryan
    factory.grantRole(factory.GOV_ROLE(), 0xE7Bc1Ed115b368B946d97e45eE79f47a14eBF179); // Luk

    factory.grantRole(factory.POOL_ROLE(), 0x11cba1EFf7a308Ac2cF6a6Ac2892ca33fabc3398); // Marion
    factory.grantRole(factory.POOL_ROLE(), 0x5dbAb2D4a3aea73CD6c6C2494A062E07a630430f); // Neeel
    factory.grantRole(factory.POOL_ROLE(), 0x316778512b7a2ea2e923A99F4E7257C837a7123b); // Illia
    factory.grantRole(factory.POOL_ROLE(), 0x1dabd8c1c485D00E64874d40098747573ae79665); // Ryan
    factory.grantRole(factory.POOL_ROLE(), 0xE7Bc1Ed115b368B946d97e45eE79f47a14eBF179); // Luk

    PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
      fee: fee,
      reserveToken: balancerPoolToken,
      sharesPerToken: sharesPerToken,
      distributionPeriod: distributionPeriod,
      feeBeneficiary: deployerAddress,
      couponToken: couponToken
    });

    // Set price feeds
    OracleFeeds(oracleFeeds).setPriceFeed(balancerPoolToken, address(0), balancerOracleAdapter, 1 days);
    OracleFeeds(oracleFeeds).setPriceFeed(cbEthToken, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), cbEthPriceFeed, 1 days);
    OracleFeeds(oracleFeeds).setPriceFeed(wstEthToken, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), ethPriceFeed, 1 days);
    OracleFeeds(oracleFeeds).setPriceFeed(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), address(0), ethPriceFeed, 1 days);
    
    Token(params.reserveToken).approve(address(factory), reserveAmount);
    
    factory.createPool(params, reserveAmount, bondAmount, leverageAmount, "Bond ETH", "bondETH", "Levered ETH", "levETH", false);
    
    vm.stopBroadcast();
  }
}
