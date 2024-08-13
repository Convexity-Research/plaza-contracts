// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {DLSP} from "../src/DLSP.sol";
import {Pool} from "../src/pool.sol";
import {Token} from "./mocks/Token.sol";
import {BondToken} from "../src/BondToken.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Utils} from "../src/lib/Utils.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract DlspTest is Test {
  DLSP private dlsp;
  DLSP.PoolParams private params;

  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private user = address(0x4);
  address private user2 = address(0x5);
  address private distributor = address(0x6);

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);

    dlsp = DLSP(Utils.deploy(address(new DLSP()), abi.encodeCall(DLSP.initialize, (governance))));

    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH"));
    params.sharesPerToken = 0;
    params.distributionPeriod = 0;
    
    vm.stopPrank();
  }
  
  function testCreatePool() public {
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000000000);
    rToken.approve(address(dlsp), 10000000000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(dlsp.CreatePool(params, 10000000000, 10000, 20000));
    rToken.approve(address(_pool), 1000);

    assertEq(rToken.totalSupply(), 10000000000);
    assertEq(_pool.dToken().totalSupply(), 10000);
    assertEq(_pool.lToken().totalSupply(), 20000);

    // Reset reserve state
    rToken.burn(governance, rToken.balanceOf(governance));
    rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
  }

  function testCreatePoolErrors() public {
    vm.startPrank(governance);

    // vm.expectRevert(bytes4(keccak256("ZeroReserveAmount()")));
    // dlsp.CreatePool(params, 0, 10000, 20000);

    // vm.expectRevert(bytes4(keccak256("ZeroDebtAmount()")));
    // dlsp.CreatePool(params, 10000000000, 0, 20000);

    // vm.expectRevert(bytes4(keccak256("ZeroLeverageAmount()")));
    // dlsp.CreatePool(params, 10000000000, 10000, 0);

    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(dlsp), 0, 10000000000));
    dlsp.CreatePool(params, 10000000000, 10000, 10000);
    
  }

  function testPause() public {
    vm.startPrank(governance);
    dlsp.pause();

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    dlsp.CreatePool(params, 10000000000, 10000, 10000);
    
    dlsp.unpause();
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(dlsp), 0, 10000000000));
    dlsp.CreatePool(params, 10000000000, 10000, 10000);
  }

  function testSetGovernance() public {
    vm.startPrank(user);
    
    vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, dlsp.GOV_ROLE()));
    dlsp.setGovernance(address(0x0));
    vm.stopPrank();

    vm.startPrank(governance);

    dlsp.setGovernance(minter);
    assertEq(dlsp.governance(), minter);

    vm.startPrank(minter);
    dlsp.setGovernance(governance);
    assertEq(dlsp.governance(), governance);
  }
}
