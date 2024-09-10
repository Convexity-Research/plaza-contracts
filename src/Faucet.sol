// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Token} from "../test/mocks/Token.sol";

contract Faucet {
  Token public reserveToken;
  Token public couponToken;

  constructor() {
    reserveToken = new Token("Wrapped Fake ETH", "WETH");
    couponToken = new Token("Circle Fake USD", "USDC");
  }
  
  function faucet() public {
    reserveToken.mint(msg.sender, 1 ether);
    couponToken.mint(msg.sender, 5000 ether);
  }

  function faucet(uint256 amountReserve, uint256 amountCoupon) public {
    reserveToken.mint(msg.sender, amountReserve);
    couponToken.mint(msg.sender, amountCoupon);
  }

  function faucetReserve(uint256 amount) public {
    reserveToken.mint(msg.sender, amount);
  }

  function faucetCoupon(uint256 amount) public {
    couponToken.mint(msg.sender, amount);
  }
}
