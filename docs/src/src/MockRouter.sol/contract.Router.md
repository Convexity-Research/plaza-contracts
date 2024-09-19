# Router
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/MockRouter.sol)

**Inherits:**
[OracleReader](/src/OracleReader.sol/contract.OracleReader.md)

*Testnet contract that replaces the real Router contract on testnet.*

********This contract is out of the scope of an audit.********


## Functions
### constructor

*Constructor that initializes the OracleReader with the ETH price feed.*


```solidity
constructor(address _ethPriceFeed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_ethPriceFeed`|`address`|The address of the ETH price feed.|


### swapCreate

*Swaps and creates tokens in a pool.*


```solidity
function swapCreate(
    address _pool,
    address depositToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount
) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pool`|`address`|The address of the pool.|
|`depositToken`|`address`|The address of the token to deposit.|
|`tokenType`|`Pool.TokenType`|The type of token to create (LEVERAGE or BOND).|
|`depositAmount`|`uint256`|The amount of tokens to deposit.|
|`minAmount`|`uint256`|The minimum amount of tokens to receive.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of tokens created.|


### swapCreate

*Swaps and creates tokens in a pool with additional parameters.*


```solidity
function swapCreate(
    address _pool,
    address depositToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf
) public returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pool`|`address`|The address of the pool.|
|`depositToken`|`address`|The address of the token to deposit.|
|`tokenType`|`Pool.TokenType`|The type of token to create (LEVERAGE or BOND).|
|`depositAmount`|`uint256`|The amount of tokens to deposit.|
|`minAmount`|`uint256`|The minimum amount of tokens to receive.|
|`deadline`|`uint256`|The deadline timestamp in seconds for the transaction.|
|`onBehalfOf`|`address`|The address to receive the created tokens.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of tokens created.|


### swapRedeem

*Swaps and redeems tokens from a pool.*


```solidity
function swapRedeem(
    address _pool,
    address redeemToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount
) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pool`|`address`|The address of the pool.|
|`redeemToken`|`address`|The address of the token to redeem.|
|`tokenType`|`Pool.TokenType`|The type of token to redeem (LEVERAGE or BOND).|
|`depositAmount`|`uint256`|The amount of tokens to deposit.|
|`minAmount`|`uint256`|The minimum amount of tokens to receive.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of tokens redeemed.|


### swapRedeem

*Swaps and redeems tokens from a pool with additional parameters.*


```solidity
function swapRedeem(
    address _pool,
    address redeemToken,
    Pool.TokenType tokenType,
    uint256 depositAmount,
    uint256 minAmount,
    uint256 deadline,
    address onBehalfOf
) public returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pool`|`address`|The address of the pool.|
|`redeemToken`|`address`|The address of the token to redeem.|
|`tokenType`|`Pool.TokenType`|The type of token to redeem (LEVERAGE or BOND).|
|`depositAmount`|`uint256`|The amount of tokens to deposit.|
|`minAmount`|`uint256`|The minimum amount of tokens to receive.|
|`deadline`|`uint256`|The deadline for the transaction.|
|`onBehalfOf`|`address`|The address to receive the redeemed tokens.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of tokens redeemed.|


## Errors
### MinAmount
*Error thrown when the minimum amount condition is not met.*


```solidity
error MinAmount();
```

