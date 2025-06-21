// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../libraries/StoryMath.sol";

contract ReaderRewards is ERC20, AccessControl {
    bytes32 public constant REWARDS_ADMIN_ROLE = keccak256("REWARDS_ADMIN_ROLE");

    struct ReaderStats {
        uint256 chaptersRead;
        uint256 storiesCompleted;
        uint256 totalRewards;
        uint256 lastRewardClaim;
        uint256 streak;
    }

    mapping(address => ReaderStats) private _readerStats;
    mapping(address => mapping(uint256 => bool)) private _hasReadChapter;
    
    uint256 public baseReward = 10e18; // 10 tokens per chapter
    uint256 public completionBonus = 100e18; // 100 tokens for story completion
    uint256 public streakMultiplier = 110; // 10% bonus per day streak (max 200%)

    event ChapterRead(address indexed reader, uint256 indexed chapterId);
    event StoryCompleted(address indexed reader, uint256 indexed storyId);
    event RewardsClaimed(address indexed reader, uint256 amount);
    event StreakUpdated(address indexed reader, uint256 streak);

    constructor() ERC20("Reader Rewards", "READ") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REWARDS_ADMIN_ROLE, msg.sender);
    }

    function recordChapterRead(address reader, uint256 chapterId) 
        external 
        onlyRole(REWARDS_ADMIN_ROLE) 
    {
        if (_hasReadChapter[reader][chapterId]) return;
        
        _hasReadChapter[reader][chapterId] = true;
        _readerStats[reader].chaptersRead++;
        
        _updateStreak(reader);
        uint256 reward = _calculateChapterReward(reader);
        _mint(reader, reward);
        
        _readerStats[reader].totalRewards += reward;
        _readerStats[reader].lastRewardClaim = block.timestamp;
        
        emit ChapterRead(reader, chapterId);
        emit RewardsClaimed(reader, reward);
    }

    function recordStoryCompletion(address reader, uint256 storyId) 
        external 
        onlyRole(REWARDS_ADMIN_ROLE) 
    {
        _readerStats[reader].storiesCompleted++;
        
        uint256 bonus = _calculateCompletionBonus(reader);
        _mint(reader, bonus);
        
        _readerStats[reader].totalRewards += bonus;
        
        emit StoryCompleted(reader, storyId);
        emit RewardsClaimed(reader, bonus);
    }

    function _calculateChapterReward(address reader) private view returns (uint256) {
        ReaderStats memory stats = _readerStats[reader];
        uint256 reward = baseReward;
        
        // Apply streak multiplier (max 200%)
        if (stats.streak > 0) {
            uint256 multiplier = streakMultiplier + (stats.streak * 10);
            if (multiplier > 200) multiplier = 200;
            reward = (reward * multiplier) / 100;
        }
        
        return reward;
    }

    function _calculateCompletionBonus(address reader) private view returns (uint256) {
        ReaderStats memory stats = _readerStats[reader];
        uint256 bonus = completionBonus;
        
        // Additional bonus for multiple completions
        if (stats.storiesCompleted > 1) {
            bonus += (stats.storiesCompleted - 1) * (completionBonus / 10);
        }
        
        return bonus;
    }

    function _updateStreak(address reader) private {
        ReaderStats storage stats = _readerStats[reader];
        
        if (stats.lastRewardClaim == 0) {
            stats.streak = 1;
        } else if (block.timestamp - stats.lastRewardClaim <= 1 days) {
            stats.streak++;
        } else if (block.timestamp - stats.lastRewardClaim > 2 days) {
            stats.streak = 1;
        }
        
        emit StreakUpdated(reader, stats.streak);
    }

    function getReaderStats(address reader) external view returns (ReaderStats memory) {
        return _readerStats[reader];
    }

    function hasReadChapter(address reader, uint256 chapterId) external view returns (bool) {
        return _hasReadChapter[reader][chapterId];
    }

    function setRewardParameters(
        uint256 _baseReward,
        uint256 _completionBonus,
        uint256 _streakMultiplier
    ) external onlyRole(REWARDS_ADMIN_ROLE) {
        baseReward = _baseReward;
        completionBonus = _completionBonus;
        streakMultiplier = _streakMultiplier;
    }
}