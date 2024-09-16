# Faucet
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/Faucet.sol)

A contract for distributing test tokens

*This contract creates and distributes two types of ERC20 tokens for testing purposes*


## State Variables
### reserveToken
The reserve token (WETH)


```solidity
Token public reserveToken;
```


### couponToken
The coupon token (USDC)


```solidity
Token public couponToken;
```


## Functions
### constructor

Initializes the contract by creating new instances of reserve and coupon tokens


```solidity
constructor();
```

### faucet

Distributes a fixed amount of both reserve and coupon tokens to the caller

*Mints 1 WETH and 5000 USDC to the caller's address*


```solidity
function faucet() public;
```

### faucet

Distributes a specified amount of both reserve and coupon tokens to the caller


```solidity
function faucet(uint256 amountReserve, uint256 amountCoupon) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountReserve`|`uint256`|The amount of reserve tokens to mint|
|`amountCoupon`|`uint256`|The amount of coupon tokens to mint|


### faucetReserve

Distributes a specified amount of reserve tokens to the caller


```solidity
function faucetReserve(uint256 amount) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of reserve tokens to mint|


### faucetCoupon

Distributes a specified amount of coupon tokens to the caller


```solidity
function faucetCoupon(uint256 amount) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of coupon tokens to mint|


