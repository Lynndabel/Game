// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contract/StoryRegistry.sol";
import "../contract/ChapterNFT.sol";
import "../contract/VotingManager.sol";
import "../governance/ProposalManager.sol";

/**
 * @title StoryPlatformRouter
 * @notice A minimal router that provides read-only access to the core
 *         contracts deployed by `StoryPlatformFactory`. Extend or replace
 *         this implementation as your platform grows.
 */
contract StoryPlatformRouter {
    StoryRegistry public immutable storyRegistry;
    ChapterNFT public immutable chapterNFT;
    VotingManager public immutable votingManager;
    ProposalManager public immutable proposalManager;

    constructor(
        address _storyRegistry,
        address _chapterNFT,
        address _votingManager,
        address _proposalManager
    ) {
        storyRegistry = StoryRegistry(_storyRegistry);
        chapterNFT = ChapterNFT(_chapterNFT);
        votingManager = VotingManager(_votingManager);
        proposalManager = ProposalManager(_proposalManager);
    }

    // ---------------------------------------------------------------------
    // Future routing / helper functions can be added below
    // ---------------------------------------------------------------------
}
