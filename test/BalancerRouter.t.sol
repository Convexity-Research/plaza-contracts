// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {BalancerRouter} from "../src/BalancerRouter.sol";
import {PreDeposit} from "../src/PreDeposit.sol";
import {IAsset} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {Token} from "./mocks/Token.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BondToken} from "../src/BondToken.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {Distributor} from "../src/Distributor.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract MockBalancerVault {    
  Token public balancerPoolToken;
  mapping(address => uint256) public joinAmounts;

  struct JoinPoolRequest {
    IAsset[] assets;
    uint256[] maxAmountsIn;
    bytes userData;
    bool fromInternalBalance;
  }

  struct ExitPoolRequest {
    IAsset[] assets;
    uint256[] minAmountsOut;
    bytes userData;
    bool toInternalBalance;
  }

  constructor(Token _balancerPoolToken) {
    balancerPoolToken = _balancerPoolToken;
  }

  function joinPool(
    bytes32 /*poolId*/,
    address sender,
    address recipient,
    JoinPoolRequest memory request
  ) external {
    for (uint256 i = 0; i < request.assets.length; i++) {
      if (address(request.assets[i]) != address(0)) {
        Token(address(request.assets[i])).transferFrom(
          sender,
          address(this),
          request.maxAmountsIn[i]
        );
        joinAmounts[address(request.assets[i])] = request.maxAmountsIn[i];
      }
    }
    balancerPoolToken.mint(recipient, 1 ether);
  }

  function exitPool(
    bytes32 /*poolId*/,
    address sender,
    address payable recipient,
    ExitPoolRequest memory request
  ) external {
    balancerPoolToken.burn(sender, request.minAmountsOut[0]);
    for (uint256 i = 0; i < request.assets.length; i++) {
      if (address(request.assets[i]) != address(0)) {
        Token(address(request.assets[i])).transfer(
          recipient,
          joinAmounts[address(request.assets[i])]
        );
      }
    }
  }
}

