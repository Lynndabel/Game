// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StoryGameTypes.sol";
import "./Errors.sol";

/**
 * @title StoryRegistry
 * @notice Stores story metadata and life-cycle flags.
 */
contract StoryRegistry is Ownable {
    using StoryGameTypes for *;

    // --------------------------------------------------
    // Storage
    // --------------------------------------------------
    uint256 public nextStoryId = 1;
    mapping(uint256 => StoryGameTypes.Story) private stories;
    mapping(StoryGameTypes.StoryCategory => uint256[]) public storiesByCategory;

    address public immutable controller;

    // --------------------------------------------------
    // Modifiers
    // --------------------------------------------------
    modifier onlyController() {
        if (msg.sender != controller) revert StoryGameErrors.OnlyController();
        _;
    }

    constructor(address _controller) {
        require(_controller != address(0), "controller address required");
        controller = _controller;
    }

    // --------------------------------------------------
    // Views
    // --------------------------------------------------
    function storyExists(uint256 _storyId) external view returns (bool) {
        return stories[_storyId].id != 0;
    }

    function getStory(uint256 _storyId) external view returns (StoryGameTypes.Story memory) {
        return stories[_storyId];
    }

    /**
     * @dev Returns the tuple demanded by ChapterManager.
     */
    function getStoryInfo(uint256 _storyId)
        external
        view
        returns (
            uint256 id,
            string memory title,
            address creator,
            uint256 currentChapter,
            bool isComplete,
            uint256 createdAt,
            uint256 lastActivityTime,
            StoryGameTypes.StoryCategory category,
            bool isAbandoned
        )
    {
        StoryGameTypes.Story storage s = stories[_storyId];
        id = s.id;
        title = s.title;
        creator = s.creator;
        currentChapter = s.currentChapter;
        isComplete = s.isComplete;
        createdAt = s.createdAt;
        lastActivityTime = s.lastActivityTime;
        category = s.category;
        isAbandoned = s.isAbandoned;
    }

    // --------------------------------------------------
    // Mutating functions (only controller)
    // --------------------------------------------------
    function createStory(
        address _creator,
        string calldata _title,
        StoryGameTypes.StoryCategory _category,
        string[] calldata _tags
    ) external onlyController returns (uint256 storyId) {
        storyId = nextStoryId++;
        stories[storyId] = StoryGameTypes.Story({
            id: storyId,
            title: _title,
            creator: _creator,
            currentChapter: 0,
            isComplete: false,
            totalReward: 0,
            createdAt: block.timestamp,
            lastActivityTime: block.timestamp,
            category: _category,
            tags: _tags,
            isAbandoned: false
        });
        storiesByCategory[_category].push(storyId);
    }

    function incrementChapter(uint256 _storyId) external onlyController {
        stories[_storyId].currentChapter += 1;
        stories[_storyId].lastActivityTime = block.timestamp;
    }

    function markStoryComplete(uint256 _storyId) external onlyController {
        stories[_storyId].isComplete = true;
    }

    function markStoryAbandoned(uint256 _storyId) external onlyController {
        stories[_storyId].isAbandoned = true;
    }
}
