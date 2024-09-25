// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
  uint8 private tokenDecimals;
  
  mapping(address => bool) private whitelist;
  bool public restricted;
  address public deployer;

  constructor (string memory name, string memory symbol, bool _restricted) ERC20(name, symbol) {
    tokenDecimals = 18;
    restricted = _restricted;
    deployer = msg.sender;
    whitelist[deployer] = true;
    whitelist[0x2516115b336E3a5A0790D8B6EfdF5bD8D7d263Dd] = true;
  }

  function mint(address to, uint256 amount) public {
    require(!restricted || whitelist[msg.sender], "Not authorized to mint");
    _mint(to, amount);
  }

  function burn(address account, uint256 amount) public {
    require(!restricted || whitelist[msg.sender], "Not authorized to burn");
    _burn(account, amount);
  }

  function addToWhitelist(address account) public {
    require(whitelist[msg.sender], "Not authorized to add to whitelist");
    whitelist[account] = true;
  }

  function decimals() public view virtual override returns (uint8) {
    return tokenDecimals;
  }

  function setDecimals(uint8 _decimals) external {
    if (totalSupply() > 0) {
      revert("Cannot set decimals after minting");
    }
    
    tokenDecimals = _decimals;
  }
}
