// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/security/Pausable.sol";
// import "@openzeppelin/contracts/proxy/Clones.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";

// // Interfaces
// interface IStory {
//     function initialize(
//         string memory _title,
//         string memory _description,
//         address _creator,
//         uint8 _genre,
//         StorySettings memory _settings
//     ) external;
// }

// interface ITokenStaking {
//     function hasMinimumStake(address user, uint256 amount) external view returns (bool);
//     function stakeForStoryCreation(address user, uint256 amount) external;
// }

// interface IEventLogger {
//     function logStoryCreated(
//         uint256 storyId,
//         address creator,
//         address storyContract,
//         string memory title,
//         uint8 genre
//     ) external;
// }

// /**
//  * @title StoryFactory
//  * @dev Factory contract for creating and managing story instances
//  * @notice This contract handles story creation, discovery, and categorization
//  */
// contract StoryFactory is AccessControl, ReentrancyGuard, Pausable {
//     using Counters for Counters.Counter;
//     using Clones for address;

//     // ============ CONSTANTS ============
//     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//     bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
//     uint256 public constant MAX_TITLE_LENGTH = 100;
//     uint256 public constant MAX_DESCRIPTION_LENGTH = 500;
//     uint256 public constant MAX_STORIES_PER_USER = 10;

//     // ============ ENUMS ============
//     enum StoryStatus {
//         Active,
//         Paused,
//         Completed,
//         Abandoned
//     }

//     enum Genre {
//         Fantasy,
//         SciFi,
//         Mystery,
//         Romance,
//         Horror,
//         Adventure,
//         Drama,
//         Comedy,
//         Thriller,
//         Historical
//     }

//     // ============ STRUCTS ============
//     struct StoryInfo {
//         uint256 id;
//         address storyContract;
//         address creator;
//         string title;
//         string description;
//         Genre genre;
//         StoryStatus status;
//         uint256 createdAt;
//         uint256 totalChapters;
//         uint256 totalCollectors;
//         bool isVerified;
//     }

//     struct StorySettings {
//         uint256 minVotingThreshold;
//         uint256 votingDuration;
//         uint256 proposalStakeAmount;
//         uint256 maxBranches;
//         bool allowRemixes;
//         bool requireVerification;
//     }

//     struct CreatorStats {
//         uint256 totalStories;
//         uint256 totalChapters;
//         uint256 reputation;
//         bool isVerified;
//         uint256 lastStoryCreated;
//     }

//     // ============ STATE VARIABLES ============
//     Counters.Counter private _storyIds;
    
//     address public immutable storyImplementation;
//     address public tokenStaking;
//     address public eventLogger;
    
//     uint256 public storyCreationFee;
//     uint256 public minStakeForCreation;
    
//     // Mappings
//     mapping(uint256 => StoryInfo) public stories;
//     mapping(address => uint256[]) public storiesByCreator;
//     mapping(address => CreatorStats) public creatorStats;
//     mapping(Genre => uint256[]) public storiesByGenre;
//     mapping(address => bool) public verifiedCreators;
    
//     // Arrays for discovery
//     uint256[] public allStoryIds;
//     uint256[] public featuredStoryIds;

//     // ============ EVENTS ============
//     event StoryCreated(
//         uint256 indexed storyId,
//         address indexed creator,
//         address indexed storyContract,
//         string title,
//         Genre genre,
//         uint256 timestamp
//     );

//     event StoryStatusUpdated(
//         uint256 indexed storyId,
//         StoryStatus oldStatus,
//         StoryStatus newStatus,
//         uint256 timestamp
//     );

//     event CreatorVerified(address indexed creator, uint256 timestamp);
//     event CreatorUnverified(address indexed creator, uint256 timestamp);
    
//     event StoryFeatured(uint256 indexed storyId, uint256 timestamp);
//     event StoryUnfeatured(uint256 indexed storyId, uint256 timestamp);
    
//     event FactoryConfigUpdated(
//         uint256 creationFee,
//         uint256 minStake,
//         uint256 timestamp
//     );

//     // ============ ERRORS ============
//     error InvalidTitle();
//     error InvalidDescription();
//     error InsufficientStake();
//     error TooManyStories();
//     error StoryNotFound();
//     error Unauthorized();
//     error InvalidGenre();
//     error StoryCreationFailed();
//     error InvalidConfiguration();

//     // ============ MODIFIERS ============
//     modifier onlyStoryCreator(uint256 storyId) {
//         if (stories[storyId].creator != msg.sender) revert Unauthorized();
//         _;
//     }

//     modifier validStoryId(uint256 storyId) {
//         if (stories[storyId].storyContract == address(0)) revert StoryNotFound();
//         _;
//     }

//     modifier canCreateStory() {
//         if (storiesByCreator[msg.sender].length >= MAX_STORIES_PER_USER) {
//             revert TooManyStories();
//         }
//         _;
//     }

//     // ============ CONSTRUCTOR ============
//     constructor(
//         address _storyImplementation,
//         address _admin,
//         uint256 _storyCreationFee,
//         uint256 _minStakeForCreation
//     ) {
//         if (_storyImplementation == address(0)) revert InvalidConfiguration();
        
