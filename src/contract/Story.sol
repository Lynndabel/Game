// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// // Interfaces
// interface IStoryFactory {
//     function updateStoryStats(uint256 storyId, uint256 totalChapters, uint256 totalCollectors) external;
// }

// interface IChapterManager {
//     function getChapterStatus(uint256 storyId, uint256 chapterId) external view returns (uint8);
//     function getChapterPath(uint256 storyId, uint256 chapterId) external view returns (uint256[] memory);
// }

// interface IVotingManager {
//     function startChapterVoting(uint256 storyId, uint256 chapterId, uint256 duration) external;
//     function getVotingResults(uint256 storyId, uint256 chapterId) external view returns (bool, uint256);
// }

// interface IChapterNFT {
//     function mintChapter(address to, uint256 storyId, uint256 chapterId, string memory uri) external returns (uint256);
//     function getChapterOwner(uint256 storyId, uint256 chapterId) external view returns (address);
// }

// interface IRevenueDistribution {
//     function distributeChapterRevenue(uint256 storyId, uint256 chapterId, uint256 amount) external;
// }

// /**
//  * @title Story
//  * @dev Individual story contract instance managing chapters, branching, and story lifecycle
//  * @notice Handles story-specific logic, chapter sequencing, and branching narratives
//  */
// contract Story is 
//     Initializable, 
//     AccessControlUpgradeable, 
//     ReentrancyGuardUpgradeable, 
//     PausableUpgradeable 
// {
//     using Counters for Counters.Counter;
//     using EnumerableSet for EnumerableSet.UintSet;
//     using EnumerableSet for EnumerableSet.AddressSet;

//     // ============ CONSTANTS ============
//     bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
//     bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
//     bytes32 public constant CHAPTER_MANAGER_ROLE = keccak256("CHAPTER_MANAGER_ROLE");
    
//     uint256 public constant MAX_BRANCHES_PER_CHAPTER = 5;
//     uint256 public constant MAX_STORY_DEPTH = 100;
//     uint256 public constant MIN_CHAPTER_INTERVAL = 1 hours;

//     // ============ ENUMS ============
//     enum StoryStatus {
//         Active,
//         Paused,
//         Completed,
//         Abandoned
//     }

//     enum ChapterStatus {
//         Proposed,
//         Voting,
//         Accepted,
//         Rejected,
//         Minted
//     }

//     enum BranchType {
//         Linear,      // Single path continuation
//         Choice,      // Reader choice point
//         Parallel,    // Multiple simultaneous paths
//         Merge        // Paths converging back
//     }

//     // ============ STRUCTS ============
//     struct StoryMetadata {
//         uint256 storyId;
//         string title;
//         string description;
//         address creator;
//         uint8 genre;
//         uint256 createdAt;
//         StoryStatus status;
//     }

//     struct StorySettings {
//         uint256 minVotingThreshold;
//         uint256 votingDuration;
//         uint256 proposalStakeAmount;
//         uint256 maxBranches;
//         bool allowRemixes;
//         bool requireVerification;
//     }

//     struct Chapter {
//         uint256 id;
//         uint256 parentChapterId;
//         uint256[] childChapterIds;
//         address proposer;
//         string contentHash;     // IPFS hash
//         string title;
//         uint256 proposedAt;
//         uint256 votingEndsAt;
//         ChapterStatus status;
//         BranchType branchType;
//         uint256 pathIndex;      // For tracking story paths
//         uint256 votes;
//         uint256 nftTokenId;
//         bool isCanonical;       // Main story path
//     }

//     struct StoryPath {
//         uint256[] chapterIds;
//         string pathName;
//         bool isComplete;
//         uint256 collectors;
//         address[] topCollectors;
//     }

//     struct ReaderProgress {
//         uint256[] completedChapters;
//         uint256 currentChapter;
//         uint256[] activePaths;
//         uint256 lastReadAt;
//         bool hasVoted;
//         uint256 reputation;
//     }

