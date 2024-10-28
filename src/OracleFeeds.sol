// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract OracleFeeds is AccessControl {

  bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");

  // Mapping of token pairs to their price feed addresses
  mapping(address => mapping(address => address)) public priceFeeds;
  mapping(address => uint256) public feedHeartbeats;

  constructor() {
    _grantRole(GOV_ROLE, msg.sender);
  }

  /**
   * @dev Sets the price feed for a given token pair
   * @param tokenA Address of the first token
   * @param tokenB Address of the second token
   * @param priceFeed Address of the price feed oracle

   * Note: address(0) is a special address that represents USD (IRL asset)
   */
  function setPriceFeed(address tokenA, address tokenB, address priceFeed, uint256 heartbeat) external onlyRole(GOV_ROLE) {
    priceFeeds[tokenA][tokenB] = priceFeed;

    if (heartbeat == 0) {
      heartbeat = 1 days;
    }

    feedHeartbeats[priceFeed] = heartbeat;
  }

  /**
   * @dev Grants `role` to `account`.
   * If `account` had not been already granted `role`, emits a {RoleGranted} event.
   * @param role The role to grant
   * @param account The account to grant the role to
   */
  function grantRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE) {
    _grantRole(role, account);
  }

  /**
   * @dev Revokes `role` from `account`.
   * If `account` had been granted `role`, emits a {RoleRevoked} event.
   * @param role The role to revoke
   * @param account The account to revoke the role from
   */
  function revokeRole(bytes32 role, address account) public virtual override onlyRole(GOV_ROLE) {
    _revokeRole(role, account);
  }
}
