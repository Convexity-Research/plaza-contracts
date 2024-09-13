# OracleReader
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/OracleReader.sol)

*Contract for reading price data from Chainlink oracles*


## State Variables
### ethPriceFeed

```solidity
address private ethPriceFeed;
```


## Functions
### __OracleReader_init

*Initializes the contract with the ETH price feed address*


```solidity
function __OracleReader_init(address _ethPriceFeed) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_ethPriceFeed`|`address`|Address of the ETH price feed oracle|


### getOraclePrice

*Retrieves the latest price from the oracle*

*Reverts if the price data is older than 1 day*


```solidity
function getOraclePrice(address) public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price from the oracle|


### getOracleDecimals

*Retrieves the number of decimals used in the oracle's price data*


```solidity
function getOracleDecimals(address) public view returns (uint8 decimals);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`decimals`|`uint8`|Number of decimals used in the price data|


## Errors
### NoPriceFound
*Error thrown when no valid price is found*


```solidity
error NoPriceFound();
```

