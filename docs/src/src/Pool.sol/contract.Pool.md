# Pool
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/Pool.sol)

**Inherits:**
Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable, [OracleReader](/src/OracleReader.sol/contract.OracleReader.md), [Validator](/src/utils/Validator.sol/abstract.Validator.md)

*This contract manages a pool of assets, allowing for the creation, redemption, and swapping of bond and leverage tokens.
It also handles distribution periods and interacts with an oracle for price information.*


## State Variables
### POINT_EIGHT

```solidity
uint256 private constant POINT_EIGHT = 800000;
```


### POINT_TWO

```solidity
uint256 private constant POINT_TWO = 200000;
```


### COLLATERAL_THRESHOLD

```solidity
uint256 private constant COLLATERAL_THRESHOLD = 1200000;
```


### PRECISION

```solidity
uint256 private constant PRECISION = 1000000;
```


### BOND_TARGET_PRICE

```solidity
uint256 private constant BOND_TARGET_PRICE = 100;
```


### COMMON_DECIMALS

```solidity
uint8 private constant COMMON_DECIMALS = 18;
```


### poolFactory

```solidity
PoolFactory public poolFactory;
```


### fee

```solidity
uint256 private fee;
```


### reserveToken

```solidity
address public reserveToken;
```


### bondToken

```solidity
BondToken public bondToken;
```


### lToken

```solidity
LeverageToken public lToken;
```


### couponToken

```solidity
address public couponToken;
```


### sharesPerToken

```solidity
uint256 private sharesPerToken;
```


### distributionPeriod

```solidity
uint256 private distributionPeriod;
```


### lastDistribution

```solidity
uint256 private lastDistribution;
```


## Functions
### constructor


```solidity
constructor();
```

### initialize

*Initializes the contract with the given parameters.*


```solidity
function initialize(
    address _poolFactory,
    uint256 _fee,
    address _reserveToken,
    address _dToken,
    address _lToken,
    address _couponToken,
    uint256 _sharesPerToken,
    uint256 _distributionPeriod,
    address _ethPriceFeed
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_poolFactory`|`address`|Address of the pool factory contract.|
|`_fee`|`uint256`|Fee percentage for the pool.|
|`_reserveToken`|`address`|Address of the reserve token.|
|`_dToken`|`address`|Address of the bond token.|
|`_lToken`|`address`|Address of the leverage token.|
|`_couponToken`|`address`|Address of the coupon token.|
|`_sharesPerToken`|`uint256`|Initial shares per bond per distribution period.|
|`_distributionPeriod`|`uint256`|Initial distribution period in seconds.|
|`_ethPriceFeed`|`address`|Address of the ETH price feed.|


### create

*Creates new tokens by depositing reserve tokens.*


```solidity
function create(TokenType tokenType, uint256 depositAmount, uint256 minAmount)
    external
    whenNotPaused
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of token to create (BOND or LEVERAGE).|
|`depositAmount`|`uint256`|The amount of reserve tokens to deposit.|
|`minAmount`|`uint256`|The minimum amount of new tokens to receive.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of new tokens created.|


### create

*Creates new tokens by depositing reserve tokens, with additional parameters for deadline and onBehalfOf for router support.*


```solidity
function create(TokenType tokenType, uint256 depositAmount, uint256 minAmount, uint256 deadline, address onBehalfOf)
    public
    whenNotPaused
    checkDeadline(deadline)
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of token to create (BOND or LEVERAGE).|
|`depositAmount`|`uint256`|The amount of reserve tokens to deposit.|
|`minAmount`|`uint256`|The minimum amount of new tokens to receive.|
|`deadline`|`uint256`|The deadline timestamp in seconds for the transaction to be executed.|
|`onBehalfOf`|`address`|The address to receive the new tokens.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of new tokens created.|


### simulateCreate

*Simulates the creation of new tokens without actually minting them.*


