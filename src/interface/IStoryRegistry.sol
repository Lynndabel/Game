// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStoryRegistry {
    struct Story {
        uint256 id;
        string title;
        string description;
        address creator;
        uint256 currentChapter;
        uint256 totalChapters;
        bool isActive;
        uint256 createdAt;
        uint256[] branchPoints;
    }

    struct Branch {
        uint256 storyId;
        uint256 fromChapter;
        uint256 branchId;
        string description;
        address creator;
        bool isActive;
    }

    function createStory(string calldata title, string calldata description) external returns (uint256);
    function createBranch(uint256 storyId, uint256 fromChapter, string calldata description) external returns (uint256);
    function getStory(uint256 storyId) external view returns (Story memory);
    function getActiveBranches(uint256 storyId) external view returns (Branch[] memory);
    function updateStoryProgress(uint256 storyId, uint256 newChapter) external;
}