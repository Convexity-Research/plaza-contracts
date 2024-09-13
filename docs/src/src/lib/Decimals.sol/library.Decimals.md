# Decimals
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/lib/Decimals.sol)


## Functions
### toBaseUnit

*Converts a token amount to its base unit representation.*


```solidity
function toBaseUnit(uint256 amount, uint8 decimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The token amount.|
|`decimals`|`uint8`|The number of decimals the token uses.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The base unit representation of the token amount.|


### fromBaseUnit

*Converts a base unit representation to a token amount.*


```solidity
function fromBaseUnit(uint256 baseUnitAmount, uint8 decimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseUnitAmount`|`uint256`|The base unit representation of the token amount.|
|`decimals`|`uint8`|The number of decimals the token uses.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The token amount.|


### normalizeAmount

*Normalizes a token amount to a common decimal base.*


```solidity
function normalizeAmount(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The token amount.|
|`fromDecimals`|`uint8`|The number of decimals the token uses.|
|`toDecimals`|`uint8`|The target number of decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The normalized token amount.|


### normalizeTokenAmount

*Normalizes a token amount to a specified decimal base.*


```solidity
function normalizeTokenAmount(uint256 amount, address token, uint8 toDecimals) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The token amount to normalize.|
|`token`|`address`|The ERC20 token.|
|`toDecimals`|`uint8`|The target number of decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The normalized token amount.|


### addAmounts

*Adds two token amounts with different decimals.*


```solidity
function addAmounts(uint256 amount1, uint8 decimals1, uint256 amount2, uint8 decimals2, uint8 resultDecimals)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount1`|`uint256`|The first token amount.|
|`decimals1`|`uint8`|The number of decimals for the first token.|
|`amount2`|`uint256`|The second token amount.|
|`decimals2`|`uint8`|The number of decimals for the second token.|
|`resultDecimals`|`uint8`|The number of decimals for the result.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The sum of the two token amounts normalized to the result decimals.|


### subtractAmounts

*Subtracts two token amounts with different decimals.*


```solidity
function subtractAmounts(uint256 amount1, uint8 decimals1, uint256 amount2, uint8 decimals2, uint8 resultDecimals)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount1`|`uint256`|The first token amount.|
|`decimals1`|`uint8`|The number of decimals for the first token.|
|`amount2`|`uint256`|The second token amount.|
|`decimals2`|`uint8`|The number of decimals for the second token.|
|`resultDecimals`|`uint8`|The number of decimals for the result.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The difference of the two token amounts normalized to the result decimals.|


