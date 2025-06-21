// contracts/utils/AccessManager.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../errors/AccessErrors.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AccessManager is AccessControl {
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant VERIFIED_AUTHOR_ROLE = keccak256("VERIFIED_AUTHOR_ROLE");

    mapping(address => bool) private _bannedUsers;
    mapping(address => uint256) private _authorReputation;
    mapping(address => uint256) private _moderatorActions;

    event UserBanned(address indexed user, address indexed moderator);
    event UserUnbanned(address indexed user, address indexed moderator);
    event ReputationUpdated(address indexed author, uint256 newReputation);
    event ModeratorActionRecorded(address indexed moderator, uint256 actionCount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PLATFORM_ADMIN_ROLE, msg.sender);
    }

    function banUser(address user) external onlyRole(MODERATOR_ROLE) {
        if (user == address(0)) revert InvalidAddress(user);
        if (hasRole(PLATFORM_ADMIN_ROLE, user)) revert Unauthorized(msg.sender);
        
        _bannedUsers[user] = true;
        _moderatorActions[msg.sender]++;
        
        emit UserBanned(user, msg.sender);
        emit ModeratorActionRecorded(msg.sender, _moderatorActions[msg.sender]);
    }

    function unbanUser(address user) external onlyRole(MODERATOR_ROLE) {
        if (user == address(0)) revert InvalidAddress(user);
        
        _bannedUsers[user] = false;
        _moderatorActions[msg.sender]++;
        
        emit UserUnbanned(user, msg.sender);
        emit ModeratorActionRecorded(msg.sender, _moderatorActions[msg.sender]);
    }

    function updateAuthorReputation(address author, uint256 reputation) 
        external 
        onlyRole(MODERATOR_ROLE) 
    {
        if (author == address(0)) revert InvalidAddress(author);
        
        _authorReputation[author] = reputation;
        
        // Auto-grant verified author role for high reputation
        if (reputation >= 1000 && !hasRole(VERIFIED_AUTHOR_ROLE, author)) {
            _grantRole(VERIFIED_AUTHOR_ROLE, author);
        }
        
        emit ReputationUpdated(author, reputation);
    }

    function isUserBanned(address user) external view returns (bool) {
        return _bannedUsers[user];
    }

    function getAuthorReputation(address author) external view returns (uint256) {
        return _authorReputation[author];
    }

    function getModeratorActions(address moderator) external view returns (uint256) {
        return _moderatorActions[moderator];
    }

    modifier notBanned(address user) {
        if (_bannedUsers[user]) revert Unauthorized(user);
        _;
    }

    modifier onlyVerifiedAuthor() {
        if (!hasRole(VERIFIED_AUTHOR_ROLE, msg.sender)) revert Unauthorized(msg.sender);
        _;
    }
}