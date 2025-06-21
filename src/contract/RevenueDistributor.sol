// contracts/core/RevenueDistributor.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interface/IRevenueDistributor.sol";
import "../libraries/StoryMath.sol";
import "../error/AccessErrors.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RevenueDistributor is IRevenueDistributor, AccessControl, ReentrancyGuard {
    bytes32 public constant REVENUE_ADMIN_ROLE = keccak256("REVENUE_ADMIN_ROLE");

    uint256 public authorSharePercentage = 5000; // 50%
    uint256 public voterSharePercentage = 3000;  // 30%
    uint256 public platformSharePercentage = 2000; // 20%

    mapping(uint256 => mapping(address => RevenueShare)) private _revenueShares;
    mapping(uint256 => uint256) private _totalChapterRevenue;
    mapping(address => uint256) private _claimableRevenue;

    event RevenueDistributed(uint256 indexed chapterId, uint256 totalRevenue);
    event RevenueClaimed(address indexed recipient, uint256 amount);
    event RevenuePercentagesUpdated(uint256 authorShare, uint256 voterShare, uint256 platformShare);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REVENUE_ADMIN_ROLE, msg.sender);
    }

    function distributeRevenue(uint256 chapterId, uint256 totalRevenue) 
        external 
        onlyRole(REVENUE_ADMIN_ROLE) 
        nonReentrant 
    {
        _totalChapterRevenue[chapterId] = totalRevenue;
        
        uint256 authorShare = StoryMath.calculatePercentage(totalRevenue, authorSharePercentage);
        uint256 voterShare = StoryMath.calculatePercentage(totalRevenue, voterSharePercentage);
        uint256 platformShare = StoryMath.calculatePercentage(totalRevenue, platformSharePercentage);
        
        // Implementation would need to get chapter author from ChapterNFT contract
        // and voters from VotingManager contract
        
        emit RevenueDistributed(chapterId, totalRevenue);
    }

    function claimRevenue(uint256 chapterId) external nonReentrant {
        RevenueShare storage share = _revenueShares[chapterId][msg.sender];
        if (share.amount == 0 || share.claimed) revert Unauthorized(msg.sender);
        
        share.claimed = true;
        _claimableRevenue[msg.sender] += share.amount;
        
        // Transfer logic would be implemented here
        
        emit RevenueClaimed(msg.sender, share.amount);
    }

    function getRevenueShare(uint256 chapterId, address recipient) 
        external 
        view 
        returns (uint256) 
    {
        return _revenueShares[chapterId][recipient].amount;
    }

    function setRevenuePercentages(uint256 authorShare, uint256 voterShare, uint256 platformShare) 
        external 
        onlyRole(REVENUE_ADMIN_ROLE) 
    {
        if (authorShare + voterShare + platformShare != 10000) revert InvalidAddress(address(0));
        
        authorSharePercentage = authorShare;
        voterSharePercentage = voterShare;
        platformSharePercentage = platformShare;
        
        emit RevenuePercentagesUpdated(authorShare, voterShare, platformShare);
    }
}