//     struct StoryStatistics {
//         uint256 totalChapters;
//         uint256 totalBranches;
//         uint256 totalReaders;
//         uint256 totalCollectors;
//         uint256 totalRevenue;
//         uint256 averageRating;
//         uint256 lastActivity;
//     }

//     // ============ STATE VARIABLES ============
//     StoryMetadata public metadata;
//     StorySettings public settings;
//     StoryStatistics public statistics;
    
//     Counters.Counter private _chapterIds;
//     Counters.Counter private _pathIds;
    
//     // Contract addresses
//     address public factory;
//     address public chapterManager;
//     address public votingManager;
//     address public chapterNFT;
//     address public revenueDistribution;
    
//     // Core story data
//     mapping(uint256 => Chapter) public chapters;
//     mapping(uint256 => StoryPath) public storyPaths;
//     mapping(address => ReaderProgress) public readerProgress;
//     mapping(uint256 => uint256[]) public chaptersByPath;
//     mapping(uint256 => mapping(uint256 => bool)) public pathConnections;
    
//     // Reader and collector tracking
//     EnumerableSet.AddressSet private readers;
//     EnumerableSet.AddressSet private collectors;
//     EnumerableSet.UintSet private activeChapters;
//     EnumerableSet.UintSet private completedPaths;
    
//     // Chapter organization
//     uint256[] public rootChapters;        // Starting chapters
//     uint256[] public canonicalPath;       // Main story line
//     uint256 public currentCanonicalChapter;
    
//     // Remix and forking
//     mapping(address => bool) public authorizedRemixers;
//     mapping(uint256 => address[]) public chapterRemixes;
//     bool public isRemixEnabled;

//     // ============ EVENTS ============
//     event ChapterProposed(
//         uint256 indexed chapterId,
//         uint256 indexed parentChapterId,
//         address indexed proposer,
//         string title,
//         BranchType branchType,
//         uint256 timestamp
//     );

//     event ChapterAccepted(
//         uint256 indexed chapterId,
//         uint256 pathIndex,
//         bool isCanonical,
//         uint256 nftTokenId,
//         uint256 timestamp
//     );

//     event ChapterRejected(
//         uint256 indexed chapterId,
//         uint256 timestamp
//     );

//     event StoryBranched(
//         uint256 indexed parentChapterId,
//         uint256[] childChapterIds,
//         BranchType branchType,
//         uint256 timestamp
//     );

//     event PathCompleted(
//         uint256 indexed pathId,
//         uint256[] chapterIds,
//         uint256 collectors,
//         uint256 timestamp
//     );

//     event ReaderJoined(
//         address indexed reader,
//         uint256 startingChapter,
//         uint256 timestamp
//     );

//     event ReaderProgressUpdated(
//         address indexed reader,
//         uint256 chapterId,
//         uint256 pathId,
//         uint256 timestamp
//     );

//     event StoryStatusChanged(
//         StoryStatus oldStatus,
//         StoryStatus newStatus,
//         uint256 timestamp
//     );

//     event RemixCreated(
//         uint256 indexed originalChapterId,
//         address indexed remixer,
//         address remixStoryContract,
//         uint256 timestamp
//     );

//     // ============ ERRORS ============
//     error AlreadyInitialized();
//     error Unauthorized();
//     error InvalidChapter();
//     error InvalidPath();
//     error VotingInProgress();
//     error MaxBranchesExceeded();
//     error StoryNotActive();
//     error ChapterNotFound();
//     error InvalidBranchType();
//     error PathNotFound();
//     error RemixNotAllowed();
//     error InvalidStoryDepth();

//     // ============ MODIFIERS ============
//     modifier onlyCreator() {
//         if (!hasRole(CREATOR_ROLE, msg.sender)) revert Unauthorized();
//         _;
//     }

//     modifier onlyChapterManager() {
//         if (!hasRole(CHAPTER_MANAGER_ROLE, msg.sender)) revert Unauthorized();
//         _;
//     }

