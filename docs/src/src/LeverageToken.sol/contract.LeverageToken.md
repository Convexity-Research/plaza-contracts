# LeverageToken
[Git Source](https://github.com/Convexity-Research/plaza-evm/blob/6476279397e46b4a2f67f3c7fe6b87911498d73b/src/LeverageToken.sol)

**Inherits:**
Initializable, ERC20Upgradeable, AccessControlUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, PausableUpgradeable

*This contract implements a leverage token with upgradeable capabilities, access control, and pausability.*


## State Variables
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


## Functions
### constructor


```solidity
constructor();
```

### initialize

*Initializes the contract with a name, symbol, minter, and governance address.*


```solidity
function initialize(string memory name, string memory symbol, address minter, address governance) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|The name of the token|
|`symbol`|`string`|The symbol of the token|
|`minter`|`address`|The address that will have minting privileges|
|`governance`|`address`|The address that will have governance privileges|


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


### grantRole

Can only be called by addresses with the GOV_ROLE.

*Grants a role to an account.*


```solidity
function grantRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role being granted|
|`account`|`address`|The account receiving the role|


### revokeRole

Can only be called by addresses with the GOV_ROLE.

*Revokes a role from an account.*


```solidity
function revokeRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role being revoked|
|`account`|`address`|The account losing the role|


### pause

Can only be called by addresses with the GOV_ROLE. Does not prevent contract upgrades.

*Pauses all token transfers, mints, burns, and indexing updates.*


```solidity
function pause() external onlyRole(GOV_ROLE);
```

### unpause

Can only be called by addresses with the GOV_ROLE.

*Unpauses all token transfers, mints, burns, and indexing updates.*


```solidity
function unpause() external onlyRole(GOV_ROLE);
```

### _authorizeUpgrade

Can only be called by the owner of the contract.

*Internal function to authorize an upgrade to a new implementation.*


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The address of the new implementation|


