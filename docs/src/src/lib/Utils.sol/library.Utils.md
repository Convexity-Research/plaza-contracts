# Utils
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/lib/Utils.sol)

*Library containing utility functions for contract deployment*


## Functions
### deploy

*Deploys a new upgradeable proxy contract*


```solidity
function deploy(address implementation, bytes memory initialize) internal returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|The address of the implementation contract|
|`initialize`|`bytes`|The initialization data for the proxy contract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The address of the newly deployed proxy contract|


