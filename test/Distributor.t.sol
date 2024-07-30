// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Token} from "./mocks/Token.sol";
import {BondToken} from "../src/BondToken.sol";
import {Distributor} from "../src/Distributor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DistributorTest is Test {
  Distributor public distributor;
  Distributor.Pool public pool;
  address public poolAddress = address(0x100);

  ERC1967Proxy private proxy;

  address public user = address(0x1);
  address public sharesTokenOwner = address(0x2);
  address private deployer = address(0x3);
  address private minter = address(0x4);
  address private governance = address(0x5);

  function setUp() public {
    vm.startPrank(deployer);
    
    // Distributor deploy
    Distributor distImpl = new Distributor();
    proxy = new ERC1967Proxy(address(distImpl), abi.encodeCall(distImpl.initialize, (governance)));
    distributor = Distributor(address(proxy));

    // Bond token deploy
    BondToken bondImpl = new BondToken();
    proxy = new ERC1967Proxy(address(bondImpl), abi.encodeCall(bondImpl.initialize, ("BondToken", "BOND", minter, governance, address(distributor))));
    pool.bondToken = BondToken(address(proxy));

    // Shares token deploy
    pool.sharesToken = address(new Token("Circle USD", "USDC"));
    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);
    distributor.updatePool(poolAddress, address(pool.bondToken), pool.sharesToken);

    // Set period to 1
    pool.bondToken.increaseIndexedAssetPeriod(200);
  }

  function testUpdatePoolAsGovernance() public {
    address _pool = address(0x101);

    vm.startPrank(governance);
    distributor.updatePool(_pool, address(0x111), address(0x222));
    vm.stopPrank();

    (BondToken bondToken, address sharesToken) = distributor.pools(_pool);

    assertEq(address(bondToken), address(0x111));
    assertEq(sharesToken, address(0x222));
  }

  function testUpdatePoolAsNonGovernance() public {
    vm.startPrank(user);
    vm.expectRevert();
    distributor.updatePool(address(0x101), address(0x111), address(0x222));
    vm.stopPrank();
  }

  function testClaimShares() public {
    Token sharesToken = Token(pool.sharesToken);
    
    vm.startPrank(minter);
    pool.bondToken.mint(user, 10000);
    sharesToken.mint(address(distributor), 1000);
    vm.stopPrank();

    (uint256 lastUpdatedPeriod, uint256 shares) = pool.bondToken.userAssets(user);

    vm.startPrank(governance);
    pool.bondToken.increaseIndexedAssetPeriod(200);
    vm.stopPrank();

    vm.startPrank(user);

    // @todo: figure out why it doesn't match
    // vm.expectEmit(true, true, true, true);
    // emit Distributor.ClaimedShares(user, 1, 200);

    pool.bondToken.transfer(address(0x24), 1);

    (lastUpdatedPeriod, shares) = pool.bondToken.userAssets(user);

    distributor.claim(poolAddress);
    assertEq(sharesToken.balanceOf(user), 200);
    vm.stopPrank();
  }

  function testClaimInsufficientSharesBalance() public {
    vm.startPrank(minter);
    pool.bondToken.mint(user, 1000);
    vm.stopPrank();

    vm.startPrank(governance);
    pool.bondToken.increaseIndexedAssetPeriod(200);
    vm.stopPrank();

    vm.startPrank(user);
    vm.expectRevert(Distributor.NotEnoughSharesBalance.selector);
    distributor.claim(poolAddress);
    vm.stopPrank();
  }

  function testClaimNonExistentPool() public {
    vm.startPrank(user);
    vm.expectRevert(Distributor.UnsupportedPool.selector);
    distributor.claim(address(0));
    vm.stopPrank();
  }

  function testClaimAfterMultiplePeriods() public {
    Token sharesToken = Token(pool.sharesToken);

    vm.startPrank(minter);
    pool.bondToken.mint(user, 1000);
    sharesToken.mint(address(distributor), 50);
    vm.stopPrank();

    vm.startPrank(governance);
    pool.bondToken.increaseIndexedAssetPeriod(100);
    pool.bondToken.increaseIndexedAssetPeriod(200);
    pool.bondToken.increaseIndexedAssetPeriod(300);
    vm.stopPrank();

    vm.startPrank(user);
    // vm.expectEmit(true, true, true, true);
    // emit distributor.ClaimedShares(user, 4, 50);

    distributor.claim(poolAddress);
    vm.stopPrank();

    assertEq(sharesToken.balanceOf(user), 50);
  }
}
