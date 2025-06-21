// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStoryGovernance {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function pause() external;
    function unpause() external;
    function updatePlatformSettings(bytes calldata data) external;
}