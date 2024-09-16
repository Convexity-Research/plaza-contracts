# PoolFactory
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/PoolFactory.sol)

**Inherits:**
Initializable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable

*This contract is responsible for creating and managing pools.
It inherits from various OpenZeppelin upgradeable contracts for enhanced functionality and security.*


## State Variables
### GOV_ROLE

```solidity
bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
```


### MINTER_ROLE

```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
```


### pools
*Array to store addresses of created pools*


```solidity
address[] public pools;
```


### poolsLength
*Number of pools created*


```solidity
uint256 public poolsLength;
```


### governance
*Address of the governance contract*


```solidity
address public governance;
```


### distributor
*Address of the distributor contract*


```solidity
address public distributor;
```


### ethPriceFeed
*Address of the ETH price feed*


```solidity
address private ethPriceFeed;
```


### tokenDeployer
*Instance of the TokenDeployer contract*


```solidity
TokenDeployer private tokenDeployer;
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
function initialize(address _governance, address _tokenDeployer, address _distributor, address _ethPriceFeed)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_governance`|`address`|Address of the governance account that will have the GOV_ROLE.|
|`_tokenDeployer`|`address`|Address of the TokenDeployer contract.|
|`_distributor`|`address`|Address of the Distributor contract.|
|`_ethPriceFeed`|`address`|Address of the ETH price feed.|


### CreatePool

*Creates a new pool with the given parameters*


```solidity
function CreatePool(PoolParams calldata params, uint256 reserveAmount, uint256 bondAmount, uint256 leverageAmount)
    external
    whenNotPaused
    onlyRole(GOV_ROLE)
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`PoolParams`|Struct containing pool parameters|
|`reserveAmount`|`uint256`|Amount of reserve tokens to seed the pool|
|`bondAmount`|`uint256`|Amount of bond tokens to mint|
|`leverageAmount`|`uint256`|Amount of leverage tokens to mint|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the newly created pool|


### grantRole

*Grants `role` to `account`.
If `account` had not been already granted `role`, emits a {RoleGranted} event.*


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
If `account` had been granted `role`, emits a {RoleRevoked} event.*


```solidity
function revokeRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to revoke|
|`account`|`address`|The account to revoke the role from|


### pause

*Pauses contract. Reverts any interaction except upgrade.*


```solidity
function pause() external onlyRole(GOV_ROLE);
```

### unpause

*Unpauses contract.*


```solidity
function unpause() external onlyRole(GOV_ROLE);
```

### _authorizeUpgrade

*Authorizes an upgrade to a new implementation.
Can only be called by the owner of the contract.*


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


## Events
### PoolCreated
*Emitted when a new pool is created*


```solidity
event PoolCreated(address pool, uint256 reserveAmount, uint256 bondAmount, uint256 leverageAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pool`|`address`|Address of the newly created pool|
|`reserveAmount`|`uint256`|Amount of reserve tokens|
|`bondAmount`|`uint256`|Amount of bond tokens|
|`leverageAmount`|`uint256`|Amount of leverage tokens|

## Errors
### ZeroDebtAmount
*Error thrown when bond amount is zero*


```solidity
error ZeroDebtAmount();
```

### ZeroReserveAmount
*Error thrown when reserve amount is zero*


```solidity
error ZeroReserveAmount();
```

### ZeroLeverageAmount
*Error thrown when leverage amount is zero*


```solidity
error ZeroLeverageAmount();
```

## Structs
### PoolParams

```solidity
struct PoolParams {
    uint256 fee;
    address reserveToken;
    address couponToken;
    uint256 distributionPeriod;
    uint256 sharesPerToken;
}
```