//     modifier storyActive() {
//         if (metadata.status != StoryStatus.Active) revert StoryNotActive();
//         _;
//     }

//     modifier validChapter(uint256 chapterId) {
//         if (chapters[chapterId].id == 0) revert ChapterNotFound();
//         _;
//     }

//     modifier validPath(uint256 pathId) {
//         if (pathId == 0 || pathId > _pathIds.current()) revert PathNotFound();
//         _;
//     }

//     // ============ INITIALIZER ============
//     function initialize(
//         string memory _title,
//         string memory _description,
//         address _creator,
//         uint8 _genre,
//         StorySettings memory _settings
//     ) external initializer {
//         __AccessControl_init();
//         __ReentrancyGuard_init();
//         __Pausable_init();

//         // Set up roles
//         _grantRole(DEFAULT_ADMIN_ROLE, _creator);
//         _grantRole(CREATOR_ROLE, _creator);
        
//         // Initialize metadata
//         metadata = StoryMetadata({
//             storyId: 0, // Will be set by factory
//             title: _title,
//             description: _description,
//             creator: _creator,
//             genre: _genre,
//             createdAt: block.timestamp,
//             status: StoryStatus.Active
//         });

//         // Initialize settings
//         settings = _settings;
        
//         // Initialize statistics
//         statistics = StoryStatistics({
//             totalChapters: 0,
//             totalBranches: 0,
//             totalReaders: 0,
//             totalCollectors: 0,
//             totalRevenue: 0,
//             averageRating: 0,
//             lastActivity: block.timestamp
//         });

//         factory = msg.sender;
//         isRemixEnabled = _settings.allowRemixes;
//     }

//     // ============ CHAPTER MANAGEMENT ============

//     /**
//      * @notice Proposes a new chapter
//      * @param parentChapterId Parent chapter (0 for root)
//      * @param title Chapter title
//      * @param contentHash IPFS hash of chapter content
//      * @param branchType Type of branching for this chapter
//      * @return chapterId The ID of the proposed chapter
//      */
//     function proposeChapter(
//         uint256 parentChapterId,
//         string memory title,
//         string memory contentHash,
//         BranchType branchType
//     ) 
//         external 
//         storyActive 
//         nonReentrant 
//         returns (uint256 chapterId) 
//     {
//         // Validate parent chapter (0 is valid for root chapters)
//         if (parentChapterId != 0 && chapters[parentChapterId].id == 0) {
//             revert InvalidChapter();
//         }

//         // Check branching limits
//         if (parentChapterId != 0) {
//             if (chapters[parentChapterId].childChapterIds.length >= settings.maxBranches) {
//                 revert MaxBranchesExceeded();
//             }
//         }

//         // Generate new chapter ID
//         _chapterIds.increment();
//         chapterId = _chapterIds.current();

//         // Create chapter
//         Chapter storage newChapter = chapters[chapterId];
//         newChapter.id = chapterId;
//         newChapter.parentChapterId = parentChapterId;
//         newChapter.proposer = msg.sender;
//         newChapter.contentHash = contentHash;
//         newChapter.title = title;
//         newChapter.proposedAt = block.timestamp;
//         newChapter.status = ChapterStatus.Proposed;
//         newChapter.branchType = branchType;
//         newChapter.isCanonical = (parentChapterId == 0); // Root chapters start as canonical

//         // Update parent chapter
//         if (parentChapterId != 0) {
//             chapters[parentChapterId].childChapterIds.push(chapterId);
//         } else {
//             rootChapters.push(chapterId);
//         }

//         // Start voting if voting manager is available
//         if (votingManager != address(0)) {
//             IVotingManager(votingManager).startChapterVoting(
//                 metadata.storyId,
//                 chapterId,
//                 settings.votingDuration
//             );
//             newChapter.status = ChapterStatus.Voting;
//             newChapter.votingEndsAt = block.timestamp + settings.votingDuration;
//         }

