// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IStoryGameRegistry.sol";
import "./interfaces/IContentValidator.sol";
import "./StoryGameTypes.sol";
import "./Errors.sol";

/**
 * @title ChapterManager
 * @dev Manages chapter content, submissions, and proposals
 * @author StoryGame Team
 */
contract ChapterManager is Ownable, ReentrancyGuard, Pausable {
    using StoryGameTypes for *;

    // State variables
    IStoryGameRegistry public immutable storyRegistry;
    IContentValidator public contentValidator;
    
    uint256 public nextChapterId = 1;
    uint256 public constant MAX_CHAPTER_LENGTH = 10000;
    uint256 public constant MIN_CHAPTER_LENGTH = 100;
    uint256 public constant SUBMISSION_COOLDOWN = 1 hours;
    uint256 public constant MAX_PROPOSALS_PER_AUTHOR = 1;

    // Mappings
    mapping(uint256 => StoryGameTypes.Chapter) public chapters;
    mapping(uint256 => uint256[]) public storyChapters; // storyId => chapterIds
    mapping(uint256 => uint256[]) public chapterProposals; // storyId => proposalIds
    mapping(bytes32 => bool) public contentHashExists;
    mapping(uint256 => mapping(address => bool)) public hasSubmittedProposal;
    mapping(uint256 => mapping(address => uint256)) public authorSubmissionCount;
    mapping(address => uint256) public lastSubmissionTime;
    mapping(uint256 => string) private chapterContent; // chapterId => IPFS hash or content
    mapping(uint256 => mapping(address => uint256)) public authorProposalTimestamp;

    // Events
    event ChapterCreated(
        uint256 indexed chapterId,
        uint256 indexed storyId,
        address indexed author,
        uint256 chapterNumber,
        bytes32 contentHash
    );
    
    event ChapterProposalSubmitted(
        uint256 indexed chapterId,
        uint256 indexed storyId,
        address indexed author,
        uint256 chapterNumber
    );
    
    event ChapterContentUpdated(uint256 indexed chapterId, string newContentHash);
    event ChapterMarkedAsWinner(uint256 indexed chapterId, uint256 indexed storyId);
    event ProposalRemoved(uint256 indexed chapterId, uint256 indexed storyId);
    event ContentValidatorUpdated(address oldValidator, address newValidator);
    event DuplicateContentRejected(address indexed author, bytes32 contentHash);

    // Modifiers
    modifier onlyController() {
        if (msg.sender != storyRegistry.controller()) {
            revert StoryGameErrors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier validStory(uint256 _storyId) {
        if (!storyRegistry.storyExists(_storyId)) {
            revert StoryGameErrors.StoryNotFound(_storyId);
        }
        _;
    }

    modifier validChapter(uint256 _chapterId) {
        if (chapters[_chapterId].id == 0) {
            revert StoryGameErrors.ChapterNotFound(_chapterId);
        }
        _;
    }

    constructor(
        address _storyRegistry,
        address _contentValidator
    ) {
        if (_storyRegistry == address(0) || _contentValidator == address(0)) {
            revert StoryGameErrors.ZeroAddress();
        }
        
        storyRegistry = IStoryGameRegistry(_storyRegistry);
        contentValidator = IContentValidator(_contentValidator);
    }

    /**
     * @dev Creates the first chapter when a story is created
     * @param _storyId The ID of the story
     * @param _content The chapter content
     * @param _author The author of the chapter
     * @return chapterId The ID of the created chapter
     */
    function createFirstChapter(
        uint256 _storyId,
        string calldata _content,
        address _author
    ) external onlyController validStory(_storyId) returns (uint256) {
        if (bytes(_content).length < MIN_CHAPTER_LENGTH || 
            bytes(_content).length > MAX_CHAPTER_LENGTH) {
            revert StoryGameErrors.InvalidContentLength(
                bytes(_content).length, 
                MIN_CHAPTER_LENGTH, 
                MAX_CHAPTER_LENGTH
            );
        }

        // Validate content
        if (!contentValidator.validateContent(_content)) {
            revert StoryGameErrors.ContentValidationFailed();
        }

        // Check for duplicate content
        bytes32 contentHash = _generateContentHash(_content);
        if (contentHashExists[contentHash]) {
            emit DuplicateContentRejected(_author, contentHash);
            revert StoryGameErrors.DuplicateContent(contentHash);
        }

        uint256 chapterId = nextChapterId++;
        
        chapters[chapterId] = StoryGameTypes.Chapter({
            id: chapterId,
            storyId: _storyId,
            chapterNumber: 1,
            author: _author,
            votes: 0,
            isWinner: true,
            timestamp: block.timestamp,
            contentHash: contentHash,
            ipfsHash: ""
        });

        storyChapters[_storyId].push(chapterId);
        chapterContent[chapterId] = _content;
        contentHashExists[contentHash] = true;
        lastSubmissionTime[_author] = block.timestamp;

        emit ChapterCreated(chapterId, _storyId, _author, 1, contentHash);
        
        return chapterId;
    }

    /**
     * @dev Submits a chapter proposal for voting
     * @param _storyId The ID of the story
     * @param _content The chapter content
     * @param _author The author of the proposal
     * @return chapterId The ID of the created chapter proposal
     */
    function submitChapterProposal(
        uint256 _storyId,
        string calldata _content,
        address _author
    ) external onlyController validStory(_storyId) nonReentrant whenNotPaused returns (uint256) {
        
        // Get story info from registry
        (,,,uint256 currentChapter, bool isComplete,,,, bool isAbandoned) = storyRegistry.getStoryInfo(_storyId);
        
        if (isComplete) {
            revert StoryGameErrors.StoryAlreadyComplete(_storyId);
        }
        
        if (isAbandoned) {
            revert StoryGameErrors.StoryAbandoned(_storyId);
        }

        // Validate content length
        if (bytes(_content).length < MIN_CHAPTER_LENGTH || 
            bytes(_content).length > MAX_CHAPTER_LENGTH) {
            revert StoryGameErrors.InvalidContentLength(
                bytes(_content).length, 
                MIN_CHAPTER_LENGTH, 
                MAX_CHAPTER_LENGTH
            );
        }

        // Validate content
        if (!contentValidator.validateContent(_content)) {
            revert StoryGameErrors.ContentValidationFailed();
        }

        // Check for duplicate content
        bytes32 contentHash = _generateContentHash(_content);
        if (contentHashExists[contentHash]) {
            emit DuplicateContentRejected(_author, contentHash);
            revert StoryGameErrors.DuplicateContent(contentHash);
        }

        // Rate limiting check
        if (block.timestamp < lastSubmissionTime[_author] + SUBMISSION_COOLDOWN) {
            revert StoryGameErrors.SubmissionCooldownActive(
                lastSubmissionTime[_author] + SUBMISSION_COOLDOWN
            );
        }

        // Check max proposals per author
        if (authorSubmissionCount[_storyId][_author] >= MAX_PROPOSALS_PER_AUTHOR) {
            revert StoryGameErrors.MaxProposalsReached(_author, MAX_PROPOSALS_PER_AUTHOR);
        }

        uint256 chapterId = nextChapterId++;
        uint256 nextChapterNumber = currentChapter + 1;

        chapters[chapterId] = StoryGameTypes.Chapter({
            id: chapterId,
            storyId: _storyId,
            chapterNumber: nextChapterNumber,
            author: _author,
            votes: 0,
            isWinner: false,
            timestamp: block.timestamp,
            contentHash: contentHash,
            ipfsHash: ""
        });

        chapterProposals[_storyId].push(chapterId);
        chapterContent[chapterId] = _content;
        contentHashExists[contentHash] = true;
        
        hasSubmittedProposal[_storyId][_author] = true;
        authorSubmissionCount[_storyId][_author]++;
        authorProposalTimestamp[_storyId][_author] = block.timestamp;
        lastSubmissionTime[_author] = block.timestamp;

        emit ChapterProposalSubmitted(chapterId, _storyId, _author, nextChapterNumber);
        
        return chapterId;
    }

    /**
     * @dev Marks a chapter as the winner after voting
     * @param _chapterId The ID of the winning chapter
     */
    function markChapterAsWinner(uint256 _chapterId) 
        external 
        onlyController 
        validChapter(_chapterId) 
    {
        StoryGameTypes.Chapter storage chapter = chapters[_chapterId];
        
        if (chapter.isWinner) {
            revert StoryGameErrors.ChapterAlreadyWinner(_chapterId);
        }

        chapter.isWinner = true;
        storyChapters[chapter.storyId].push(_chapterId);

        emit ChapterMarkedAsWinner(_chapterId, chapter.storyId);
    }

    /**
     * @dev Updates chapter votes (called by VotingEngine)
     * @param _chapterId The ID of the chapter
     * @param _newVoteCount The new vote count
     */
    function updateChapterVotes(uint256 _chapterId, uint256 _newVoteCount) 
        external 
        onlyController 
        validChapter(_chapterId) 
    {
        chapters[_chapterId].votes = _newVoteCount;
    }

    /**
     * @dev Resets chapter proposals after voting round
     * @param _storyId The ID of the story
     */
    function resetChapterProposals(uint256 _storyId) 
        external 
        onlyController 
        validStory(_storyId) 
    {
        uint256[] memory proposals = chapterProposals[_storyId];
        
        for (uint256 i = 0; i < proposals.length; i++) {
            uint256 chapterId = proposals[i];
            address author = chapters[chapterId].author;
            
            hasSubmittedProposal[_storyId][author] = false;
            authorSubmissionCount[_storyId][author] = 0;
            authorProposalTimestamp[_storyId][author] = 0;
        }
        
        delete chapterProposals[_storyId];
    }

    /**
     * @dev Updates IPFS hash for a chapter (for off-chain storage)
     * @param _chapterId The ID of the chapter
     * @param _ipfsHash The IPFS hash of the content
     */
    function updateChapterIPFSHash(uint256 _chapterId, string calldata _ipfsHash) 
        external 
        onlyController 
        validChapter(_chapterId) 
    {
        chapters[_chapterId].ipfsHash = _ipfsHash;
        emit ChapterContentUpdated(_chapterId, _ipfsHash);
    }

    /**
     * @dev Removes a chapter proposal (in case of violations)
     * @param _chapterId The ID of the chapter to remove
     */
    function removeChapterProposal(uint256 _chapterId) 
        external 
        onlyController 
        validChapter(_chapterId) 
    {
        StoryGameTypes.Chapter memory chapter = chapters[_chapterId];
        
        if (chapter.isWinner) {
            revert StoryGameErrors.CannotRemoveWinningChapter(_chapterId);
        }

        // Remove from proposals array
        uint256[] storage proposals = chapterProposals[chapter.storyId];
        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i] == _chapterId) {
                proposals[i] = proposals[proposals.length - 1];
                proposals.pop();
                break;
            }
        }

        // Clean up author submission tracking
        hasSubmittedProposal[chapter.storyId][chapter.author] = false;
        if (authorSubmissionCount[chapter.storyId][chapter.author] > 0) {
            authorSubmissionCount[chapter.storyId][chapter.author]--;
        }

        // Remove content hash
        contentHashExists[chapter.contentHash] = false;
        
        // Clear chapter data
        delete chapters[_chapterId];
        delete chapterContent[_chapterId];

        emit ProposalRemoved(_chapterId, chapter.storyId);
    }

    // View Functions

    /**
     * @dev Gets chapter information
     * @param _chapterId The ID of the chapter
     * @return chapter The chapter struct
     */
    function getChapter(uint256 _chapterId) 
        external 
        view 
        validChapter(_chapterId) 
        returns (StoryGameTypes.Chapter memory) 
    {
        return chapters[_chapterId];
    }

    /**
     * @dev Gets chapter content
     * @param _chapterId The ID of the chapter
     * @return content The chapter content
     */
    function getChapterContent(uint256 _chapterId) 
        external 
        view 
        validChapter(_chapterId) 
        returns (string memory) 
    {
        return chapterContent[_chapterId];
    }

    /**
     * @dev Gets all chapters for a story
     * @param _storyId The ID of the story
     * @return chapterIds Array of chapter IDs
     */
    function getStoryChapters(uint256 _storyId) 
        external 
        view 
        validStory(_storyId) 
        returns (uint256[] memory) 
    {
        return storyChapters[_storyId];
    }

    /**
     * @dev Gets current proposals for a story
     * @param _storyId The ID of the story
     * @return proposalIds Array of proposal IDs
     */
    function getCurrentProposals(uint256 _storyId) 
        external 
        view 
        validStory(_storyId) 
        returns (uint256[] memory) 
    {
        return chapterProposals[_storyId];
    }

    /**
     * @dev Gets detailed proposal information for a story
     * @param _storyId The ID of the story
     * @return proposals Array of chapter structs
     */
    function getProposalDetails(uint256 _storyId) 
        external 
        view 
        validStory(_storyId) 
        returns (StoryGameTypes.Chapter[] memory) 
    {
        uint256[] memory proposalIds = chapterProposals[_storyId];
        StoryGameTypes.Chapter[] memory proposals = new StoryGameTypes.Chapter[](proposalIds.length);
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            proposals[i] = chapters[proposalIds[i]];
        }
        
        return proposals;
    }

    /**
     * @dev Checks if an author can submit a proposal
     * @param _storyId The ID of the story
     * @param _author The author address
     * @return canSubmit Whether the author can submit
     * @return reason Reason if they cannot submit
     */
    function canAuthorSubmitProposal(uint256 _storyId, address _author) 
        external 
        view 
        validStory(_storyId) 
        returns (bool canSubmit, string memory reason) 
    {
        // Check cooldown
        if (block.timestamp < lastSubmissionTime[_author] + SUBMISSION_COOLDOWN) {
            return (false, "Submission cooldown active");
        }

        // Check max proposals
        if (authorSubmissionCount[_storyId][_author] >= MAX_PROPOSALS_PER_AUTHOR) {
            return (false, "Maximum proposals reached");
        }

        // Check if story is complete or abandoned
        (,,,, bool isComplete,,,, bool isAbandoned) = storyRegistry.getStoryInfo(_storyId);
        if (isComplete) {
            return (false, "Story is complete");
        }
        if (isAbandoned) {
            return (false, "Story is abandoned");
        }

        return (true, "");
    }

    /**
     * @dev Gets the number of chapters in a story
     * @param _storyId The ID of the story
     * @return count The number of chapters
     */
    function getStoryChapterCount(uint256 _storyId) 
        external 
        view 
        validStory(_storyId) 
        returns (uint256) 
    {
        return storyChapters[_storyId].length;
    }

    /**
     * @dev Gets the number of active proposals for a story
     * @param _storyId The ID of the story
     * @return count The number of proposals
     */
    function getProposalCount(uint256 _storyId) 
        external 
        view 
        validStory(_storyId) 
        returns (uint256) 
    {
        return chapterProposals[_storyId].length;
    }

    /**
     * @dev Checks if content hash already exists
     * @param _contentHash The content hash to check
     * @return exists Whether the hash exists
     */
    function doesContentHashExist(bytes32 _contentHash) 
        external 
        view 
        returns (bool) 
    {
        return contentHashExists[_contentHash];
    }

    // Admin Functions

    /**
     * @dev Updates the content validator contract
     * @param _newValidator The new validator contract address
     */
    function updateContentValidator(address _newValidator) external onlyOwner {
        if (_newValidator == address(0)) {
            revert StoryGameErrors.ZeroAddress();
        }
        
        address oldValidator = address(contentValidator);
        contentValidator = IContentValidator(_newValidator);
        
        emit ContentValidatorUpdated(oldValidator, _newValidator);
    }

    /**
     * @dev Emergency pause function
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause function
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // --------------------------------------------------
    // Controller-only setters for VotingEngine
    // --------------------------------------------------
    function updateChapterVotes(uint256 _chapterId, uint256 _newVoteCount)
        external
        onlyController
        validChapter(_chapterId)
    {
        chapters[_chapterId].votes = _newVoteCount;
    }

    function markChapterAsWinner(uint256 _chapterId)
        external
        onlyController
        validChapter(_chapterId)
    {
        StoryGameTypes.Chapter storage ch = chapters[_chapterId];
        ch.isWinner = true;
        emit ChapterMarkedAsWinner(_chapterId, ch.storyId);
    }

    function resetChapterProposals(uint256 _storyId) external onlyController validStory(_storyId) {
        delete chapterProposals[_storyId];
    }

    // Internal Functions

    /**
     * @dev Generates a hash for content to detect duplicates
     * @param _content The content to hash
     * @return contentHash The generated hash
     */
    function _generateContentHash(string calldata _content) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_content));
    }
}