// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error StoryNotFound(uint256 storyId);
error StoryInactive(uint256 storyId);
error UnauthorizedStoryAction(address caller, uint256 storyId);
error InvalidChapterNumber(uint256 chapterNumber);
error BranchNotFound(uint256 branchId);
error StoryAlreadyCompleted(uint256 storyId);
error InvalidStoryData();