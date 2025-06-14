// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library StoryGameErrors {
    // === General Errors ===
    error InvalidInput();
    error Unauthorized();
    error InsufficientFunds();
    error TransferFailed();
    error ContractPaused();
    error ZeroAddress();
    
    // === Story Errors ===
    error StoryNotFound();
    error StoryAlreadyExists();
    error StoryComplete();
    error StoryAbandoned();
    error StoryNotAbandoned();
    error InvalidStoryTitle();
    error InvalidStoryCategory();
    error TooManyTags();
    error InvalidTag();
    error StoryNotActive();
    error OnlyCreator();
    error InsufficientChapters();
    
    // === Chapter Errors ===
    error ChapterNotFound();
    error InvalidChapterLength();
    error DuplicateContent();
    error ChapterAlreadyWinner();
    error ContentValidationFailed();
    error MaxProposalsReached();
    error SubmissionCooldownActive();
    error InvalidChapterNumber();
    
    // === Voting Errors ===
    error VotingNotActive();
    error VotingEnded();
    error AlreadyVoted();
    error CannotVoteOnOwnChapter();
    error CreatorCannotVoteEarly();
    error InsufficientVotes();
    error NoProposals();
    error VotingStillActive();
    error InvalidVoteWeight();
    
    // === Content Validation Errors ===
    error ProhibitedContent();
    error ContentTooShort();
    error ContentTooLong();
    error InvalidContentHash();
    error ContentHashExists();
    error BannedWordDetected();
    
    // === Reward Errors ===
    error NoRewardsToDistribute();
    error RewardCalculationFailed();
    error NoContributions();
    error RefundFailed();
    error InsufficientTreasuryFunds();
    error InvalidRewardPercentage();
    
    // === NFT Errors ===
    error TokenNotFound();
    error InvalidTokenURI();
    error MintingFailed();
    error NotTokenOwner();
    
    // === Fee Errors ===
    error InsufficientVotingFee();
    error InsufficientSubmissionFee();
    error InvalidFeeAmount();
    error FeeCalculationError();
    
    // === Time-based Errors ===
    error DeadlineNotReached();
    error DeadlinePassed();
    error InvalidTimeframe();
    error TooEarlyToFinalize();
    
    // === Access Control Errors ===
    error OnlyController();
    error OnlyRegistry();
    error OnlyVotingEngine();
    error OnlyRewardDistributor();
    error OnlyValidator();
    error OnlyChapterManager();
    error ContractNotAuthorized();
    
    // === System Errors ===
    error SystemNotInitialized();
    error InvalidConfiguration();
    error UpgradeNotAllowed();
    error EmergencyStopActive();
    error RateLimitExceeded();
}