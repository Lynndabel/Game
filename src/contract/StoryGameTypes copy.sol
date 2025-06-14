// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library StoryGameTypes {
    
    // Story categories
    enum StoryCategory {
        Fiction,
        SciFi,
        Fantasy,
        Mystery,
        Romance,
        Horror,
        Comedy,
        Drama,
        Adventure,
        Other
    }
    
    // Story structure
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
    
    // Chapter structure
    struct Chapter {
        uint256 id;
        uint256 storyId;
        uint256 chapterNumber;
        string contentHash; // Short content hash / legacy
        string ipfsHash;    // Full IPFS CID for off-chain storage
        address author;
        uint256 votes;
        bool isWinner;
        uint256 timestamp;
        bytes32 contentHashBytes; // Duplicate detection
    }
    
    // Vote structure
    struct Vote {
        address voter;
        uint256 chapterId;
        uint256 weight;
        uint256 timestamp;
    }
    
    // Voting round data
    struct VotingRound {
        uint256 storyId;
        uint256[] proposalIds;
        uint256 deadline;
        uint256 tieBreakCount;
        uint256[] tiedChapters;
        bool isActive;
    }
    
    // Economic data
    struct EconomicData {
        uint256 totalReward;
        uint256 popularity;
        uint256 voterCount;
        bool isCommunityFavorite;
        uint256 abandonedRewards;
    }
    
    // User statistics
    struct UserStats {
        uint256 totalContributed;
        uint256 accuracyScore;
        uint256 chaptersAuthored;
        uint256 votescast;
        uint256 rewardsEarned;
    }
    
    // Reward distribution percentages (out of 10000 = 100%)
    struct RewardDistribution {
        uint256 winnerShare;    // 40%
        uint256 creatorShare;   // 20%
        uint256 voterShare;     // 25%
        uint256 treasuryShare;  // 15%
    }
    
    // System configuration
    struct SystemConfig {
        uint256 baseVotingFee;
        uint256 baseSubmissionFee;
        uint256 votingDuration;
        uint256 maxChapterLength;
        uint256 minChapterLength;
        uint256 submissionCooldown;
        uint256 maxProposalsPerAuthor;
        uint256 minVotesToWin;
        uint256 maxTagsPerStory;
        uint256 abandonmentPeriod;
        uint256 tieBreakerExtension;
    }
    
    // Content validation result
    struct ValidationResult {
        bool isValid;
        string reason;
        bytes32 contentHash;
    }
    
    // Tie-breaking data
    struct TieBreakData {
        uint256[] tiedChapterIds;
        uint256 extensionCount;
        uint256 newDeadline;
    }
}