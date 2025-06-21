// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interface/IStoryRegistry.sol";
import "../error/StoryErrors.sol";
import "../error/AccessErrors.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StoryRegistry is IStoryRegistry, AccessControl, ReentrancyGuard {
    bytes32 public constant STORY_MANAGER_ROLE = keccak256("STORY_MANAGER_ROLE");
    
    uint256 private _storyCounter;
    uint256 private _branchCounter;
    
    mapping(uint256 => Story) private _stories;
    mapping(uint256 => Branch[]) private _storyBranches;
    mapping(address => uint256[]) private _userStories;
    
    event StoryCreated(uint256 indexed storyId, address indexed creator, string title);
    event BranchCreated(uint256 indexed storyId, uint256 indexed branchId, address indexed creator);
    event StoryUpdated(uint256 indexed storyId, uint256 newChapter);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STORY_MANAGER_ROLE, msg.sender);
    }

    function createStory(string calldata title, string calldata description) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        if (bytes(title).length == 0) revert InvalidStoryData();
        
        uint256 storyId = ++_storyCounter;
        
        _stories[storyId] = Story({
            id: storyId,
            title: title,
            description: description,
            creator: msg.sender,
            currentChapter: 0,
            totalChapters: 0,
            isActive: true,
            createdAt: block.timestamp,
            branchPoints: new uint256[](0)
        });
        
        _userStories[msg.sender].push(storyId);
        
        emit StoryCreated(storyId, msg.sender, title);
        return storyId;
    }

    function createBranch(uint256 storyId, uint256 fromChapter, string calldata description) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        Story storage story = _stories[storyId];
        if (story.id == 0) revert StoryNotFound(storyId);
        if (!story.isActive) revert StoryInactive(storyId);
        if (fromChapter > story.currentChapter) revert InvalidChapterNumber(fromChapter);
        
        uint256 branchId = ++_branchCounter;
        
        Branch memory newBranch = Branch({
            storyId: storyId,
            fromChapter: fromChapter,
            branchId: branchId,
            description: description,
            creator: msg.sender,
            isActive: true
        });
        
        _storyBranches[storyId].push(newBranch);
        story.branchPoints.push(fromChapter);
        
        emit BranchCreated(storyId, branchId, msg.sender);
        return branchId;
    }

    function updateStoryProgress(uint256 storyId, uint256 newChapter) 
        external 
        onlyRole(STORY_MANAGER_ROLE) 
    {
        Story storage story = _stories[storyId];
        if (story.id == 0) revert StoryNotFound(storyId);
        
        story.currentChapter = newChapter;
        if (newChapter > story.totalChapters) {
            story.totalChapters = newChapter;
        }
        
        emit StoryUpdated(storyId, newChapter);
    }

    function getStory(uint256 storyId) external view returns (Story memory) {
        Story memory story = _stories[storyId];
        if (story.id == 0) revert StoryNotFound(storyId);
        return story;
    }

    function getActiveBranches(uint256 storyId) external view returns (Branch[] memory) {
        Branch[] memory branches = _storyBranches[storyId];
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < branches.length; i++) {
            if (branches[i].isActive) activeCount++;
        }
        
        Branch[] memory activeBranches = new Branch[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < branches.length; i++) {
            if (branches[i].isActive) {
                activeBranches[index] = branches[i];
                index++;
            }
        }
        
        return activeBranches;
    }

    function getUserStories(address user) external view returns (uint256[] memory) {
        return _userStories[user];
    }
}