```solidity
function simulateCreate(TokenType tokenType, uint256 depositAmount) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of token to simulate creating (BOND or LEVERAGE).|
|`depositAmount`|`uint256`|The amount of reserve tokens to simulate depositing.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of new tokens that would be created.|


### getCreateAmount

*Calculates the amount of new tokens to create based on the current pool state and oracle price.*


```solidity
function getCreateAmount(
    TokenType tokenType,
    uint256 depositAmount,
    uint256 bondSupply,
    uint256 levSupply,
    uint256 poolReserves,
    uint256 ethPrice,
    uint8 oracleDecimals
) public pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of token to create (BOND or LEVERAGE).|
|`depositAmount`|`uint256`|The amount of reserve tokens to deposit.|
|`bondSupply`|`uint256`|The current supply of bond tokens.|
|`levSupply`|`uint256`|The current supply of leverage tokens.|
|`poolReserves`|`uint256`|The current amount of reserve tokens in the pool.|
|`ethPrice`|`uint256`|The current ETH price from the oracle.|
|`oracleDecimals`|`uint8`|The number of decimals used by the oracle.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of new tokens to create.|


### redeem

*Redeems tokens for reserve tokens.*


```solidity
function redeem(TokenType tokenType, uint256 depositAmount, uint256 minAmount) public whenNotPaused returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of derivative token to redeem (BOND or LEVERAGE).|
|`depositAmount`|`uint256`|The amount of derivative tokens to redeem.|
|`minAmount`|`uint256`|The minimum amount of reserve tokens to receive.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of reserve tokens received.|


### redeem

*Redeems tokens for reserve tokens, with additional parameters.*


```solidity
function redeem(TokenType tokenType, uint256 depositAmount, uint256 minAmount, uint256 deadline, address onBehalfOf)
    public
    whenNotPaused
    checkDeadline(deadline)
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of derivative token to redeem (BOND or LEVERAGE).|
|`depositAmount`|`uint256`|The amount of derivative tokens to redeem.|
|`minAmount`|`uint256`|The minimum amount of reserve tokens to receive.|
|`deadline`|`uint256`|The deadline timestamp in seconds for the transaction to be executed.|
|`onBehalfOf`|`address`|The address to receive the reserve tokens.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of reserve tokens received.|


### simulateRedeem

*Simulates the redemption of tokens without actually burning them.*


```solidity
function simulateRedeem(TokenType tokenType, uint256 depositAmount) public view whenNotPaused returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of derivative token to simulate redeeming (BOND or LEVERAGE).|
|`depositAmount`|`uint256`|The amount of derivative tokens to simulate redeeming.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of reserve tokens that would be received.|


### getRedeemAmount

*Calculates the amount of reserve tokens to be redeemed for a given amount of bond or leverage tokens.*


```solidity
function getRedeemAmount(
    TokenType tokenType,
    uint256 depositAmount,
    uint256 bondSupply,
    uint256 levSupply,
    uint256 poolReserves,
    uint256 ethPrice,
    uint8 oracleDecimals
) public pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of derivative token being redeemed (BOND or LEVERAGE).|
|`depositAmount`|`uint256`|The amount of derivative tokens being redeemed.|
|`bondSupply`|`uint256`|The total supply of bond tokens.|
|`levSupply`|`uint256`|The total supply of leverage tokens.|
|`poolReserves`|`uint256`|The total amount of reserve tokens in the pool.|
|`ethPrice`|`uint256`|The current ETH price from the oracle.|
|`oracleDecimals`|`uint8`|The number of decimals used by the oracle.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of reserve tokens to be redeemed.|


### swap

*Swaps one token type for another (BOND for LEVERAGE or vice versa).*


```solidity
function swap(TokenType tokenType, uint256 depositAmount, uint256 minAmount) public whenNotPaused returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of derivative token being swapped.|
|`depositAmount`|`uint256`|The amount of derivative tokens to swap.|
|`minAmount`|`uint256`|The minimum amount of derivative tokens to receive in return.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of derivative tokens received in the swap.|


### swap

*Swaps one token type for another with additional parameters.*


```solidity
function swap(TokenType tokenType, uint256 depositAmount, uint256 minAmount, uint256 deadline, address onBehalfOf)
    public
    whenNotPaused
    checkDeadline(deadline)
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of derivative token being swapped.|
|`depositAmount`|`uint256`|The amount of derivative tokens to swap.|
|`minAmount`|`uint256`|The minimum amount of derivative tokens to receive in return.|
|`deadline`|`uint256`|The deadline timestamp in seconds for the transaction to be executed.|
|`onBehalfOf`|`address`|The address to receive the swapped derivative tokens.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of derivative tokens received in the swap.|


