// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Shared interfaces for all contracts to communicate

interface IStoryRegistry {
    struct Story {
        uint256 id;
        string title;
        address creator;
        uint256 currentChapter;
        bool isComplete;
        uint256 totalReward;
        uint256 createdAt;
        uint256 lastActivityTime;
        StoryCategory category;
        string[] tags;
        bool isAbandoned;
    }
    
    enum StoryCategory {
        Fiction, SciFi, Fantasy, Mystery, Romance, 
        Horror, Comedy, Drama, Adventure, Other
    }
    
    function createStory(
        string memory title,
        address creator,
        StoryCategory category,
        string[] memory tags
    ) external returns (uint256 storyId);
    
    function updateStoryReward(uint256 storyId, uint256 amount) external;
    function updateLastActivity(uint256 storyId) external;
    function markComplete(uint256 storyId) external;
    function markAbandoned(uint256 storyId) external;
    function getStory(uint256 storyId) external view returns (Story memory);
    function incrementChapter(uint256 storyId) external;
}

interface IChapterManager {
    struct Chapter {
        uint256 id;
        uint256 storyId;
        uint256 chapterNumber;
        string contentHash; // IPFS hash
        address author;
        uint256 votes;
        bool isWinner;
        uint256 timestamp;
        bytes32 dupCheckHash;
    }
    
    function submitChapter(
        uint256 storyId,
        string memory contentHash,
        address author,
        uint256 chapterNumber
    ) external returns (uint256 chapterId);
    
    function addWinningChapter(uint256 storyId, uint256 chapterId) external;
    function markChapterWinner(uint256 chapterId) external;
    function getChapter(uint256 chapterId) external view returns (Chapter memory);
    function getStoryChapters(uint256 storyId) external view returns (uint256[] memory);
    function getChapterProposals(uint256 storyId) external view returns (uint256[] memory);
    function isContentDuplicate(string memory content) external view returns (bool);
}

interface IVotingEngine {
    struct Vote {
        address voter;
        uint256 chapterId;
        uint256 weight;
        uint256 timestamp;
    }
    
    function startVotingPeriod(uint256 storyId) external;
    function castVote(uint256 chapterId, address voter, uint256 weight) external;
    function finalizeVoting(uint256 storyId) external returns (uint256 winningChapterId);
    function isVotingActive(uint256 storyId) external view returns (bool);
    function hasVoted(uint256 chapterId, address voter) external view returns (bool);
    function getVotingDeadline(uint256 storyId) external view returns (uint256);
    function incrementChapterVotes(uint256 chapterId) external;
}

interface IRewardDistributor {
    function distributeChapterRewards(
        uint256 storyId,
        uint256 winningChapterId,
        uint256 totalReward
    ) external;
    
    function processStoryCompletion(uint256 storyId, address creator) external;
    function handleAbandonedStory(uint256 storyId, uint256 amount) external;
    function claimAbandonedRefund(uint256 storyId, address claimant) external;
    function addToTreasury(uint256 amount) external payable;
    function recordContribution(uint256 storyId, address contributor, uint256 amount) external;
    function getTreasuryBalance() external view returns (uint256);
}

interface IContentValidator {
    function validateContent(string memory content) external view returns (bool);
    function validateTitle(string memory title) external pure returns (bool);
    function validateTags(string[] memory tags) external pure returns (bool);
    function generateContentHash(string memory content) external pure returns (bytes32);
    function addBannedWord(string memory word) external;
    function removeBannedWord(string memory word) external;
}

interface IStoryNFT {
    function mintChapterNFT(address to, uint256 chapterId) external returns (uint256 tokenId);
    function setChapterMetadata(uint256 tokenId, string memory metadataURI) external;
    function getTokenByChapter(uint256 chapterId) external view returns (uint256);
}

interface IStoryGameController {
    function calculateVotingFee(uint256 storyId) external view returns (uint256);
    function calculateSubmissionFee(uint256 storyId) external view returns (uint256);
    function getStoryPopularity(uint256 storyId) external view returns (uint256);
    function updatePopularity(uint256 storyId) external;
}