// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interface/IStoryGovernance.sol";
import "../error/AccessErrors.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StoryGovernance is IStoryGovernance, AccessControl, Pausable {
    bytes32 public constant GOVERNANCE_ADMIN_ROLE = keccak256("GOVERNANCE_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant STORY_ADMIN_ROLE = keccak256("STORY_ADMIN_ROLE");

    struct PlatformSettings {
        uint256 minVotingPeriod;
        uint256 maxVotingPeriod;
        uint256 proposalThreshold;
        uint256 quorumThreshold;
        bool emergencyMode;
    }

    PlatformSettings public platformSettings;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event PlatformSettingsUpdated(PlatformSettings settings);
    event EmergencyModeToggled(bool enabled);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        platformSettings = PlatformSettings({
            minVotingPeriod: 1 days,
            maxVotingPeriod: 7 days,
            proposalThreshold: 1000e18, // 1000 tokens
            quorumThreshold: 5000, // 50%
            emergencyMode: false
        });
    }

    function grantRole(bytes32 role, address account) 
        public 
        override(AccessControl, IStoryGovernance) 
        onlyRole(GOVERNANCE_ADMIN_ROLE) 
    {
        if (account == address(0)) revert InvalidAddress(account);
        if (hasRole(role, account)) revert RoleAlreadyGranted(account, role);
        
        _grantRole(role, account);
        emit RoleGranted(role, account, msg.sender);
    }

    function revokeRole(bytes32 role, address account) 
        public 
        override(AccessControl, IStoryGovernance) 
        onlyRole(GOVERNANCE_ADMIN_ROLE) 
    {
        if (account == address(0)) revert InvalidAddress(account);
        
        _revokeRole(role, account);
        emit RoleRevoked(role, account, msg.sender);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function updatePlatformSettings(bytes calldata data) external onlyRole(GOVERNANCE_ADMIN_ROLE) {
        PlatformSettings memory newSettings = abi.decode(data, (PlatformSettings));
        
        if (newSettings.minVotingPeriod > newSettings.maxVotingPeriod) {
            revert InvalidStoryData();
        }
        
        platformSettings = newSettings;
        emit PlatformSettingsUpdated(newSettings);
    }

    function toggleEmergencyMode() external onlyRole(GOVERNANCE_ADMIN_ROLE) {
        platformSettings.emergencyMode = !platformSettings.emergencyMode;
        emit EmergencyModeToggled(platformSettings.emergencyMode);
    }

    function hasRole(bytes32 role, address account) 
        public 
        view 
        override(AccessControl, IStoryGovernance) 
        returns (bool) 
    {
        return super.hasRole(role, account);
    }
}
