// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
  uint8 private tokenDecimals;

  constructor (string memory name, string memory symbol) ERC20(name, symbol) {
    tokenDecimals = 18;
  }

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }

  function burn(address account, uint256 amount) public {
    _burn(account, amount);
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
