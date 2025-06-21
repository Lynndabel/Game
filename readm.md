// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// 1. GOVERNANCE TOKEN CONTRACT
contract StoryToken is ERC20, Ownable {
    constructor() ERC20("StoryDAO", "STORY") {}
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

// 2. CHAPTER NFT CONTRACT
contract ChapterNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    
    struct Chapter {
        uint256 storyId;
        uint256 chapterNumber;
        address author;
        string contentHash; // IPFS hash
        uint256 timestamp;
    }
    
    mapping(uint256 => Chapter) public chapters;
    mapping(uint256 => uint256[]) public storyChapters; // storyId -> chapter tokenIds
    
    event ChapterMinted(uint256 indexed tokenId, uint256 indexed storyId, address author);
    
    constructor() ERC721("StoryChapter", "CHAPTER") {}
    
    function mintChapter(
        uint256 storyId,
        address author,
        string memory contentHash
    ) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        uint256 chapterNumber = storyChapters[storyId].length + 1;
        
        chapters[tokenId] = Chapter({
            storyId: storyId,
            chapterNumber: chapterNumber,
            author: author,
            contentHash: contentHash,
            timestamp: block.timestamp
        });
        
        storyChapters[storyId].push(tokenId);
        _mint(author, tokenId);
        
        emit ChapterMinted(tokenId, storyId, author);
        return tokenId;
    }
    
    function getStoryChapters(uint256 storyId) external view returns (uint256[] memory) {
        return storyChapters[storyId];
    }
}

// 3. STORY REGISTRY CONTRACT
contract StoryRegistry is Ownable {
    uint256 private _storyIdCounter;
    
    struct Story {
        string title;
        string description;
        address creator;
        uint256 timestamp;
        bool isActive;
    }
    
    mapping(uint256 => Story) public stories;
    
    event StoryCreated(uint256 indexed storyId, address creator, string title);
    
    function createStory(
        string memory title,
        string memory description
    ) external returns (uint256) {
        uint256 storyId = _storyIdCounter++;
        
        stories[storyId] = Story({
            title: title,
            description: description,
            creator: msg.sender,
            timestamp: block.timestamp,
            isActive: true
        });
        
        emit StoryCreated(storyId, msg.sender, title);
        return storyId;
    }
    
    function getStoryCount() external view returns (uint256) {
        return _storyIdCounter;
    }
}

// 4. PROPOSAL SYSTEM CONTRACT
contract ProposalSystem is ReentrancyGuard {
    IERC20 public immutable storyToken;
    
    struct Proposal {
        uint256 storyId;
        address author;
        string contentHash;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterStakes;
    }
    
    uint256 private _proposalIdCounter;
    mapping(uint256 => Proposal) public proposals;
    
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant MIN_STAKE = 100 * 10**18; // 100 tokens
    
    event ProposalCreated(uint256 indexed proposalId, uint256 storyId, address author);
    event VoteCast(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    
    constructor(address _storyToken) {
        storyToken = IERC20(_storyToken);
    }
    
    function createProposal(
        uint256 storyId,
        string memory contentHash
    ) external returns (uint256) {
        require(storyToken.transferFrom(msg.sender, address(this), MIN_STAKE), "Stake required");
        
        uint256 proposalId = _proposalIdCounter++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.storyId = storyId;
        proposal.author = msg.sender;
        proposal.contentHash = contentHash;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        
        emit ProposalCreated(proposalId, storyId, msg.sender);
        return proposalId;
    }
    
    function vote(uint256 proposalId, bool support, uint256 amount) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(amount > 0, "Must stake tokens to vote");
        
        require(storyToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voterStakes[msg.sender] = amount;
        
        if (support) {
            proposal.votesFor += amount;
        } else {
            proposal.votesAgainst += amount;
        }
        
        emit VoteCast(proposalId, msg.sender, support, amount);
    }
    
    function getProposalInfo(uint256 proposalId) external view returns (
        uint256 storyId,
        address author,
        string memory contentHash,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.storyId,
            proposal.author,
            proposal.contentHash,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.endTime,
            proposal.executed
        );
    }
}

