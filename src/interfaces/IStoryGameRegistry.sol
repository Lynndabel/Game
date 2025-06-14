// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contract/StoryGameTypes.sol";

interface IStoryGameRegistry {
    using StoryGameTypes for *;

    // --- View functions ---
    function storyExists(uint256 _storyId) external view returns (bool);

    function controller() external view returns (address);

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
        );

    // --- Mutating functions ---
    function createStory(
        address _creator,
        string calldata _title,
        StoryGameTypes.StoryCategory _category,
        string[] calldata _tags
    ) external returns (uint256 storyId);

    function incrementChapter(uint256 _storyId) external;

    function markStoryComplete(uint256 _storyId) external;

    function markStoryAbandoned(uint256 _storyId) external;
}
