// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Merchant} from "./Merchant.sol";
import {PoolFactory} from "./PoolFactory.sol";

contract MerchantAutomation {
  Merchant private merchant;
  PoolFactory private factory;

  constructor(address _merchant) {
    merchant = Merchant(_merchant);
    factory = PoolFactory(merchant.factory());
  }

  // @todo: if one pool fails for whatever reason, everything else will fail too
  // We should improve this by isolating each exeucition independantly
  function execute() external {
    uint256 poolsLength = factory.poolsLength();

    address pool;
    for (uint256 i = 0; i < poolsLength; i++) {
      pool = factory.pools(i);
      if (merchant.hasPendingOrders(pool)) {
        merchant.updateLimitOrders(pool);
      }

      if (merchant.ordersPriceReached(pool)) {
        merchant.executeOrders(pool);
      }
    }
  }
}