contract BalancerRouterTest is Test {
  BalancerRouter public router;
  MockBalancerVault public vault;
  Pool public _pool;
  PreDeposit public predeposit;
  Token public balancerPoolToken;
  Token public asset1;
  Token public asset2;
  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);
  PoolFactory.PoolParams private params;
  PoolFactory public poolFactory;
  Distributor public distributor;
  MockPriceFeed public mockPriceFeed;

  address public user = address(0x1);
  address public governance = address(0x2);
  address private deployer = address(0x3);
  address private minter = address(0x4);

  uint256 private constant CHAINLINK_DECIMAL_PRECISION = 10**8;
  uint8 private constant CHAINLINK_DECIMAL = 8;


  bytes32 public constant BALANCER_POOL_ID = bytes32(uint256(1));

  function setUp() public {

    vm.startPrank(deployer);

    // Deploy mock tokens
    balancerPoolToken = new Token("Balancer Pool Token", "balancerPoolToken", false);
    asset1 = new Token("Test Token 1", "TT1", true);
    asset2 = new Token("Test Token 2", "TT2", true);
    address contractDeployer = address(new Deployer());
    address oracleFeeds = address(new OracleFeeds());

    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));

    poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(
      PoolFactory.initialize, 
      (governance, contractDeployer, oracleFeeds, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
    )));

    params.fee = 0;
    params.reserveToken = address(balancerPoolToken);
    params.sharesPerToken = 50 * 10 ** 18;
    params.distributionPeriod = 0;
    params.couponToken = address(new Token("USDC", "USDC", false));

    OracleFeeds(oracleFeeds).setPriceFeed(params.reserveToken, address(0), ethPriceFeed, 1 days);

    // Deploy the mock price feed
    mockPriceFeed = new MockPriceFeed();

    // Use vm.etch to deploy the mock contract at the specific address
    bytes memory bytecode = address(mockPriceFeed).code;
    vm.etch(ethPriceFeed, bytecode);

    // Set oracle price
    mockPriceFeed = MockPriceFeed(ethPriceFeed);
    mockPriceFeed.setMockPrice(3000 * int256(CHAINLINK_DECIMAL_PRECISION), uint8(CHAINLINK_DECIMAL));

    balancerPoolToken.mint(governance, 100 ether);
    vm.stopPrank();

    vm.startPrank(governance);
    poolFactory.grantRole(poolFactory.POOL_ROLE(), governance);

    balancerPoolToken.approve(address(poolFactory), 100 ether);
    _pool = Pool(poolFactory.createPool(params, 100 ether, 10000*10**18, 10000*10**18, "", "", "", "", false));
    vm.stopPrank();

    vm.startPrank(deployer);

    // Deploy mock contracts
    vault = new MockBalancerVault(balancerPoolToken);
    predeposit = PreDeposit(Utils.deploy(address(new PreDeposit()), abi.encodeCall(
      PreDeposit.initialize, 
      (params, address(poolFactory), block.timestamp, block.timestamp + 1 hours, 100000 ether, "Bond ETH", "bondETH", "Leveraged ETH", "levETH")
    )));
    router = new BalancerRouter(address(vault), address(balancerPoolToken));

    // Setup initial token balances
    asset1.mint(user, 1000 ether);
    asset2.mint(user, 1000 ether);

    vm.stopPrank();
  }

  function testJoinBalancerAndPredeposit() public {
    vm.startPrank(user);

    IAsset[] memory assets = new IAsset[](2);
    assets[0] = IAsset(address(asset1));
    assets[1] = IAsset(address(asset2));

    uint256[] memory maxAmountsIn = new uint256[](2);
    maxAmountsIn[0] = 1 ether;
    maxAmountsIn[1] = 1 ether;

    asset1.approve(address(router), 1 ether);
    asset2.approve(address(router), 1 ether);

    uint256 balancerPoolTokenReceived = router.joinBalancerAndPredeposit(
      BALANCER_POOL_ID,
      address(predeposit),
      assets,
      maxAmountsIn,
      ""
    );

    assertEq(balancerPoolTokenReceived, 1 ether, "Incorrect balancerPoolToken amount received");
    assertEq(asset1.balanceOf(user), 999 ether, "Incorrect asset1 balance");
    assertEq(asset2.balanceOf(user), 999 ether, "Incorrect asset2 balance");

    vm.stopPrank();
  }

  function testJoinBalancerAndPlaza() public {
    vm.startPrank(user);

    IAsset[] memory assets = new IAsset[](2);
    assets[0] = IAsset(address(asset1));
    assets[1] = IAsset(address(asset2));

    uint256[] memory maxAmountsIn = new uint256[](2);
    maxAmountsIn[0] = 1 ether;
    maxAmountsIn[1] = 1 ether;

    asset1.approve(address(router), 1 ether);
    asset2.approve(address(router), 1 ether);

    uint256 plazaTokens = router.joinBalancerAndPlaza(
      BALANCER_POOL_ID,
      address(_pool),
      assets,
      maxAmountsIn,
      "",
      Pool.TokenType.BOND,
      0.9 ether,
      block.timestamp + 1 hours
    );

    assertEq(plazaTokens, 125000000000000000000, "Incorrect Plaza tokens received");
    assertEq(asset1.balanceOf(user), 999 ether, "Incorrect asset1 balance");
    assertEq(asset2.balanceOf(user), 999 ether, "Incorrect asset2 balance");

    vm.stopPrank();
  }

  function testExitPlazaAndBalancer() public {
    // First join Balancer and Plaza to get some Plaza tokens
    vm.startPrank(user);

    IAsset[] memory assets = new IAsset[](2);
    assets[0] = IAsset(address(asset1));
    assets[1] = IAsset(address(asset2));

    uint256[] memory maxAmountsIn = new uint256[](2);
    maxAmountsIn[0] = 1 ether;
    maxAmountsIn[1] = 1 ether;

    asset1.approve(address(router), 1 ether);
    asset2.approve(address(router), 1 ether);

    // Join first to get Plaza tokens
    uint256 plazaTokens = router.joinBalancerAndPlaza(
      BALANCER_POOL_ID,
      address(_pool),
      assets,
      maxAmountsIn,
      "",
      Pool.TokenType.BOND,
      0.9 ether,
      block.timestamp + 1 hours
    );

    // Record balances before exit
    uint256 asset1BalanceBefore = asset1.balanceOf(user);
    uint256 asset2BalanceBefore = asset2.balanceOf(user);
    uint256 bondTokenBalanceBefore = _pool.bondToken().balanceOf(user);

    // Approve Plaza tokens for router
    _pool.bondToken().approve(address(router), plazaTokens);

    // Prepare exit parameters
    uint256[] memory minAmountsOut = new uint256[](2);
    minAmountsOut[0] = 0.9 ether;
    minAmountsOut[1] = 0.9 ether;

    // Exit Plaza and Balancer
    router.exitPlazaAndBalancer(
      BALANCER_POOL_ID,
      address(_pool),
      assets,
      plazaTokens,
      minAmountsOut,
      "",
      Pool.TokenType.BOND,
      0.9 ether
    );

    // Verify balances after exit
    assertEq(
      asset1.balanceOf(user), 
      asset1BalanceBefore + 1 ether, 
      "Incorrect asset1 balance after exit"
    );
    assertEq(
      asset2.balanceOf(user), 
      asset2BalanceBefore + 1 ether, 
      "Incorrect asset2 balance after exit"
    );
    assertEq(
      _pool.bondToken().balanceOf(user), 
      bondTokenBalanceBefore - plazaTokens, 
      "Incorrect bond token balance after exit"
    );

    vm.stopPrank();
  }


  function testFailJoinWithInsufficientAllowance() public {
    vm.startPrank(user);

    IAsset[] memory assets = new IAsset[](2);
    assets[0] = IAsset(address(asset1));
    assets[1] = IAsset(address(asset2));

    uint256[] memory maxAmountsIn = new uint256[](2);
    maxAmountsIn[0] = 1 ether;
    maxAmountsIn[1] = 1 ether;

    // Don't approve tokens
    router.joinBalancerAndPredeposit(
      BALANCER_POOL_ID,
      address(predeposit),
      assets,
      maxAmountsIn,
      ""
    );

    vm.stopPrank();
  }

  function testFailJoinWithInsufficientBalance() public {
    vm.startPrank(user);

    IAsset[] memory assets = new IAsset[](2);
    assets[0] = IAsset(address(asset1));
    assets[1] = IAsset(address(asset2));

    uint256[] memory maxAmountsIn = new uint256[](2);
    maxAmountsIn[0] = 1001 ether; // More than user's balance
    maxAmountsIn[1] = 1 ether;

    asset1.approve(address(router), 1001 ether);
    asset2.approve(address(router), 1 ether);

    router.joinBalancerAndPredeposit(
      BALANCER_POOL_ID,
      address(predeposit),
      assets,
      maxAmountsIn,
      ""
    );

    vm.stopPrank();
  }
}
