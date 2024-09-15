# Distributor
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/Distributor.sol)

**Inherits:**
Initializable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable

*This contract manages the distribution of coupon shares to users based on their bond token balances.*


## State Variables
### GOV_ROLE
*Role identifier for accounts with governance privileges*


```solidity
bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
```


### POOL_FACTORY_ROLE
*Role identifier for the pool factory*


```solidity
bytes32 public constant POOL_FACTORY_ROLE = keccak256("POOL_FACTORY_ROLE");
```


### poolInfos
*Mapping of pool addresses to their respective PoolInfo*


```solidity
mapping(address => PoolInfo) public poolInfos;
```


### couponAmountsToDistribute
*Mapping of coupon token addresses to their total amount to be distributed*


```solidity
mapping(address => uint256) public couponAmountsToDistribute;
```


## Functions
### constructor


```solidity
constructor();
```

### initialize

*Initializes the contract with the governance address and sets up roles.
This function is called once during deployment or upgrading to initialize state variables.*


```solidity
function initialize(address _governance) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_governance`|`address`|Address of the governance account that will have the GOV_ROLE.|


### registerPool

*Allows the pool factory to register a pool in the distributor.*


```solidity
function registerPool(address _pool, address _couponToken) external onlyRole(POOL_FACTORY_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pool`|`address`|Address of the pool to be registered|
|`_couponToken`|`address`|Address of the coupon token associated with the pool|


### claim

*Allows a user to claim their shares from a specific pool.
Calculates the number of shares based on the user's bond token balance and the shares per token.
Transfers the calculated shares to the user's address.*


```solidity
function claim(address _pool) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pool`|`address`|Address of the pool from which to claim shares.|


### allocate

*Allocates shares to a pool.*


```solidity
function allocate(address _pool, uint256 _amountToDistribute) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pool`|`address`|Address of the pool to allocate shares to.|
|`_amountToDistribute`|`uint256`|Amount of shares to allocate.|


### grantRole

*Grants `role` to `account`.
If `account` had not been already granted `role`, emits a {RoleGranted} event.
Requirements:
- the caller must have ``role``'s admin role.*


```solidity
function grantRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to grant|
|`account`|`address`|The account to grant the role to|


### revokeRole

*Revokes `role` from `account`.
If `account` had been granted `role`, emits a {RoleRevoked} event.
Requirements:
- the caller must have ``role``'s admin role.*


```solidity
function revokeRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to revoke|
|`account`|`address`|The account to revoke the role from|


### pause

*Pauses all contract functions except for upgrades.
Requirements:
- the caller must have the `GOV_ROLE`.*


```solidity
function pause() external onlyRole(GOV_ROLE);
```

### unpause

*Unpauses all contract functions.
Requirements:
- the caller must have the `GOV_ROLE`.*


```solidity
function unpause() external onlyRole(GOV_ROLE);
```

### _authorizeUpgrade

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
### ClaimedShares
*Event emitted when a user claims their shares*


```solidity
event ClaimedShares(address user, uint256 period, uint256 shares);
```

### PoolRegistered
*Event emitted when a new pool is registered*


```solidity
event PoolRegistered(address pool, address couponToken);
```

## Errors
### NotEnoughSharesBalance
*Error thrown when there are not enough shares in the contract's balance*


```solidity
error NotEnoughSharesBalance();
```

### UnsupportedPool
*Error thrown when an unsupported pool is accessed*


```solidity
error UnsupportedPool();
```

### NotEnoughSharesToDistribute
*Error thrown when there are not enough shares allocated to distribute*


```solidity
error NotEnoughSharesToDistribute();
```

### NotEnoughCouponBalance
*Error thrown when there are not enough coupon tokens in the contract's balance*


```solidity
error NotEnoughCouponBalance();
```

### PoolAlreadyRegistered
*Error thrown when attempting to register an already registered pool*


```solidity
error PoolAlreadyRegistered();
```

## Structs
### PoolInfo

```solidity
struct PoolInfo {
    address couponToken;
    uint256 amountToDistribute;
}
```

