// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Distributor} from "../src/Distributor.sol";
import "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {BondToken} from "../src/BondToken.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {TokenDeployer} from "../src/utils/TokenDeployer.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract PoolFactoryTest is Test {
  PoolFactory private poolFactory;
  PoolFactory.PoolParams private params;
  Distributor private distributor;

  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private user = address(0x4);
  address private user2 = address(0x5);

  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);

    address tokenDeployer = address(new TokenDeployer());
    distributor = Distributor(Utils.deploy(address(new Distributor()), abi.encodeCall(Distributor.initialize, (governance))));
    poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(PoolFactory.initialize, (governance, tokenDeployer, address(distributor), ethPriceFeed))));

    vm.stopPrank();

    vm.startPrank(governance);
    distributor.grantRole(distributor.POOL_FACTORY_ROLE(), address(poolFactory));

    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH"));
    params.distributionPeriod = 0;
    
    vm.stopPrank();
  }
  
  function testCreatePool() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000000000);
    rToken.approve(address(poolFactory), 10000000000);

    uint256 startLength = poolFactory.poolsLength();

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 20000));
    uint256 endLength = poolFactory.poolsLength();

    assertEq(1, endLength-startLength);
    assertEq(rToken.totalSupply(), 10000000000);
    assertEq(_pool.bondToken().totalSupply(), 10000);
    assertEq(_pool.lToken().totalSupply(), 20000);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testCreatePoolErrors() public {
    vm.startPrank(governance);

    // vm.expectRevert(bytes4(keccak256("ZeroReserveAmount()")));
    // poolFactory.CreatePool(params, 0, 10000, 20000);

    // vm.expectRevert(bytes4(keccak256("ZeroDebtAmount()")));
    // poolFactory.CreatePool(params, 10000000000, 0, 20000);

    // vm.expectRevert(bytes4(keccak256("ZeroLeverageAmount()")));
    // poolFactory.CreatePool(params, 10000000000, 10000, 0);

    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(poolFactory), 0, 10000000000));
    poolFactory.CreatePool(params, 10000000000, 10000, 10000);
    
  }

  function testPause() public {
    vm.startPrank(governance);
    poolFactory.pause();

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    poolFactory.CreatePool(params, 10000000000, 10000, 10000);
    
    poolFactory.unpause();
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(poolFactory), 0, 10000000000));
    poolFactory.CreatePool(params, 10000000000, 10000, 10000);
  }
}
