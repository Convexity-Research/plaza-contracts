// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {BondToken} from "../src/BondToken.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Distributor} from "../src/Distributor.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Create3} from "@create3/contracts/Create3.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract PoolFactoryTest is Test {
  PoolFactory private poolFactory;
  PoolFactory.PoolParams private params;
  Distributor private distributor;

  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private securityCouncil = address(0x4);
  address private user = address(0x5);
  address private user2 = address(0x6);

  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);

    address contractDeployer = address(new Deployer());

    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));

    poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize, 
      (governance, contractDeployer, ethPriceFeed, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
    )));

    vm.stopPrank();

    vm.startPrank(governance);
    poolFactory.grantRole(poolFactory.POOL_ROLE(), governance);
    poolFactory.grantRole(poolFactory.SECURITY_COUNCIL_ROLE(), securityCouncil);
    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH", false));
    params.distributionPeriod = 0;
  }
  
  function testCreatePool() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000000000);
    rToken.approve(address(poolFactory), 10000000000);

    uint256 startLength = poolFactory.poolsLength();

    vm.expectEmit(true, true, true, false);
    // Pool address is not deterministic
    emit PoolFactory.PoolCreated(address(0), 10000000000, 10000, 20000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10000000000, 10000, 20000, "", "", "", "", false));
    uint256 endLength = poolFactory.poolsLength();

    assertEq(1, endLength-startLength);
    assertEq(rToken.totalSupply(), 10000000000);
    assertEq(_pool.bondToken().totalSupply(), 10000);
    assertEq(_pool.lToken().totalSupply(), 20000);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testCreatePoolDeterministic() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 1);
    rToken.approve(address(poolFactory), 1);
    
    // address poolAddress = poolFactory.getPoolAddress(params.reserveToken, params.couponToken, "bondWETH", "levWETH");

    bytes32 salt = keccak256(abi.encodePacked(
      params.reserveToken,
      params.couponToken,
      "bondWETH",
      "levWETH"
    ));

    address proxyAddress = address(uint160(uint256(keccak256(abi.encodePacked(
      hex'ff',
      address(poolFactory),
      salt,
      Create3.KECCAK256_PROXY_CHILD_BYTECODE
    )))));

    address poolAddress = address(uint160(uint256(keccak256(abi.encodePacked(
      hex"d6_94",
      proxyAddress,
      hex"01"
    )))));

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 1, 1, 1, "", "bondWETH", "", "levWETH", false));

    assertEq(address(_pool), poolAddress);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testCreatePoolErrors() public {
    vm.startPrank(governance);

    vm.expectRevert(bytes4(keccak256("ZeroReserveAmount()")));
    poolFactory.createPool(params, 0, 10000, 20000, "", "", "", "", false);

    vm.expectRevert(bytes4(keccak256("ZeroDebtAmount()")));
    poolFactory.createPool(params, 10000000000, 0, 20000, "", "", "", "", false);

    vm.expectRevert(bytes4(keccak256("ZeroLeverageAmount()")));
    poolFactory.createPool(params, 10000000000, 10000, 0, "", "", "", "", false);

    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(poolFactory), 0, 10000000000));
    poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false);
    
  }

  function testPause() public {
    vm.startPrank(securityCouncil);
    poolFactory.pause();

    vm.startPrank(governance);
    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false);

    vm.startPrank(securityCouncil);
    poolFactory.unpause();

    vm.startPrank(governance);
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(poolFactory), 0, 10000000000));
    poolFactory.createPool(params, 10000000000, 10000, 10000, "", "", "", "", false);
  }
}
