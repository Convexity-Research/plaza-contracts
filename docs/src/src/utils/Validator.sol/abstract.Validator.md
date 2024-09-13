# Validator
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/utils/Validator.sol)

**Inherits:**
[BlockTimestamp](/src/utils/BlockTimestamp.sol/abstract.BlockTimestamp.md)

*Abstract contract that provides a modifier to check transaction deadlines.*


## Functions
### checkDeadline

This modifier will revert the transaction if the current block timestamp is after the deadline.

*Modifier to check if the current block timestamp is before or equal to the given deadline.*


```solidity
modifier checkDeadline(uint256 deadline);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deadline`|`uint256`|The timestamp by which the transaction must be executed.|


## Errors
### TransactionTooOld
*Custom error to be thrown when a transaction is submitted after its deadline.*


```solidity
error TransactionTooOld();
```

