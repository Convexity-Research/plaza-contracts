// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";
import {Token} from "./mocks/Token.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Router} from "../src/MockRouter.sol";
import {MockPool} from "./mocks/MockPool.sol";
import {BondToken} from "../src/BondToken.sol";
import {Distributor} from "../src/Distributor.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Validator} from "../src/utils/Validator.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";
import {TokenDeployer} from "../src/utils/TokenDeployer.sol";

contract MockRouterTest is Test {
  PoolFactory private poolFactory;
  Pool private pool;
  Router private mockRouter;

  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private user = address(0x4);
  address private user2 = address(0x5);

  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);
  uint256 private constant CHAINLINK_DECIMAL_PRECISION = 10**8;
  uint8 private constant CHAINLINK_DECIMAL = 8;

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);

    address tokenDeployer = address(new TokenDeployer());
    Distributor distributor = Distributor(Utils.deploy(address(new Distributor()), abi.encodeCall(Distributor.initialize, (governance))));

    address oracleFeeds = address(new OracleFeeds());
    console.log("oracleFeeds", oracleFeeds);
    poolFactory = PoolFactory(Utils.deploy(address(new PoolFactory()), abi.encodeCall(PoolFactory.initialize, (governance,tokenDeployer, address(distributor), oracleFeeds))));

    PoolFactory.PoolParams memory params;
    params.fee = 0;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH", false));
    params.sharesPerToken = 50 * 10 ** 18;
    params.distributionPeriod = 0;
    params.couponToken = address(new Token("USDC", "USDC", false));

    OracleFeeds(oracleFeeds).setPriceFeed(params.reserveToken, address(0), ethPriceFeed);

    // Deploy the mock price feed
    MockPriceFeed mockPriceFeed = new MockPriceFeed();

    // Use vm.etch to deploy the mock contract at the specific address
    bytes memory bytecode = address(mockPriceFeed).code;
    vm.etch(ethPriceFeed, bytecode);

    // Set oracle price
    mockPriceFeed = MockPriceFeed(ethPriceFeed);
    mockPriceFeed.setMockPrice(3000 * int256(CHAINLINK_DECIMAL_PRECISION), uint8(CHAINLINK_DECIMAL));
    
    mockRouter = new Router(oracleFeeds);
    vm.stopPrank();

    vm.startPrank(governance);

    distributor.grantRole(distributor.POOL_FACTORY_ROLE(), address(poolFactory));

    Token rToken = Token(params.reserveToken);

    // Mint reserve tokens
    rToken.mint(governance, 1000000000000000000000000);
    rToken.approve(address(poolFactory), 1000000000000000000000000);

    // Create pool and approve deposit amount
    pool = Pool(poolFactory.CreatePool(params, 1000000000000000000000000, 25000000000000000000000000, 1000000000000000000000000));
    vm.stopPrank();
  }

  function testRouterCreate() public {
    vm.startPrank(governance);

    // Mint and approve USDC
    Token usdc = Token(pool.couponToken());
    usdc.mint(governance, 3000000000000000000000);
    usdc.approve(address(mockRouter), 3000000000000000000000);

    // Call create and assert minted tokens
    uint256 amount = mockRouter.swapCreate(address(pool), pool.couponToken(), Pool.TokenType.BOND, 3000000000000000000000, 0);
    assertEq(amount, 31250000000000000000);
  }

  function testRouterRedeem() public {
    vm.startPrank(governance);

    pool.bondToken().approve(address(mockRouter), 31000000000000000000);

    // Call create and assert minted tokens
    uint256 amount = mockRouter.swapRedeem(address(pool), pool.couponToken(), Pool.TokenType.BOND, 31000000000000000000, 0);
    assertEq(amount, 2976000000000000000000);
  }

  function useMockPool(address poolAddress) public {
    // Deploy the mock pool
    MockPool mockPool = new MockPool();

    // Use vm.etch to deploy the mock contract at the specific address
    vm.etch(poolAddress, address(mockPool).code);
  }

  function setEthPrice(uint256 price) public {
    MockPriceFeed mockPriceFeed = MockPriceFeed(ethPriceFeed);
    mockPriceFeed.setMockPrice(int256(price), uint8(CHAINLINK_DECIMAL));
  }
}

