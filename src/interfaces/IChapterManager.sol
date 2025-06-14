// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contract/StoryGameTypes.sol";

interface IChapterManager {
    function createFirstChapter(
        uint256 _storyId,
        string calldata _content,
        address _author
    ) external returns (uint256);

    function submitChapterProposal(
        uint256 _storyId,
        string calldata _content,
        address _author
    ) external returns (uint256);

    function markChapterAsWinner(uint256 _chapterId) external;

    function updateChapterVotes(uint256 _chapterId, uint256 _newVoteCount) external;

    function resetChapterProposals(uint256 _storyId) external;

    function getStoryChapters(uint256 _storyId) external view returns (uint256[] memory);

    function getChapter(uint256 _chapterId) external view returns (StoryGameTypes.Chapter memory);
}
