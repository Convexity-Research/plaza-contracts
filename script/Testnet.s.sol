// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Pool} from "../src/Pool.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Token} from "../test/mocks/Token.sol";
import {BondToken} from "../src/BondToken.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Distributor} from "../src/Distributor.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {PreDepositScript} from "./PreDeposit.s.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract TestnetScript is Script {
    // Base Sepolia addresses
    address public constant reserveToken =
        address(0x13e5FB0B6534BB22cBC59Fae339dbBE0Dc906871);
    address public constant couponToken =
        address(0xf7464321dE37BdE4C03AAeeF6b1e7b71379A9a64);

    address public constant ethPriceFeed =
        address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);

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

        address poolBeacon = address(
            new UpgradeableBeacon(address(new Pool()), deployerAddress)
        );
        address bondBeacon = address(
            new UpgradeableBeacon(address(new BondToken()), deployerAddress)
        );
        address levBeacon = address(
            new UpgradeableBeacon(address(new LeverageToken()), deployerAddress)
        );
        address distributorBeacon = address(
            new UpgradeableBeacon(address(new Distributor()), deployerAddress)
        );

        PoolFactory factory = PoolFactory(
            Utils.deploy(
                address(new PoolFactory()),
                abi.encodeCall(
                    PoolFactory.initialize,
                    (
                        deployerAddress,
                        contractDeployer,
                        oracleFeeds,
                        poolBeacon,
                        bondBeacon,
                        levBeacon,
                        distributorBeacon
                    )
                )
            )
        );

        // @todo: remove - marion address
        factory.grantRole(
            factory.GOV_ROLE(),
            0x11cba1EFf7a308Ac2cF6a6Ac2892ca33fabc3398
        );
        factory.grantRole(
            factory.GOV_ROLE(),
            0x56B0a1Ec5932f6CF6662bF85F9099365FaAf3eCd
        );

        PoolFactory.PoolParams memory params = PoolFactory.PoolParams({
            fee: fee,
            reserveToken: reserveToken,
            sharesPerToken: sharesPerToken,
            distributionPeriod: distributionPeriod,
            feeBeneficiary: deployerAddress,
            couponToken: couponToken
        });

        // Set price feed
        OracleFeeds(oracleFeeds).setPriceFeed(
            params.reserveToken,
            address(0),
            ethPriceFeed,
            1 days
        );

        Token(params.reserveToken).mint(deployerAddress, reserveAmount);
        Token(params.reserveToken).approve(address(factory), reserveAmount);

        factory.createPool(
            params,
            reserveAmount,
            bondAmount,
            leverageAmount,
            "Bond ETH",
            "bondETH",
            "Levered ETH",
            "levETH",
            false
        );

        vm.stopBroadcast();
    }
}