//         // Update statistics
//         statistics.totalChapters++;
//         statistics.lastActivity = block.timestamp;
        
//         // Update factory stats
//         if (factory != address(0)) {
//             IStoryFactory(factory).updateStoryStats(
//                 metadata.storyId,
//                 statistics.totalChapters,
//                 statistics.totalCollectors
//             );
//         }

//         emit ChapterProposed(
//             chapterId,
//             parentChapterId,
//             msg.sender,
//             title,
//             branchType,
//             block.timestamp
//         );

//         return chapterId;
//     }

//     /**
//      * @notice Accepts a chapter proposal (called by chapter manager)
//      * @param chapterId The chapter ID
//      * @param pathIndex The story path this chapter belongs to
//      */
//     function acceptChapter(
//         uint256 chapterId,
//         uint256 pathIndex
//     ) 
//         external 
//         onlyChapterManager 
//         validChapter(chapterId) 
//         nonReentrant 
//     {
//         Chapter storage chapter = chapters[chapterId];
        
//         if (chapter.status != ChapterStatus.Voting) {
//             revert InvalidChapter();
//         }

//         // Update chapter status
//         chapter.status = ChapterStatus.Accepted;
//         chapter.pathIndex = pathIndex;

//         // Determine if this chapter is canonical
//         bool isCanonical = _determineCanonicalStatus(chapterId, pathIndex);
//         chapter.isCanonical = isCanonical;

//         if (isCanonical) {
//             canonicalPath.push(chapterId);
//             currentCanonicalChapter = chapterId;
//         }

//         // Mint NFT if contract is available
//         uint256 nftTokenId = 0;
//         if (chapterNFT != address(0)) {
//             nftTokenId = IChapterNFT(chapterNFT).mintChapter(
//                 chapter.proposer,
//                 metadata.storyId,
//                 chapterId,
//                 chapter.contentHash
//             );
//             chapter.nftTokenId = nftTokenId;
//             chapter.status = ChapterStatus.Minted;
//         }

//         // Update path information
//         _updateStoryPath(pathIndex, chapterId);

//         // Handle branching if this creates new paths
//         if (chapter.branchType != BranchType.Linear) {
//             _handleBranching(chapterId);
//         }

//         emit ChapterAccepted(chapterId, pathIndex, isCanonical, nftTokenId, block.timestamp);
//     }

//     /**
//      * @notice Rejects a chapter proposal (called by chapter manager)
//      * @param chapterId The chapter ID
//      */
//     function rejectChapter(uint256 chapterId) 
//         external 
//         onlyChapterManager 
//         validChapter(chapterId) 
//     {
//         Chapter storage chapter = chapters[chapterId];
        
//         if (chapter.status != ChapterStatus.Voting) {
//             revert InvalidChapter();
//         }

//         chapter.status = ChapterStatus.Rejected;
        
//         // Remove from parent's children if needed
//         if (chapter.parentChapterId != 0) {
//             _removeFromParentChildren(chapter.parentChapterId, chapterId);
//         }

//         emit ChapterRejected(chapterId, block.timestamp);
//     }

//     // ============ STORY PATH MANAGEMENT ============

//     /**
//      * @notice Creates a new story path
//      * @param pathName Name for the path
//      * @param startingChapterId Starting chapter for this path
//      * @return pathId The created path ID
//      */
//     function createStoryPath(
//         string memory pathName,
//         uint256 startingChapterId
//     ) 
//         external 
//         onlyChapterManager 
//         validChapter(startingChapterId) 
//         returns (uint256 pathId) 
//     {
//         _pathIds.increment();
//         pathId = _pathIds.current();

//         StoryPath storage newPath = storyPaths[pathId];
//         newPath.pathName = pathName;
//         newPath.chapterIds.push(startingChapterId);
//         newPath.isComplete = false;
//         newPath.collectors = 0;

//         chaptersByPath[pathId].push(startingChapterId);
        
