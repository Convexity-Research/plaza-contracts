// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Merchant} from "./Merchant.sol";
import {PoolFactory} from "./PoolFactory.sol";

contract MerchantAutomation {
  Merchant private merchant;
  PoolFactory private factory;

  error NothingToExecute();
  error ExecutionError();

  constructor(address _merchant, address _poolFactory) {
    merchant = Merchant(_merchant);
    factory = PoolFactory(_poolFactory);
  }

  // @todo: if one pool fails for whatever reason, everything else will fail too
  // We should improve this by isolating each exeucition independantly or using soft-revert
  function canExecute() public returns (bool canExec, bytes memory payload) {
    uint256 poolsLength = factory.poolsLength();

    address pool;
    for (uint256 i = 0; i < poolsLength; i++) {
      pool = factory.pools(i);
      if (merchant.hasPendingOrders(pool)) {
        payload = abi.encodeWithSelector(
          Merchant.updateOrders.selector,
          pool
        );

        return (true, payload);
      }

      if (merchant.ordersPriceReached(pool)) {
        payload = abi.encodeWithSelector(
          Merchant.executeOrders.selector,
          pool
        );

        return (true, payload);
      }
    }

    return (false, payload);
  }

  function execute() external {
    (bool canExec, bytes memory payload) = canExecute();
    if (!canExec) {
      revert NothingToExecute();
    }

    (bool success,) = address(merchant).call{value:0}(payload);
    if (!success) {
      revert ExecutionError();
    }
  }
}