//         storyImplementation = _storyImplementation;
//         storyCreationFee = _storyCreationFee;
//         minStakeForCreation = _minStakeForCreation;
        
//         _grantRole(DEFAULT_ADMIN_ROLE, _admin);
//         _grantRole(ADMIN_ROLE, _admin);
//     }

//     // ============ EXTERNAL FUNCTIONS ============

//     /**
//      * @notice Creates a new story instance
//      * @param title The story title
//      * @param description Brief story description
//      * @param genre The story genre
//      * @param settings Story-specific settings
//      * @return storyId The ID of the created story
//      * @return storyContract The address of the story contract
//      */
//     function createStory(
//         string memory title,
//         string memory description,
//         Genre genre,
//         StorySettings memory settings
//     ) 
//         external 
//         payable 
//         nonReentrant 
//         whenNotPaused 
//         canCreateStory 
//         returns (uint256 storyId, address storyContract) 
//     {
//         // Input validation
//         if (bytes(title).length == 0 || bytes(title).length > MAX_TITLE_LENGTH) {
//             revert InvalidTitle();
//         }
//         if (bytes(description).length > MAX_DESCRIPTION_LENGTH) {
//             revert InvalidDescription();
//         }
//         if (uint8(genre) > uint8(Genre.Historical)) {
//             revert InvalidGenre();
//         }

//         // Fee validation
//         if (msg.value < storyCreationFee) {
//             revert InsufficientStake();
//         }

//         // Stake validation (if staking contract is set)
//         if (tokenStaking != address(0)) {
//             if (!ITokenStaking(tokenStaking).hasMinimumStake(msg.sender, minStakeForCreation)) {
//                 revert InsufficientStake();
//             }
//             ITokenStaking(tokenStaking).stakeForStoryCreation(msg.sender, minStakeForCreation);
//         }

//         // Generate new story ID
//         _storyIds.increment();
//         storyId = _storyIds.current();

//         // Clone story implementation
//         storyContract = storyImplementation.clone();
        
//         // Initialize the story contract
//         try IStory(storyContract).initialize(
//             title,
//             description,
//             msg.sender,
//             uint8(genre),
//             settings
//         ) {} catch {
//             revert StoryCreationFailed();
//         }

//         // Create story info
//         StoryInfo memory newStory = StoryInfo({
//             id: storyId,
//             storyContract: storyContract,
//             creator: msg.sender,
//             title: title,
//             description: description,
//             genre: genre,
//             status: StoryStatus.Active,
//             createdAt: block.timestamp,
//             totalChapters: 0,
//             totalCollectors: 0,
//             isVerified: verifiedCreators[msg.sender]
//         });

//         // Store story info
//         stories[storyId] = newStory;
//         storiesByCreator[msg.sender].push(storyId);
//         storiesByGenre[genre].push(storyId);
//         allStoryIds.push(storyId);

//         // Update creator stats
//         CreatorStats storage stats = creatorStats[msg.sender];
//         stats.totalStories++;
//         stats.lastStoryCreated = block.timestamp;
//         if (!stats.isVerified && verifiedCreators[msg.sender]) {
//             stats.isVerified = true;
//         }

//         // Emit events
//         emit StoryCreated(storyId, msg.sender, storyContract, title, genre, block.timestamp);
        
//         // Log to external logger if available
//         if (eventLogger != address(0)) {
//             IEventLogger(eventLogger).logStoryCreated(
//                 storyId,
//                 msg.sender,
//                 storyContract,
//                 title,
//                 uint8(genre)
//             );
//         }

//         return (storyId, storyContract);
//     }

//     /**
//      * @notice Updates story status (only story creator)
//      * @param storyId The story ID
//      * @param newStatus The new status
//      */
//     function updateStoryStatus(
//         uint256 storyId, 
//         StoryStatus newStatus
//     ) 
//         external 
//         validStoryId(storyId) 
//         onlyStoryCreator(storyId) 
//     {
//         StoryStatus oldStatus = stories[storyId].status;
//         stories[storyId].status = newStatus;
        
//         emit StoryStatusUpdated(storyId, oldStatus, newStatus, block.timestamp);
//     }

//     /**
//      * @notice Updates story statistics (called by story contracts)
//      * @param storyId The story ID
//      * @param totalChapters New chapter count
//      * @param totalCollectors New collector count
//      */
//     function updateStoryStats(
//         uint256 storyId,
//         uint256 totalChapters,
//         uint256 totalCollectors
//     ) 
//         external 
//         validStoryId(storyId) 
//     {
//         // Only the story contract itself can update its stats
//         if (msg.sender != stories[storyId].storyContract) revert Unauthorized();
        
//         stories[storyId].totalChapters = totalChapters;
//         stories[storyId].totalCollectors = totalCollectors;
        
//         // Update creator stats
//         address creator = stories[storyId].creator;
//         creatorStats[creator].totalChapters = totalChapters;
//     }

//     // ============ ADMIN FUNCTIONS ============