//         statistics.totalBranches++;

//         return pathId;
//     }

//     /**
//      * @notice Completes a story path
//      * @param pathId The path ID
//      */
//     function completePath(uint256 pathId) 
//         external 
//         onlyChapterManager 
//         validPath(pathId) 
//     {
//         StoryPath storage path = storyPaths[pathId];
//         path.isComplete = true;
//         completedPaths.add(pathId);

//         emit PathCompleted(pathId, path.chapterIds, path.collectors, block.timestamp);
//     }

//     // ============ READER MANAGEMENT ============

//     /**
//      * @notice Allows a reader to join the story
//      * @param startingChapterId Chapter to start reading from
//      */
//     function joinAsReader(uint256 startingChapterId) 
//         external 
//         storyActive 
//         validChapter(startingChapterId) 
//     {
//         if (!readers.contains(msg.sender)) {
//             readers.add(msg.sender);
//             statistics.totalReaders++;
//         }

//         ReaderProgress storage progress = readerProgress[msg.sender];
//         progress.currentChapter = startingChapterId;
//         progress.lastReadAt = block.timestamp;
//         progress.completedChapters.push(startingChapterId);

//         // Add to active paths based on chapter
//         uint256 pathId = chapters[startingChapterId].pathIndex;
//         if (pathId != 0) {
//             progress.activePaths.push(pathId);
//         }

//         emit ReaderJoined(msg.sender, startingChapterId, block.timestamp);
//     }

//     /**
//      * @notice Updates reader progress
//      * @param chapterId Chapter being read
//      * @param pathId Path being followed
//      */
//     function updateReaderProgress(
//         uint256 chapterId,
//         uint256 pathId
//     ) 
//         external 
//         validChapter(chapterId) 
//         validPath(pathId) 
//     {
//         ReaderProgress storage progress = readerProgress[msg.sender];
//         progress.currentChapter = chapterId;
//         progress.lastReadAt = block.timestamp;
        
//         // Add to completed chapters if not already there
//         bool alreadyCompleted = false;
//         for (uint256 i = 0; i < progress.completedChapters.length; i++) {
//             if (progress.completedChapters[i] == chapterId) {
//                 alreadyCompleted = true;
//                 break;
//             }
//         }
        
//         if (!alreadyCompleted) {
//             progress.completedChapters.push(chapterId);
//         }

//         emit ReaderProgressUpdated(msg.sender, chapterId, pathId, block.timestamp);
//     }

//     // ============ STORY MANAGEMENT ============

//     /**
//      * @notice Updates story status (creator only)
//      * @param newStatus The new status
//      */
//     function updateStoryStatus(StoryStatus newStatus) external onlyCreator {
//         StoryStatus oldStatus = metadata.status;
//         metadata.status = newStatus;
        
//         emit StoryStatusChanged(oldStatus, newStatus, block.timestamp);
//     }

//     /**
//      * @notice Sets external contract addresses (creator only)
//      */
//     function setExternalContracts(
//         address _chapterManager,
//         address _votingManager,
//         address _chapterNFT,
//         address _revenueDistribution
//     ) external onlyCreator {
//         chapterManager = _chapterManager;
//         votingManager = _votingManager;
//         chapterNFT = _chapterNFT;
//         revenueDistribution = _revenueDistribution;
        
//         // Grant roles to external contracts
//         if (_chapterManager != address(0)) {
//             _grantRole(CHAPTER_MANAGER_ROLE, _chapterManager);
//         }
//     }

//     /**
//      * @notice Updates story settings (creator only)
//      */
//     function updateStorySettings(StorySettings memory newSettings) 
//         external 
//         onlyCreator 
//     {
//         settings = newSettings;
//         isRemixEnabled = newSettings.allowRemixes;
//     }

//     // ============ REMIX & FORKING ============

