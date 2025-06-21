// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error Unauthorized(address caller);
error InvalidAddress(address addr);
error ContractPaused();
error InvalidRole(bytes32 role);
error RoleAlreadyGranted(address account, bytes32 role);