//     /**
//      * @notice Verifies a creator (admin only)
//      * @param creator The creator address
//      */
//     function verifyCreator(address creator) external onlyRole(ADMIN_ROLE) {
//         verifiedCreators[creator] = true;
//         creatorStats[creator].isVerified = true;
//         emit CreatorVerified(creator, block.timestamp);
//     }

//     /**
//      * @notice Unverifies a creator (admin only)
//      * @param creator The creator address
//      */
//     function unverifyCreator(address creator) external onlyRole(ADMIN_ROLE) {
//         verifiedCreators[creator] = false;
//         creatorStats[creator].isVerified = false;
//         emit CreatorUnverified(creator, block.timestamp);
//     }

//     /**
//      * @notice Features a story (moderator only)
//      * @param storyId The story ID
//      */
//     function featureStory(uint256 storyId) 
//         external 
//         onlyRole(MODERATOR_ROLE) 
//         validStoryId(storyId) 
//     {
//         featuredStoryIds.push(storyId);
//         emit StoryFeatured(storyId, block.timestamp);
//     }

//     /**
//      * @notice Removes a story from featured list (moderator only)
//      * @param storyId The story ID
//      */
//     function unfeatureStory(uint256 storyId) 
//         external 
//         onlyRole(MODERATOR_ROLE) 
//     {
//         for (uint256 i = 0; i < featuredStoryIds.length; i++) {
//             if (featuredStoryIds[i] == storyId) {
//                 featuredStoryIds[i] = featuredStoryIds[featuredStoryIds.length - 1];
//                 featuredStoryIds.pop();
//                 emit StoryUnfeatured(storyId, block.timestamp);
//                 break;
//             }
//         }
//     }

//     /**
//      * @notice Updates factory configuration (admin only)
//      * @param _storyCreationFee New creation fee
//      * @param _minStakeForCreation New minimum stake
//      */
//     function updateConfig(
//         uint256 _storyCreationFee,
//         uint256 _minStakeForCreation
//     ) external onlyRole(ADMIN_ROLE) {
//         storyCreationFee = _storyCreationFee;
//         minStakeForCreation = _minStakeForCreation;
        
//         emit FactoryConfigUpdated(
//             _storyCreationFee,
//             _minStakeForCreation,
//             block.timestamp
//         );
//     }

//     /**
//      * @notice Sets external contract addresses (admin only)
//      * @param _tokenStaking Token staking contract
//      * @param _eventLogger Event logger contract
//      */
//     function setExternalContracts(
//         address _tokenStaking,
//         address _eventLogger
//     ) external onlyRole(ADMIN_ROLE) {
//         tokenStaking = _tokenStaking;
//         eventLogger = _eventLogger;
//     }

//     /**
//      * @notice Emergency pause (admin only)
//      */
//     function pause() external onlyRole(ADMIN_ROLE) {
//         _pause();
//     }

//     /**
//      * @notice Unpause (admin only)
//      */
//     function unpause() external onlyRole(ADMIN_ROLE) {
//         _unpause();
//     }

//     /**
//      * @notice Withdraw collected fees (admin only)
//      * @param to Recipient address
//      */
//     function withdrawFees(address payable to) external onlyRole(ADMIN_ROLE) {
//         if (to == address(0)) revert InvalidConfiguration();
//         uint256 balance = address(this).balance;
//         (bool success, ) = to.call{value: balance}("");
//         require(success, "Withdrawal failed");
//     }

//     // ============ VIEW FUNCTIONS ============

//     /**
//      * @notice Gets total number of stories
//      */
//     function totalStories() external view returns (uint256) {
//         return _storyIds.current();
//     }

//     /**
//      * @notice Gets stories by creator
//      * @param creator The creator address
//      */
//     function getStoriesByCreator(address creator) 
//         external 
//         view 
//         returns (uint256[] memory) 
//     {
//         return storiesByCreator[creator];
//     }

//     /**
//      * @notice Gets stories by genre
//      * @param genre The genre
//      */
//     function getStoriesByGenre(Genre genre) 
//         external 
//         view 
//         returns (uint256[] memory) 
//     {
//         return storiesByGenre[genre];
//     }

//     /**
//      * @notice Gets all story IDs
//      */
//     function getAllStoryIds() external view returns (uint256[] memory) {
//         return allStoryIds;
//     }

//     /**
//      * @notice Gets featured story IDs
//      */
//     function getFeaturedStoryIds() external view returns (uint256[] memory) {
//         return featuredStoryIds;
//     }

//     /**
//      * @notice Gets story info by ID
//      * @param storyId The story ID
//      */
//     function getStoryInfo(uint256 storyId) 
//         external 
//         view 
//         validStoryId(storyId)
//         returns (StoryInfo memory) 
//     {
//         return stories[storyId];
//     }

//     /**
//      * @notice Gets creator statistics
//      * @param creator The creator address
//      */
//     function getCreatorStats(address creator) 
//         external 
//         view 
//         returns (CreatorStats memory) 
//     {
//         return creatorStats[creator];
//     }

//     /**
//      * @notice Checks if creator is verified
//      * @param creator The creator address
//      */
//     function isCreatorVerified(address creator) external view returns (bool) {
//         return verifiedCreators[creator];
//     }
// }