### simulateSwap

*Simulates a swap without actually executing it.*


```solidity
function simulateSwap(TokenType tokenType, uint256 depositAmount) public view whenNotPaused returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenType`|`TokenType`|The type of derivative token being swapped.|
|`depositAmount`|`uint256`|The amount of derivative tokens to simulate swapping.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of derivative tokens that would be received in the swap.|


### distribute

*Distributes coupon tokens to bond token holders.
Can only be called after the distribution period has passed.*


```solidity
function distribute() external whenNotPaused;
```

### getPoolInfo

*Returns the current pool information.*


```solidity
function getPoolInfo() external view returns (PoolInfo memory info);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`info`|`PoolInfo`|A struct containing various pool parameters and balances.|


### setDistributionPeriod

*Sets the distribution period.*


```solidity
function setDistributionPeriod(uint256 _distributionPeriod) external onlyRole(poolFactory.GOV_ROLE());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_distributionPeriod`|`uint256`|The new distribution period.|


### setSharesPerToken

*Sets the shares per token.*


```solidity
function setSharesPerToken(uint256 _sharesPerToken) external onlyRole(poolFactory.GOV_ROLE());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sharesPerToken`|`uint256`|The new shares per token value.|


### setFee

*Sets the fee for the pool.*


```solidity
function setFee(uint256 _fee) external whenNotPaused onlyRole(poolFactory.GOV_ROLE());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_fee`|`uint256`|The new fee value.|


### pause

*Pauses the contract. Reverts any interaction except upgrade.*


```solidity
function pause() external onlyRole(poolFactory.GOV_ROLE());
```

### unpause

*Unpauses the contract.*


```solidity
function unpause() external onlyRole(poolFactory.GOV_ROLE());
```

### recovery

This function should be removed before production deployment.

*Recovers any ERC20 tokens or native tokens sent to this contract.*


```solidity
function recovery(address token) external onlyRole(poolFactory.GOV_ROLE());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the ERC20 token to recover.|


### onlyRole

*Modifier to check if the caller has the specified role.*


```solidity
modifier onlyRole(bytes32 role);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to check for.|


### _authorizeUpgrade

*Authorizes an upgrade to a new implementation.
Can only be called by the owner of the contract.*


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The address of the new implementation.|


## Events
### TokensCreated

```solidity
event TokensCreated(
    address caller, address onBehalfOf, TokenType tokenType, uint256 depositedAmount, uint256 mintedAmount
);
```

### TokensRedeemed

```solidity
event TokensRedeemed(
    address caller, address onBehalfOf, TokenType tokenType, uint256 depositedAmount, uint256 redeemedAmount
);
```

### TokensSwapped

```solidity
event TokensSwapped(
    address caller, address onBehalfOf, TokenType tokenType, uint256 depositedAmount, uint256 redeemedAmount
);
```

### DistributionPeriodChanged

```solidity
event DistributionPeriodChanged(uint256 oldPeriod, uint256 newPeriod);
```

### SharesPerTokenChanged

```solidity
event SharesPerTokenChanged(uint256 sharesPerToken);
```

### Distributed

```solidity
event Distributed(uint256 amount);
```

## Errors
### MinAmount

```solidity
error MinAmount();
```

### ZeroAmount

```solidity
error ZeroAmount();
```

### AccessDenied

```solidity
error AccessDenied();
```

### ZeroDebtSupply

```solidity
error ZeroDebtSupply();
```

### ZeroLeverageSupply

```solidity
error ZeroLeverageSupply();
```

### DistributionPeriod

```solidity
error DistributionPeriod();
```

## Structs
### PoolInfo
*Struct containing information about the pool's current state.*


```solidity
struct PoolInfo {
    uint256 fee;
    uint256 reserve;
    uint256 bondSupply;
    uint256 levSupply;
    uint256 sharesPerToken;
    uint256 currentPeriod;
    uint256 lastDistribution;
    uint256 distributionPeriod;
}
```

## Enums
### TokenType
*Enum representing the types of tokens that can be created or redeemed.*


```solidity
enum TokenType {
    BOND,
    LEVERAGE
}
```

