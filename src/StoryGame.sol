// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StoryGame is ERC721, Ownable, ReentrancyGuard {
    
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
        string content;
        address author;
        uint256 votes;
        bool isWinner;
        uint256 timestamp;
        bytes32 contentHash; // For duplicate detection
    }
    
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
    
    // Vote structure for future enhancements
    struct Vote {
        address voter;
        uint256 chapterId;
        uint256 weight;
        uint256 timestamp;
    }
    
    // State variables
    uint256 public nextStoryId = 1;
    uint256 public nextChapterId = 1;
    uint256 public nextTokenId = 1;
    
    // Dynamic fee base rates
    uint256 public baseVotingFee = 0.001 ether;
    uint256 public baseSubmissionFee = 0.005 ether;
    uint256 public votingDuration = 7 days;
    
    // Economic constants
    uint256 public constant MAX_CHAPTER_LENGTH = 10000;
    uint256 public constant MIN_CHAPTER_LENGTH = 100;
    uint256 public constant SUBMISSION_COOLDOWN = 1 hours;
    uint256 public constant MAX_PROPOSALS_PER_AUTHOR = 1;
    uint256 public constant MIN_VOTES_TO_WIN = 3;
    uint256 public constant MAX_TAGS_PER_STORY = 5;
    uint256 public constant ABANDONMENT_PERIOD = 30 days;
    uint256 public constant TIE_BREAKER_EXTENSION = 3 days;
    
    // Reward distribution percentages (out of 10000 = 100%)
    uint256 public constant WINNER_SHARE = 4000; // 40%
    uint256 public constant CREATOR_SHARE = 2000; // 20%
    uint256 public constant VOTER_SHARE = 2500; // 25%
    uint256 public constant TREASURY_SHARE = 1500; // 15%
    
    // Economic bonuses
    uint256 public constant EARLY_VOTER_BONUS = 500; // 5% bonus for first 10 voters
    uint256 public constant COMPLETION_BONUS = 1000; // 10% bonus for completed stories
    uint256 public constant QUALITY_THRESHOLD = 10; // Votes needed for quality bonus
    uint256 public constant COMMUNITY_FAVORITE_THRESHOLD = 50; // Votes for community favorite status
    
    // Mappings
    mapping(uint256 => Story) public stories;
    mapping(uint256 => Chapter) public chapters;
    mapping(uint256 => uint256[]) public storyChapters;
    mapping(uint256 => uint256[]) public chapterProposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => uint256) public votingDeadlines;
    
    // Category and tag mappings
    mapping(StoryCategory => uint256[]) public storiesByCategory;
    mapping(string => uint256[]) public storiesByTag;
    mapping(bytes32 => bool) public contentHashExists; // Duplicate detection
    mapping(string => bool) public bannedWords; // Simple profanity filter
    
    // Tie-breaking and abandoned story tracking
    mapping(uint256 => uint256) public tieBreakCount; // How many tie extensions
    mapping(uint256 => uint256[]) public tiedChapters; // Chapters involved in current tie
    mapping(uint256 => uint256) public abandonedStoryRewards; // Claimable rewards
    
    // Security mappings
    mapping(uint256 => mapping(address => bool)) public hasSubmittedProposal;
    mapping(uint256 => mapping(address => uint256)) public authorSubmissionCount;
    mapping(address => uint256) public lastSubmissionTime;
    
    // Economic tracking
    mapping(uint256 => uint256) public storyPopularity;
    mapping(uint256 => mapping(address => uint256)) public voterContributions;
    mapping(uint256 => address[]) public storyVoters;
    mapping(uint256 => mapping(address => Vote)) public voteDetails;
    mapping(uint256 => uint256) public chapterVoteCount;
    mapping(address => uint256) public userTotalContributions;
    mapping(address => uint256) public userAccuracyScore; // For vote accuracy rewards
    mapping(uint256 => bool) public isCommunityFavorite; // Story community favorite status
    
    uint256 public treasuryBalance;
    
    // Events
    event StoryCreated(uint256 indexed storyId, string title, address creator, StoryCategory category);
    event ChapterSubmitted(uint256 indexed chapterId, uint256 indexed storyId, address author);
    event VoteCast(uint256 indexed chapterId, address voter, uint256 weight);
    event ChapterWon(uint256 indexed chapterId, uint256 indexed storyId, address author, uint256 reward);
    event StoryCompleted(uint256 indexed storyId, uint256 totalReward);
    event StoryAbandoned(uint256 indexed storyId, uint256 returnedReward);
    event VoterRewarded(uint256 indexed storyId, address voter, uint256 reward);
    event TreasuryUpdated(uint256 amount);
    event CommunityFavoriteAchieved(uint256 indexed storyId);
    event AccuracyBonusAwarded(address indexed voter, uint256 bonus);
    event TieDetected(uint256 indexed storyId, uint256[] tiedChapterIds);
    event DuplicateContentRejected(address author, bytes32 contentHash);
    
    constructor() ERC721("StoryChapter", "STORY") {
        // Initialize some basic banned words (in production, this would be more comprehensive)
        bannedWords[keccak256(bytes("badword1"))] = true;
        bannedWords[keccak256(bytes("badword2"))] = true;
    }
    
    // Content validation functions
    function _validateContent(string memory _content) internal view returns (bool) {
        // Basic profanity check (simplified - in production use more sophisticated filtering)
        string[] memory words = _splitWords(_content);
        for (uint256 i = 0; i < words.length; i++) {
            if (bannedWords[keccak256(bytes(_toLowerCase(words[i])))]) {
                return false;
            }
        }
        return true;
    }
    
    function _splitWords(string memory _str) internal pure returns (string[] memory) {
        // Simplified word splitting - in production use more robust parsing
        // This is a placeholder that would need proper implementation
        string[] memory words = new string[](1);
        words[0] = _str;
        return words;
    }
    
    function _toLowerCase(string memory _str) internal pure returns (string memory) {
        // Simplified - in production use proper case conversion
        return _str;
    }
    
    function _generateContentHash(string memory _content) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_content));
    }
    
    function _isValidTag(string memory _tag) internal pure returns (bool) {
        bytes memory tagBytes = bytes(_tag);
        return tagBytes.length > 0 && tagBytes.length <= 20;
    }
    
    // Economic helper functions
    function calculateVotingFee(uint256 _storyId) public view returns (uint256) {
        uint256 popularity = storyPopularity[_storyId];
        // Dynamic pricing: increases with popularity
        uint256 multiplier = 100 + (popularity / 10); // 1% increase per 10 votes
        return (baseVotingFee * multiplier) / 100;
    }
    
    function calculateSubmissionFee(uint256 _storyId) public view returns (uint256) {
        uint256 chapterCount = stories[_storyId].currentChapter;
        // Fee increases as story progresses
        uint256 multiplier = 100 + (chapterCount * 5); // 5% increase per chapter
        return (baseSubmissionFee * multiplier) / 100;
    }
    
    function isEarlyVoter(uint256 _chapterId) public view returns (bool) {
        return chapterVoteCount[_chapterId] < 10;
    }
    
    function hasQualityBonus(uint256 _chapterId) public view returns (bool) {
        return chapters[_chapterId].votes >= QUALITY_THRESHOLD;
    }
    
    function calculateVoterAccuracyBonus(address _voter) public view returns (uint256) {
        uint256 score = userAccuracyScore[_voter];
        if (score >= 80) return 1000; // 10% bonus for 80%+ accuracy
        if (score >= 60) return 500;  // 5% bonus for 60%+ accuracy
        if (score >= 40) return 250;  // 2.5% bonus for 40%+ accuracy
        return 0;
    }
    
    // Create a new story
    function createStory(
        string memory _title, 
        string memory _firstChapter,
        StoryCategory _category,
        string[] memory _tags
    ) external payable nonReentrant {
        require(msg.value >= baseSubmissionFee, "Insufficient submission fee");
        require(bytes(_title).length > 0 && bytes(_title).length <= 200, "Invalid title length");
        require(bytes(_firstChapter).length >= MIN_CHAPTER_LENGTH && 
                bytes(_firstChapter).length <= MAX_CHAPTER_LENGTH, "Invalid chapter length");
        require(_tags.length <= MAX_TAGS_PER_STORY, "Too many tags");
        
        // Validate content
        require(_validateContent(_firstChapter), "Content contains prohibited words");
        
        // Check for duplicate content
        bytes32 contentHash = _generateContentHash(_firstChapter);
        require(!contentHashExists[contentHash], "Duplicate content detected");
        
        // Validate tags
        for (uint256 i = 0; i < _tags.length; i++) {
            require(_isValidTag(_tags[i]), "Invalid tag");
        }
        
        uint256 storyId = nextStoryId++;
        
        stories[storyId] = Story({
            id: storyId,
            title: _title,
            creator: msg.sender,
            currentChapter: 1,
            isComplete: false,
            totalReward: msg.value,
            createdAt: block.timestamp,
            lastActivityTime: block.timestamp,
            category: _category,
            tags: _tags,
            isAbandoned: false
        });
        
        uint256 chapterId = nextChapterId++;
        chapters[chapterId] = Chapter({
            id: chapterId,
            storyId: storyId,
            chapterNumber: 1,
            content: _firstChapter,
            author: msg.sender,
            votes: 0,
            isWinner: true,
            timestamp: block.timestamp,
            contentHash: contentHash
        });
        
        storyChapters[storyId].push(chapterId);
        contentHashExists[contentHash] = true;
        
        // Index by category and tags
        storiesByCategory[_category].push(storyId);
        for (uint256 i = 0; i < _tags.length; i++) {
            storiesByTag[_tags[i]].push(storyId);
        }
        
        // Mint NFT for first chapter
        _mint(msg.sender, nextTokenId++);
        
        lastSubmissionTime[msg.sender] = block.timestamp;
        
        emit StoryCreated(storyId, _title, msg.sender, _category);
        emit ChapterSubmitted(chapterId, storyId, msg.sender);
    }
    
    // Submit a chapter proposal
    function submitChapterProposal(uint256 _storyId, string memory _content) external payable nonReentrant {
        uint256 requiredFee = calculateSubmissionFee(_storyId);
        require(msg.value >= requiredFee, "Insufficient submission fee");
        require(stories[_storyId].id != 0, "Story does not exist");
        require(!stories[_storyId].isComplete, "Story is complete");
        require(!stories[_storyId].isAbandoned, "Story is abandoned");
        require(bytes(_content).length >= MIN_CHAPTER_LENGTH && 
                bytes(_content).length <= MAX_CHAPTER_LENGTH, "Invalid chapter length");
        
        // Validate content
        require(_validateContent(_content), "Content contains prohibited words");
        
        // Check for duplicate content
        bytes32 contentHash = _generateContentHash(_content);
        if (contentHashExists[contentHash]) {
            emit DuplicateContentRejected(msg.sender, contentHash);
            revert("Duplicate content detected");
        }
        
        // Rate limiting
        require(block.timestamp >= lastSubmissionTime[msg.sender] + SUBMISSION_COOLDOWN, 
                "Submission cooldown active");
        
        // Limit proposals per author
        require(authorSubmissionCount[_storyId][msg.sender] < MAX_PROPOSALS_PER_AUTHOR,
                "Max proposals reached");
        
        // Start or check voting period
        if (votingDeadlines[_storyId] == 0) {
            votingDeadlines[_storyId] = block.timestamp + votingDuration;
        } else {
            require(block.timestamp < votingDeadlines[_storyId], "Voting period ended");
        }
        
        uint256 chapterId = nextChapterId++;
        chapters[chapterId] = Chapter({
            id: chapterId,
            storyId: _storyId,
            chapterNumber: stories[_storyId].currentChapter + 1,
            content: _content,
            author: msg.sender,
            votes: 0,
            isWinner: false,
            timestamp: block.timestamp,
            contentHash: contentHash
        });
        
        chapterProposals[_storyId].push(chapterId);
        stories[_storyId].totalReward += msg.value;
        stories[_storyId].lastActivityTime = block.timestamp;
        contentHashExists[contentHash] = true;
        
        hasSubmittedProposal[_storyId][msg.sender] = true;
        authorSubmissionCount[_storyId][msg.sender]++;
        lastSubmissionTime[msg.sender] = block.timestamp;
        userTotalContributions[msg.sender] += msg.value;
        
        emit ChapterSubmitted(chapterId, _storyId, msg.sender);
    }
    
    // Vote on a chapter
    function voteOnChapter(uint256 _chapterId) external payable nonReentrant {
        Chapter memory chapter = chapters[_chapterId];
        uint256 storyId = chapter.storyId;
        uint256 requiredFee = calculateVotingFee(storyId);
        
        require(msg.value >= requiredFee, "Insufficient voting fee");
        require(chapter.id != 0, "Chapter does not exist");
        require(!chapter.isWinner, "Cannot vote on winning chapter");
        require(!hasVoted[_chapterId][msg.sender], "Already voted");
        require(block.timestamp < votingDeadlines[storyId], "Voting ended");
        require(!stories[storyId].isAbandoned, "Story is abandoned");
        
        // Security checks
        require(chapter.author != msg.sender, "Cannot vote on own chapter");
        if (stories[storyId].currentChapter <= 2) {
            require(stories[storyId].creator != msg.sender, "Creator cannot vote early");
        }
        
        // Record vote with details
        voteDetails[_chapterId][msg.sender] = Vote({
            voter: msg.sender,
            chapterId: _chapterId,
            weight: 1,
            timestamp: block.timestamp
        });
        
        hasVoted[_chapterId][msg.sender] = true;
        chapters[_chapterId].votes++;
        chapterVoteCount[_chapterId]++;
        
        storyPopularity[storyId]++;
        voterContributions[storyId][msg.sender] += msg.value;
        userTotalContributions[msg.sender] += msg.value;
        
        if (voterContributions[storyId][msg.sender] == msg.value) {
            storyVoters[storyId].push(msg.sender);
        }
        
        stories[storyId].totalReward += msg.value;
        stories[storyId].lastActivityTime = block.timestamp;
        
        // Check for community favorite status
        if (storyPopularity[storyId] >= COMMUNITY_FAVORITE_THRESHOLD && !isCommunityFavorite[storyId]) {
            isCommunityFavorite[storyId] = true;
            emit CommunityFavoriteAchieved(storyId);
        }
        
        emit VoteCast(_chapterId, msg.sender, 1);
    }
    
    // Finalize voting and distribute rewards
    function finalizeVoting(uint256 _storyId) external nonReentrant {
        require(stories[_storyId].id != 0, "Story does not exist");
        require(!stories[_storyId].isAbandoned, "Story is abandoned");
        require(block.timestamp >= votingDeadlines[_storyId], "Voting still active");
        require(votingDeadlines[_storyId] != 0, "No voting in progress");
        
        uint256[] memory proposals = chapterProposals[_storyId];
        require(proposals.length > 0, "No proposals");
        
        // Find chapters with highest votes
        uint256 maxVotes = 0;
        uint256[] memory topChapters = new uint256[](proposals.length);
        uint256 topCount = 0;
        
        // First pass: find max votes
        for (uint256 i = 0; i < proposals.length; i++) {
            if (chapters[proposals[i]].votes > maxVotes) {
                maxVotes = chapters[proposals[i]].votes;
            }
        }
        
        require(maxVotes >= MIN_VOTES_TO_WIN, "Insufficient votes");
        
        // Second pass: collect all chapters with max votes
        for (uint256 i = 0; i < proposals.length; i++) {
            if (chapters[proposals[i]].votes == maxVotes) {
                topChapters[topCount] = proposals[i];
                topCount++;
            }
        }
        
        // Handle ties
        if (topCount > 1) {
            // Check if we've already extended for ties too many times
            if (tieBreakCount[_storyId] >= 3) {
                // After 3 extensions, use timestamp as tiebreaker (earliest submission wins)
                uint256 winningChapterId = topChapters[0];
                uint256 earliestTime = chapters[topChapters[0]].timestamp;
                
                for (uint256 i = 1; i < topCount; i++) {
                    if (chapters[topChapters[i]].timestamp < earliestTime) {
                        earliestTime = chapters[topChapters[i]].timestamp;
                        winningChapterId = topChapters[i];
                    }
                }
                
                _processWinningChapter(_storyId, winningChapterId);
            } else {
                // Extend voting for tied chapters only
                votingDeadlines[_storyId] = block.timestamp + TIE_BREAKER_EXTENSION;
                tieBreakCount[_storyId]++;
                
                // Store tied chapters for reference
                delete tiedChapters[_storyId];
                for (uint256 i = 0; i < topCount; i++) {
                    tiedChapters[_storyId].push(topChapters[i]);
                }
                
                emit TieDetected(_storyId, tiedChapters[_storyId]);
                return;
            }
        } else {
            // Clear winner
            _processWinningChapter(_storyId, topChapters[0]);
        }
    }
    
    // Process winning chapter (extracted for clarity)
    function _processWinningChapter(uint256 _storyId, uint256 _winningChapterId) internal {
        // Update state
        chapters[_winningChapterId].isWinner = true;
        storyChapters[_storyId].push(_winningChapterId);
        stories[_storyId].currentChapter++;
        stories[_storyId].lastActivityTime = block.timestamp;
        
        // Calculate rewards
        uint256 totalReward = stories[_storyId].totalReward;
        uint256 winnerReward = (totalReward * WINNER_SHARE) / 10000;
        uint256 voterPool = (totalReward * VOTER_SHARE) / 10000;
        uint256 treasuryAmount = (totalReward * TREASURY_SHARE) / 10000;
        uint256 creatorAmount = (totalReward * CREATOR_SHARE) / 10000;
        
        // Apply quality bonus
        if (hasQualityBonus(_winningChapterId)) {
            uint256 qualityBonus = (winnerReward * 500) / 10000;
            winnerReward += qualityBonus;
        }
        
        // Apply community favorite bonus
        if (isCommunityFavorite[_storyId]) {
            uint256 communityBonus = (winnerReward * 300) / 10000;
            winnerReward += communityBonus;
        }
        
        // Update treasury
        treasuryBalance += treasuryAmount;
        
        // Store creator's share
        stories[_storyId].totalReward = creatorAmount;
        
        // Update voter accuracy
        _updateVoterAccuracy(chapterProposals[_storyId], _winningChapterId);
        
        // Reset for next round
        _resetVotingRound(_storyId);
        
        // Mint NFT
        _mint(chapters[_winningChapterId].author, nextTokenId++);
        
        // Distribute rewards
        _distributeVoterRewards(_storyId, voterPool);
        
        // Pay winner
        (bool success, ) = payable(chapters[_winningChapterId].author).call{value: winnerReward}("");
        require(success, "Winner payment failed");
        
        emit ChapterWon(_winningChapterId, _storyId, chapters[_winningChapterId].author, winnerReward);
        emit TreasuryUpdated(treasuryAmount);
    }
    
    // Update voter accuracy scores
    function _updateVoterAccuracy(uint256[] memory proposals, uint256 winningChapterId) internal {
        uint256 totalVoters;
        uint256 correctVoters;
        
        for (uint256 i = 0; i < proposals.length; i++) {
            uint256 chapterId = proposals[i];
            address[] memory voters = _getChapterVoters(chapterId);
            
            for (uint256 j = 0; j < voters.length; j++) {
                totalVoters++;
                if (chapterId == winningChapterId) {
                    correctVoters++;
                    // Update individual accuracy
                    uint256 currentScore = userAccuracyScore[voters[j]];
                    userAccuracyScore[voters[j]] = (currentScore * 4 + 100) / 5; // Moving average
                } else {
                    uint256 currentScore = userAccuracyScore[voters[j]];
                    userAccuracyScore[voters[j]] = (currentScore * 4) / 5; // Decay incorrect votes
                }
            }
        }
    }
    
    // Get voters for a chapter (helper function)
    function _getChapterVoters(uint256 _chapterId) internal view returns (address[] memory) {
        // This is simplified - in production, you'd maintain a proper voter list per chapter
        uint256 count = chapterVoteCount[_chapterId];
        address[] memory voters = new address[](count);
        // Implementation would fill this array
        return voters;
    }
    
    // Distribute voter rewards
    function _distributeVoterRewards(uint256 _storyId, uint256 _voterPool) internal {
        address[] memory voters = storyVoters[_storyId];
        uint256 totalContributions;
        
        for (uint256 i = 0; i < voters.length; i++) {
            totalContributions += voterContributions[_storyId][voters[i]];
        }
        
        if (totalContributions == 0) return;
        
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            uint256 contribution = voterContributions[_storyId][voter];
            uint256 baseReward = (_voterPool * contribution) / totalContributions;
            
            // Apply accuracy bonus
            uint256 accuracyBonus = calculateVoterAccuracyBonus(voter);
            uint256 finalReward = baseReward + (baseReward * accuracyBonus) / 10000;
            
            if (finalReward > 0) {
                (bool success, ) = payable(voter).call{value: finalReward}("");
                if (success) {
                    emit VoterRewarded(_storyId, voter, finalReward);
                    if (accuracyBonus > 0) {
                        emit AccuracyBonusAwarded(voter, accuracyBonus);
                    }
                }
            }
        }
    }
    
    // Reset voting round
    function _resetVotingRound(uint256 _storyId) internal {
        uint256[] memory proposals = chapterProposals[_storyId];
        for (uint256 i = 0; i < proposals.length; i++) {
            address author = chapters[proposals[i]].author;
            hasSubmittedProposal[_storyId][author] = false;
            authorSubmissionCount[_storyId][author] = 0;
        }
        delete chapterProposals[_storyId];
        delete votingDeadlines[_storyId];
        delete tiedChapters[_storyId];
        tieBreakCount[_storyId] = 0;
    }
    
    // Check and mark abandoned stories
    function checkAbandonedStory(uint256 _storyId) external {
        require(stories[_storyId].id != 0, "Story does not exist");
        require(!stories[_storyId].isComplete, "Story is complete");
        require(!stories[_storyId].isAbandoned, "Already marked abandoned");
        require(
            block.timestamp >= stories[_storyId].lastActivityTime + ABANDONMENT_PERIOD,
            "Story still active"
        );
        
        stories[_storyId].isAbandoned = true;
        
        // Calculate refunds
        uint256 totalReward = stories[_storyId].totalReward;
        if (totalReward > 0) {
            // Return funds to treasury for redistribution
            abandonedStoryRewards[_storyId] = totalReward;
            treasuryBalance += totalReward;
            stories[_storyId].totalReward = 0;
            
            emit StoryAbandoned(_storyId, totalReward);
            emit TreasuryUpdated(totalReward);
        }
    }
    
    // Allow voters to claim proportional refunds from abandoned stories
    function claimAbandonedStoryRefund(uint256 _storyId) external nonReentrant {
        require(stories[_storyId].isAbandoned, "Story not abandoned");
        require(voterContributions[_storyId][msg.sender] > 0, "No contributions");
        require(abandonedStoryRewards[_storyId] > 0, "No rewards to claim");
        
        uint256 totalContributions = 0;
        address[] memory voters = storyVoters[_storyId];
        
        for (uint256 i = 0; i < voters.length; i++) {
            totalContributions += voterContributions[_storyId][voters[i]];
        }
        
        uint256 userShare = (abandonedStoryRewards[_storyId] * voterContributions[_storyId][msg.sender]) / totalContributions;
        
        // Reset user's contribution to prevent double claims
        voterContributions[_storyId][msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: userShare}("");
        require(success, "Refund failed");
        
        emit VoterRewarded(_storyId, msg.sender, userShare);
    }
    
    // Complete story
    function completeStory(uint256 _storyId) external nonReentrant {
        require(stories[_storyId].creator == msg.sender, "Only creator");
        require(!stories[_storyId].isComplete, "Already complete");
        require(stories[_storyId].currentChapter >= 3, "Need 3+ chapters");
        
        stories[_storyId].isComplete = true;
        
        uint256 creatorReward = stories[_storyId].totalReward;
        
        // Apply completion bonus for longer stories
        if (stories[_storyId].currentChapter >= 5) {
            uint256 completionBonus = (creatorReward * COMPLETION_BONUS) / 10000;
            creatorReward += completionBonus;
        }
        
        if (creatorReward > 0) {
            stories[_storyId].totalReward = 0;
            (bool success, ) = payable(msg.sender).call{value: creatorReward}("");
            require(success, "Payment failed");
        }
        
        emit StoryCompleted(_storyId, creatorReward);
    }
    
    // View functions
    function getStory(uint256 _storyId) external view returns (Story memory) {
        return stories[_storyId];
    }
    
    function getChapter(uint256 _chapterId) external view returns (Chapter memory) {
        return chapters[_chapterId];
    }
    
    function getStoryChapters(uint256 _storyId) external view returns (uint256[] memory) {
        return storyChapters[_storyId];
    }
    
    function getCurrentProposals(uint256 _storyId) external view returns (uint256[] memory) {
        return chapterProposals[_storyId];
    }
    
    function getStoriesByCategory(StoryCategory _category) external view returns (uint256[] memory) {
        return storiesByCategory[_category];
    }
    
    function getStoriesByTag(string memory _tag) external view returns (uint256[] memory) {
        return storiesByTag[_tag];
    }
    
    function getTiedChapters(uint256 _storyId) external view returns (uint256[] memory) {
        return tiedChapters[_storyId];
    }
    
    function isStoryAbandoned(uint256 _storyId) external view returns (bool) {
        return stories[_storyId].isAbandoned || 
               (block.timestamp >= stories[_storyId].lastActivityTime + ABANDONMENT_PERIOD && 
                !stories[_storyId].isComplete);
    }
    
    function getStoryTags(uint256 _storyId) external view returns (string[] memory) {
        return stories[_storyId].tags;
    }
    
    function getStoryEconomics(uint256 _storyId) external view returns (
        uint256 totalReward,
        uint256 popularity,
        uint256 currentVotingFee,
        uint256 currentSubmissionFee,
        uint256 voterCount,
        bool communityFavorite
    ) {
        totalReward = stories[_storyId].totalReward;
        popularity = storyPopularity[_storyId];
        currentVotingFee = calculateVotingFee(_storyId);
        currentSubmissionFee = calculateSubmissionFee(_storyId);
        voterCount = storyVoters[_storyId].length;
        communityFavorite = isCommunityFavorite[_storyId];
    }
    
    function getUserStats(address _user) external view returns (
        uint256 totalContributed,
        uint256 accuracyScore,
        uint256 accuracyBonus
    ) {
        totalContributed = userTotalContributions[_user];
        accuracyScore = userAccuracyScore[_user];
        accuracyBonus = calculateVoterAccuracyBonus(_user);
    }
    
    // Admin functions
    function updateBaseFees(uint256 _votingFee, uint256 _submissionFee) external onlyOwner {
        baseVotingFee = _votingFee;
        baseSubmissionFee = _submissionFee;
    }
    
    function updateVotingDuration(uint256 _duration) external onlyOwner {
        votingDuration = _duration;
    }
    
    function addBannedWord(string memory _word) external onlyOwner {
        bannedWords[keccak256(bytes(_toLowerCase(_word)))] = true;
    }
    
    function removeBannedWord(string memory _word) external onlyOwner {
        bannedWords[keccak256(bytes(_toLowerCase(_word)))] = false;
    }
    
    function withdrawTreasury(uint256 _amount) external onlyOwner {
        require(_amount <= treasuryBalance, "Insufficient treasury");
        treasuryBalance -= _amount;
        payable(owner()).transfer(_amount);
    }
    
    function emergencyPause(uint256 _storyId) external onlyOwner {
        // Emergency function to pause a problematic story
        stories[_storyId].isAbandoned = true;
        emit StoryAbandoned(_storyId, 0);
    }
}