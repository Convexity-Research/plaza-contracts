// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

//import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Merchant is AccessControl, Pausable {

  // Define a constants for the access roles using keccak256 to generate a unique hash
  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  struct LimitOrder {
    uint256 price;
    uint256 amount;
  }

  struct DayMarketData {
    uint256 weightedAverageHighs;
    uint256 weightedAverageLows;
    uint256 volume;
  }

  mapping (address => DayMarketData[]) poolMarketData;

  constructor() {
    _setRoleAdmin(GOV_ROLE, GOV_ROLE);
    _grantRole(GOV_ROLE, msg.sender);
  }

  function getLimitOrders() public returns(LimitOrder[] memory) {
    
  }

  function pause() external onlyRole(GOV_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(GOV_ROLE) {
    _unpause();
  }
}
