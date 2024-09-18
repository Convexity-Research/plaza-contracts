// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Merchant} from "./Merchant.sol";
import {PoolFactory} from "./PoolFactory.sol";

contract MerchantAutomation {
  Merchant private merchant;
  PoolFactory private factory;

  constructor(address _merchant, address _poolFactory) {
    merchant = Merchant(_merchant);
    factory = PoolFactory(_poolFactory);
  }

  // @todo: if one pool fails for whatever reason, everything else will fail too
  // We should improve this by isolating each exeucition independantly or using soft-revert
  function execute() external returns (bool canExec, bytes memory execPayload) {
    uint256 poolsLength = factory.poolsLength();

    address pool;
    for (uint256 i = 0; i < poolsLength; i++) {
      pool = factory.pools(i);
      if (merchant.hasPendingOrders(pool)) {
        execPayload = abi.encodeWithSelector(
          Merchant.updateLimitOrders.selector,
          pool
        );

        return (true, execPayload);
      }

      if (merchant.ordersPriceReached(pool)) {
        execPayload = abi.encodeWithSelector(
          Merchant.executeOrders.selector,
          pool
        );

        return (true, execPayload);
      }
    }

    return (false, execPayload);
  }
}
