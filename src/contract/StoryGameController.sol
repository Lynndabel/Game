// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./StoryRegistry.sol";
import "./interfaces/IChapterManager.sol";
import "./VotingEngine.sol";
import "./RewardDistributor.sol";
import "./StoryNFT.sol";
import "./ContentValidator.sol";
import "./StoryGameTypes.sol";
import "./Errors.sol";

/**
 * @title StoryGameController
 * @notice Main entry-point contract that orchestrates all modules.
 */
contract StoryGameController is Ownable, ReentrancyGuard {
    using StoryGameTypes for *;

    // Modules
    StoryRegistry public immutable registry;
    IChapterManager public immutable chapters;
    VotingEngine public immutable voting;
    RewardDistributor public immutable rewards;
    StoryNFT public immutable nft;
    ContentValidator public immutable validator;

    // Fees & durations (simple constants for demo)
    uint256 public baseVotingFee = 0.001 ether;
    uint256 public baseSubmissionFee = 0.005 ether;

    event StoryCreated(uint256 indexed storyId, string title, address creator);
    event ChapterProposal(uint256 indexed storyId, uint256 chapterId);
    event Voted(uint256 indexed chapterId, address voter);

    constructor(
        address _registry,
        address _chapters,
        address _voting,
        address _rewards,
        address _nft,
        address _validator
    ) {
        registry = StoryRegistry(_registry);
        chapters = IChapterManager(_chapters);
        voting = VotingEngine(_voting);
        rewards = RewardDistributor(_rewards);
        nft = StoryNFT(_nft);
        validator = ContentValidator(_validator);
    }

    // --------------------------------------------------
    // Story flow
    // --------------------------------------------------
    function createStory(
        string calldata _title,
        string calldata _firstChapter,
        StoryGameTypes.StoryCategory _category,
        string[] calldata _tags
    ) external payable nonReentrant returns (uint256 storyId) {
        require(msg.value >= baseSubmissionFee, "fee");
        storyId = registry.createStory(msg.sender, _title, _category, _tags);
        uint256 chapterId = chapters.createFirstChapter(storyId, _firstChapter, msg.sender);
        rewards.collectFee{value: msg.value}(storyId);
        emit StoryCreated(storyId, _title, msg.sender);
        emit ChapterProposal(storyId, chapterId);
    }

    function submitChapterProposal(uint256 _storyId, string calldata _content) external payable nonReentrant {
        require(msg.value >= baseSubmissionFee, "fee");
        uint256 chapterId = chapters.submitChapterProposal(_storyId, _content, msg.sender);
        rewards.collectFee{value: msg.value}(_storyId);
        emit ChapterProposal(_storyId, chapterId);
    }

    function vote(uint256 _chapterId) external payable nonReentrant {
        require(msg.value >= baseVotingFee, "fee");
        voting.vote(_chapterId, msg.sender);
        // simplistic: derive storyId via chapter, skip for brevity
        rewards.collectFee{value: msg.value}(0);
        emit Voted(_chapterId, msg.sender);
    }

    // Finalize voting round (off-chain determines proposals list)
    function finalize(uint256 _storyId, uint256[] calldata _proposalIds, address _winner, address _creator) external onlyOwner {
        // Step 1: finalize votes & mark winner
        voting.finalize(_storyId, _proposalIds);
        // Step 2: payout (for demo assume totalReward = address(this).balance) – should track per-story.
        rewards.payOut(_storyId, _winner, _creator, address(this).balance);
        // Step 3: mint NFT
        nft.mint(_winner, "ipfs://metadata");
    }
}
