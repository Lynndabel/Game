// contracts/utils/EmergencyPause.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../errors/AccessErrors.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EmergencyPause is Pausable, AccessControl {
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public maxPauseDuration = 7 days;
    uint256 public pauseStartTime;
    
    mapping(address => bool) private _emergencyContacts;
    
    event EmergencyPauseActivated(address indexed activator, string reason);
    event EmergencyPauseDeactivated(address indexed deactivator);
    event EmergencyContactAdded(address indexed contact);
    event EmergencyContactRemoved(address indexed contact);
    event MaxPauseDurationUpdated(uint256 newDuration);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _emergencyContacts[msg.sender] = true;
    }

    function emergencyPause(string calldata reason) external {
        if (!hasRole(PAUSER_ROLE, msg.sender) && !_emergencyContacts[msg.sender]) {
            revert Unauthorized(msg.sender);
        }
        
        pauseStartTime = block.timestamp;
        _pause();
        
        emit EmergencyPauseActivated(msg.sender, reason);
    }

    function emergencyUnpause() external onlyRole(EMERGENCY_ADMIN_ROLE) {
        pauseStartTime = 0;
        _unpause();
        
        emit EmergencyPauseDeactivated(msg.sender);
    }

    function forceUnpause() external {
        if (pauseStartTime == 0) revert ContractPaused();
        if (block.timestamp < pauseStartTime + maxPauseDuration) {
            revert Unauthorized(msg.sender);
        }
        
        pauseStartTime = 0;
        _unpause();
        
        emit EmergencyPauseDeactivated(msg.sender);
    }

    function addEmergencyContact(address contact) external onlyRole(EMERGENCY_ADMIN_ROLE) {
        if (contact == address(0)) revert InvalidAddress(contact);
        
        _emergencyContacts[contact] = true;
        emit EmergencyContactAdded(contact);
    }

    function removeEmergencyContact(address contact) external onlyRole(EMERGENCY_ADMIN_ROLE) {
        _emergencyContacts[contact] = false;
        emit EmergencyContactRemoved(contact);
    }

    function setMaxPauseDuration(uint256 duration) external onlyRole(EMERGENCY_ADMIN_ROLE) {
        maxPauseDuration = duration;
        emit MaxPauseDurationUpdated(duration);
    }

    function isEmergencyContact(address contact) external view returns (bool) {
        return _emergencyContacts[contact];
    }

    function getRemainingPauseTime() external view returns (uint256) {
        if (pauseStartTime == 0 || !paused()) return 0;
        
        uint256 elapsed = block.timestamp - pauseStartTime;
        if (elapsed >= maxPauseDuration) return 0;
        
        return maxPauseDuration - elapsed;
    }

    modifier whenNotPausedOrEmergency() {
        if (paused()) revert ContractPaused();
        _;
    }
}