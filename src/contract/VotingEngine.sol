// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./StoryRegistry.sol";
import "./interfaces/IChapterManager.sol";
import "./RewardDistributor.sol";
import "./StoryGameTypes.sol";
import "./Errors.sol";

/**
 * @title VotingEngine
 * @notice Handles voting rounds, tie-breaks & winner selection.
 */
contract VotingEngine is Ownable, ReentrancyGuard {
    using StoryGameTypes for *;

    StoryRegistry public immutable registry;
    IChapterManager public immutable chapters;
    RewardDistributor public immutable rewards;
    address public immutable controller;

    mapping(uint256 => uint256) public voteDeadline; // storyId => timestamp
    mapping(uint256 => mapping(address => bool)) public hasVoted; // chapterId => voter => bool
    mapping(uint256 => uint256) public chapterVotes; // chapterId => count

    modifier onlyController() {
        if (msg.sender != controller) revert StoryGameErrors.OnlyController();
        _;
    }

    event Voted(uint256 indexed chapterId, address indexed voter);
    event WinnerSelected(uint256 indexed storyId, uint256 indexed chapterId);

    constructor(
        address _registry,
        address _chapterMgr,
        address _reward,
        address _controller
    ) {
        registry = StoryRegistry(_registry);
        chapters = IChapterManager(_chapterMgr);
        rewards = RewardDistributor(_reward);
        controller = _controller;
    }

    // --------------------------------------------------
    // Called by Controller when user votes
    // --------------------------------------------------
    function vote(uint256 _chapterId, address _voter) external onlyController {
        require(!hasVoted[_chapterId][_voter], "double vote");
        hasVoted[_chapterId][_voter] = true;
        chapterVotes[_chapterId] += 1;
        chapters.updateChapterVotes(_chapterId, chapterVotes[_chapterId]);
        emit Voted(_chapterId, _voter);
    }

    // --------------------------------------------------
    // Finalize and pick winner – simplistic highest votes wins
    // --------------------------------------------------
    function finalize(uint256 _storyId, uint256[] calldata _proposalIds) external onlyController {
        require(_proposalIds.length > 0, "no proposals");
        uint256 winningChapter;
        uint256 maxVotes;
        for (uint256 i = 0; i < _proposalIds.length; i++) {
            uint256 c = _proposalIds[i];
            uint256 v = chapterVotes[c];
            if (v > maxVotes) {
                maxVotes = v;
                winningChapter = c;
            }
        }
        chapters.markChapterAsWinner(winningChapter);
        registry.incrementChapter(_storyId);
        emit WinnerSelected(_storyId, winningChapter);
    }
}
