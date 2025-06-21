// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IChapterNFT is IERC721 {
    struct ChapterMetadata {
        uint256 storyId;
        uint256 chapterNumber;
        uint256 branchId;
        string content;
        address author;
        uint256 votesReceived;
        uint256 mintTimestamp;
        string ipfsHash;
        bool isCanonical;
    }

    function mintChapter(
        address to,
        uint256 storyId,
        uint256 chapterNumber,
        uint256 branchId,
        string calldata content,
        string calldata ipfsHash
    ) external returns (uint256);

    function getChapterMetadata(uint256 tokenId) external view returns (ChapterMetadata memory);
    function getStoryChapters(uint256 storyId) external view returns (uint256[] memory);
    function setCanonical(uint256 tokenId, bool canonical) external;
    function updateVoteCount(uint256 tokenId, uint256 votes) external;
}