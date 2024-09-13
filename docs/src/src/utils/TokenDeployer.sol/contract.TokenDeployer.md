# TokenDeployer
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/utils/TokenDeployer.sol)

*Contract for deploying BondToken and LeverageToken instances*


## Functions
### deployDebtToken

*Deploys a new BondToken contract*


```solidity
function deployDebtToken(
    string memory,
    string memory,
    address minter,
    address governance,
    address distributor,
    uint256 sharesPerToken
) external returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`||
|`<none>`|`string`||
|`minter`|`address`|The address with minting privileges|
|`governance`|`address`|The address with governance privileges|
|`distributor`|`address`|The address with distributor privileges|
|`sharesPerToken`|`uint256`|The initial number of shares per token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address of the deployed BondToken contract|


### deployLeverageToken

*Deploys a new LeverageToken contract*


```solidity
function deployLeverageToken(string memory, string memory, address minter, address governance)
    external
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`||
|`<none>`|`string`||
|`minter`|`address`|The address with minting privileges|
|`governance`|`address`|The address with governance privileges|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address of the deployed LeverageToken contract|


