// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {BondToken} from "../src/BondToken.sol";
import {Distributor} from "../src/Distributor.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {TokenDeployer} from "../src/utils/TokenDeployer.sol";

contract DistributorTest is Test {
  Distributor public distributor;
  Pool public _pool;
  PoolFactory.PoolParams private params;

  address public user = address(0x1);
  address public sharesTokenOwner = address(0x2);
  address private deployer = address(0x3);
  address private minter = address(0x4);
  address private governance = address(0x5);

  function setUp() public {
    vm.startPrank(deployer);

    address tokenDeployer = address(new TokenDeployer());
    PoolFactory poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(PoolFactory.initialize, (governance,tokenDeployer))));

    // Distributor deploy
    distributor = Distributor(Utils.deploy(address(new Distributor()), abi.encodeCall(Distributor.initialize, (governance))));

    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);

    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH"));
    params.sharesPerToken = 50000;
    params.distributionPeriod = 0;
    params.couponToken = address(new Token("Circle USD", "USDC"));
    
    vm.stopPrank(); 
    vm.startPrank(governance);
    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 10000000000);
    rToken.approve(address(poolFactory), 10000000000);

    // Create pool and approve deposit amount
    _pool = Pool(poolFactory.CreatePool(params, 10000000000, 10000, 10000));

    _pool.dToken().grantRole(_pool.dToken().DISTRIBUTOR_ROLE(), address(distributor));
    _pool.dToken().grantRole(_pool.dToken().MINTER_ROLE(), minter);
    _pool.lToken().grantRole(_pool.lToken().MINTER_ROLE(), minter);

    // Set period to 1
    _pool.dToken().increaseIndexedAssetPeriod(200);
  }

  function testClaimShares() public {
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(minter);
    _pool.dToken().mint(user, 10000);
    sharesToken.mint(address(distributor), 1000);
    vm.stopPrank();

    (uint256 lastUpdatedPeriod, uint256 shares) = _pool.dToken().userAssets(user);

    vm.startPrank(governance);
    _pool.dToken().increaseIndexedAssetPeriod(200);
    vm.stopPrank();

    vm.startPrank(user);

    // @todo: figure out why it doesn't match
    // vm.expectEmit(true, true, true, true);
    // emit Distributor.ClaimedShares(user, 1, 200);

    _pool.dToken().transfer(address(0x24), 1);

    (lastUpdatedPeriod, shares) = _pool.dToken().userAssets(user);

    distributor.claim(address(_pool));
    assertEq(sharesToken.balanceOf(user), 200);
    vm.stopPrank();
  }

  function testClaimInsufficientSharesBalance() public {
    vm.startPrank(minter);
    _pool.dToken().mint(user, 1000);
    vm.stopPrank();

    vm.startPrank(governance);
    _pool.dToken().increaseIndexedAssetPeriod(200);
    vm.stopPrank();

    vm.startPrank(user);
    vm.expectRevert(Distributor.NotEnoughSharesBalance.selector);
    distributor.claim(address(_pool));
    vm.stopPrank();
  }

  function testClaimNonExistentPool() public {
    vm.startPrank(user);
    vm.expectRevert(Distributor.UnsupportedPool.selector);
    distributor.claim(address(0));
    vm.stopPrank();
  }

  function testClaimAfterMultiplePeriods() public {
    Token sharesToken = Token(_pool.couponToken());

    vm.startPrank(minter);
    _pool.dToken().mint(user, 1000);
    sharesToken.mint(address(distributor), 50);
    vm.stopPrank();

    vm.startPrank(governance);
    _pool.dToken().increaseIndexedAssetPeriod(100);
    _pool.dToken().increaseIndexedAssetPeriod(200);
    _pool.dToken().increaseIndexedAssetPeriod(300);
    vm.stopPrank();

    vm.startPrank(user);
    // vm.expectEmit(true, true, true, true);
    // emit distributor.ClaimedShares(user, 4, 50);

    distributor.claim(address(_pool));
    vm.stopPrank();

    assertEq(sharesToken.balanceOf(user), 50);
  }
}
