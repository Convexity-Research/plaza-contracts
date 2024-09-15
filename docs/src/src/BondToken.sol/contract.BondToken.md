# BondToken
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/BondToken.sol)

**Inherits:**
Initializable, ERC20Upgradeable, AccessControlUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, PausableUpgradeable

*This contract implements a bond token with upgradeable capabilities, access control, and pausability.
It includes functionality for managing indexed user assets and global asset pools.*


## State Variables
### globalPool
*The global asset pool*


```solidity
IndexedGlobalAssetPool public globalPool;
```


### userAssets
*Mapping of user addresses to their indexed assets*


```solidity
mapping(address => IndexedUserAssets) public userAssets;
```


### MINTER_ROLE
*Role identifier for accounts with minting privileges*


```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
```


### GOV_ROLE
*Role identifier for accounts with governance privileges*


```solidity
bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
```


### DISTRIBUTOR_ROLE
*Role identifier for the distributor*


```solidity
bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
```


### SHARES_DECIMALS
*The number of decimals for shares*


```solidity
uint8 public constant SHARES_DECIMALS = 6;
```


## Functions
### constructor


```solidity
constructor();
```

### initialize

*Initializes the contract with a name, symbol, minter, governance address, distributor, and initial shares per token.*


```solidity
function initialize(
    string memory name,
    string memory symbol,
    address minter,
    address governance,
    address distributor,
    uint256 sharesPerToken
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|The name of the token|
|`symbol`|`string`|The symbol of the token|
|`minter`|`address`|The address that will have minting privileges|
|`governance`|`address`|The address that will have governance privileges|
|`distributor`|`address`|The address that will have distributor privileges|
|`sharesPerToken`|`uint256`|The initial number of shares per token|


### mint

Can only be called by addresses with the MINTER_ROLE.

*Mints new tokens to the specified address.*


```solidity
function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address that will receive the minted tokens|
|`amount`|`uint256`|The amount of tokens to mint|


### burn

Can only be called by addresses with the MINTER_ROLE.

*Burns tokens from the specified account.*


```solidity
function burn(address account, uint256 amount) public onlyRole(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account from which tokens will be burned|
|`amount`|`uint256`|The amount of tokens to burn|


### getPreviousPoolAmounts

*Returns the previous pool amounts from the global pool.*


```solidity
function getPreviousPoolAmounts() external view returns (PoolAmount[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`PoolAmount[]`|An array of PoolAmount structs representing the previous pool amounts|


### _update

This function is called during token transfer and is paused when the contract is paused.

*Internal function to update user assets after a transfer.*


```solidity
function _update(address from, address to, uint256 amount) internal virtual override whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address tokens are transferred from|
|`to`|`address`|The address tokens are transferred to|
|`amount`|`uint256`|The amount of tokens transferred|


### updateIndexedUserAssets

This function updates the number of shares held by the user based on the current period.

*Updates the indexed user assets for a specific user.*


```solidity
function updateIndexedUserAssets(address user, uint256 balance) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`balance`|`uint256`|The current balance of the user|


### getIndexedUserAmount

This function calculates the number of shares based on the current period and the previous pool amounts.

*Returns the indexed amount of shares for a specific user.*


```solidity
function getIndexedUserAmount(address user, uint256 balance, uint256 period) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`balance`|`uint256`|The current balance of the user|
|`period`|`uint256`|The period to calculate the shares for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The indexed amount of shares for the user|


### resetIndexedUserAssets

This function resets the last updated period and indexed amount of shares to zero.
Can only be called by addresses with the DISTRIBUTOR_ROLE and when the contract is not paused.

*Resets the indexed user assets for a specific user.*


```solidity
function resetIndexedUserAssets(address user) external onlyRole(DISTRIBUTOR_ROLE) whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|


### increaseIndexedAssetPeriod

Can only be called by addresses with the GOV_ROLE and when the contract is not paused.

*Increases the current period and updates the shares per token.*


```solidity
function increaseIndexedAssetPeriod(uint256 sharesPerToken) public onlyRole(GOV_ROLE) whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sharesPerToken`|`uint256`|The new number of shares per token|


### grantRole

Can only be called by addresses with the GOV_ROLE.

*Grants a role to an account.*


```solidity
function grantRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to grant|
|`account`|`address`|The account to grant the role to|


### revokeRole

Can only be called by addresses with the GOV_ROLE.

*Revokes a role from an account.*


```solidity
function revokeRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to revoke|
|`account`|`address`|The account to revoke the role from|


### pause

Can only be called by addresses with the GOV_ROLE.

*Pauses all contract functions except for upgrades.*


```solidity
function pause() external onlyRole(GOV_ROLE);
```

### unpause

Can only be called by addresses with the GOV_ROLE.

*Unpauses all contract functions.*


```solidity
function unpause() external onlyRole(GOV_ROLE);
```

### _authorizeUpgrade

Can only be called by addresses with the GOV_ROLE.

*Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
{upgradeTo} and {upgradeToAndCall}.*


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(GOV_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation contract|


## Events
### IncreasedAssetPeriod
*Emitted when the asset period is increased*


```solidity
event IncreasedAssetPeriod(uint256 currentPeriod, uint256 sharesPerToken);
```

### UpdatedUserAssets
*Emitted when a user's assets are updated*


```solidity
event UpdatedUserAssets(address user, uint256 lastUpdatedPeriod, uint256 indexedAmountShares);
```

## Structs
### PoolAmount
*Struct to represent a pool's outstanding shares and shares per bond at a specific period*


```solidity
struct PoolAmount {
    uint256 period;
    uint256 amount;
    uint256 sharesPerToken;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`period`|`uint256`|The period of the pool amount|
|`amount`|`uint256`|The total amount in the pool|
|`sharesPerToken`|`uint256`|The number of shares per token (base 10000)|

### IndexedGlobalAssetPool
*Struct to represent the global asset pool, including the current period, shares per token, and previous pool amounts.*


```solidity
struct IndexedGlobalAssetPool {
    uint256 currentPeriod;
    uint256 sharesPerToken;
    PoolAmount[] previousPoolAmounts;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`currentPeriod`|`uint256`|The current period of the global pool|
|`sharesPerToken`|`uint256`|The current number of shares per token (base 10000)|
|`previousPoolAmounts`|`PoolAmount[]`|An array of previous pool amounts|

### IndexedUserAssets
*Struct to represent a user's indexed assets, which are the user's shares*


```solidity
struct IndexedUserAssets {
    uint256 lastUpdatedPeriod;
    uint256 indexedAmountShares;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`lastUpdatedPeriod`|`uint256`|The last period when the user's assets were updated|
|`indexedAmountShares`|`uint256`|The user's indexed amount of shares|