//     /**
//      * @notice Authorizes an address to create remixes
//      * @param remixer Address to authorize
//      */
//     function authorizeRemixer(address remixer) external onlyCreator {
//         if (!isRemixEnabled) revert RemixNotAllowed();
//         authorizedRemixers[remixer] = true;
//     }

//     /**
//      * @notice Creates a remix/fork from a specific chapter
//      * @param chapterId Chapter to remix from
//      * @param newTitle Title for the remix
//      * @param newDescription Description for the remix
//      */
//     function createRemix(
//         uint256 chapterId,
//         string memory newTitle,
//         string memory newDescription
//     ) 
//         external 
//         validChapter(chapterId) 
//         returns (address remixContract) 
//     {
//         if (!isRemixEnabled || !authorizedRemixers[msg.sender]) {
//             revert RemixNotAllowed();
//         }

//         // Create remix through factory (this would need factory integration)
//         // For now, emit event for off-chain handling
//         chapterRemixes[chapterId].push(msg.sender);

//         emit RemixCreated(chapterId, msg.sender, address(0), block.timestamp);
        
//         return address(0); // Placeholder
//     }

//     // ============ INTERNAL FUNCTIONS ============

//     function _determineCanonicalStatus(
//         uint256 chapterId,
//         uint256 pathIndex
//     ) internal view returns (bool) {
//         // Logic to determine if this chapter should be part of canonical path
//         // This could be based on voting results, path popularity, etc.
//         return pathIndex == 1; // Simplified: path 1 is canonical
//     }

//     function _updateStoryPath(uint256 pathId, uint256 chapterId) internal {
//         if (pathId == 0) {
//             // Create new path if needed
//             _pathIds.increment();
//             pathId = _pathIds.current();
//         }
        
//         chaptersByPath[pathId].push(chapterId);
//         storyPaths[pathId].chapterIds.push(chapterId);
//     }

//     function _handleBranching(uint256 chapterId) internal {
//         Chapter storage chapter = chapters[chapterId];
        
//         if (chapter.branchType == BranchType.Choice || 
//             chapter.branchType == BranchType.Parallel) {
            
//             statistics.totalBranches++;
            
//             emit StoryBranched(
//                 chapterId,
//                 chapter.childChapterIds,
//                 chapter.branchType,
//                 block.timestamp
//             );
//         }
//     }

//     function _removeFromParentChildren(
//         uint256 parentId,
//         uint256 childId
//     ) internal {
//         uint256[] storage children = chapters[parentId].childChapterIds;
//         for (uint256 i = 0; i < children.length; i++) {
//             if (children[i] == childId) {
//                 children[i] = children[children.length - 1];
//                 children.pop();
//                 break;
//             }
//         }
//     }

//     // ============ VIEW FUNCTIONS ============

//     function getChapter(uint256 chapterId) 
//         external 
//         view 
//         validChapter(chapterId) 
//         returns (Chapter memory) 
//     {
//         return chapters[chapterId];
//     }

//     function getStoryPath(uint256 pathId) 
//         external 
//         view 
//         validPath(pathId) 
//         returns (StoryPath memory) 
//     {
//         return storyPaths[pathId];
//     }

//     function getReaderProgress(address reader) 
//         external 
//         view 
//         returns (ReaderProgress memory) 
//     {
//         return readerProgress[reader];
//     }

//     function getCanonicalPath() external view returns (uint256[] memory) {
//         return canonicalPath;
//     }

//     function getRootChapters() external view returns (uint256[] memory) {
//         return rootChapters;
//     }

//     function getTotalChapters() external view returns (uint256) {
//         return _chapterIds.current();
//     }

//     function getTotalPaths() external view returns (uint256) {
//         return _pathIds.current();
//     }

//     function getStatistics() external view returns (StoryStatistics memory) {
//         return statistics;
//     }

//     function isReader(address user) external view returns (bool) {
//         return readers.contains(user);
//     }

//     function isCollector(address user) external view returns (bool) {
//         return collectors.contains(user);
//     }
// }