// 5. REVENUE DISTRIBUTOR CONTRACT
contract RevenueDistributor is ReentrancyGuard {
    ChapterNFT public immutable chapterNFT;
    
    struct RevenueShare {
        uint256 totalRevenue;
        mapping(address => uint256) authorShares;
        mapping(address => bool) hasClaimed;
    }
    
    mapping(uint256 => RevenueShare) public storyRevenues; // storyId -> revenue data
    
    uint256 public constant AUTHOR_SHARE_PERCENT = 70; // 70% to authors
    uint256 public constant PLATFORM_SHARE_PERCENT = 30; // 30% to platform
    
    event RevenueAdded(uint256 indexed storyId, uint256 amount);
    event RevenueClaimed(uint256 indexed storyId, address author, uint256 amount);
    
    constructor(address _chapterNFT) {
        chapterNFT = ChapterNFT(_chapterNFT);
    }
    
    function addRevenue(uint256 storyId) external payable {
        require(msg.value > 0, "No revenue to add");
        
        RevenueShare storage revenue = storyRevenues[storyId];
        revenue.totalRevenue += msg.value;
        
        emit RevenueAdded(storyId, msg.value);
    }
    
    function claimRevenue(uint256 storyId) external nonReentrant {
        RevenueShare storage revenue = storyRevenues[storyId];
        require(!revenue.hasClaimed[msg.sender], "Already claimed");
        require(revenue.totalRevenue > 0, "No revenue to claim");
        
        // Calculate author's share based on chapters contributed
        uint256[] memory chapters = chapterNFT.getStoryChapters(storyId);
        uint256 authorChapters = 0;
        
        for (uint256 i = 0; i < chapters.length; i++) {
            (, , address author, , ) = chapterNFT.chapters(chapters[i]);
            if (author == msg.sender) {
                authorChapters++;
            }
        }
        
        require(authorChapters > 0, "No chapters authored");
        
        uint256 authorRevenue = (revenue.totalRevenue * AUTHOR_SHARE_PERCENT / 100);
        uint256 authorShare = (authorRevenue * authorChapters) / chapters.length;
        
        revenue.hasClaimed[msg.sender] = true;
        
        (bool success, ) = payable(msg.sender).call{value: authorShare}("");
        require(success, "Transfer failed");
        
        emit RevenueClaimed(storyId, msg.sender, authorShare);
    }
}

// 6. MAIN PLATFORM CONTRACT (Orchestrator)
contract StoryPlatform is Ownable {
    StoryRegistry public immutable storyRegistry;
    ChapterNFT public immutable chapterNFT;
    ProposalSystem public immutable proposalSystem;
    RevenueDistributor public immutable revenueDistributor;
    
    event ChapterProposalWon(uint256 indexed proposalId, uint256 indexed storyId);
    
    constructor(
        address _storyRegistry,
        address _chapterNFT,
        address _proposalSystem,
        address _revenueDistributor
    ) {
        storyRegistry = StoryRegistry(_storyRegistry);
        chapterNFT = ChapterNFT(_chapterNFT);
        proposalSystem = ProposalSystem(_proposalSystem);
        revenueDistributor = RevenueDistributor(_revenueDistributor);
    }
    
    function executeWinningProposal(uint256 proposalId) external {
        (
            uint256 storyId,
            address author,
            string memory contentHash,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 endTime,
            bool executed
        ) = proposalSystem.getProposalInfo(proposalId);
        
        require(block.timestamp >= endTime, "Voting still active");
        require(!executed, "Already executed");
        require(votesFor > votesAgainst, "Proposal did not pass");
        
        // Mint the winning chapter as NFT
        chapterNFT.mintChapter(storyId, author, contentHash);
        
        emit ChapterProposalWon(proposalId, storyId);
    }
}