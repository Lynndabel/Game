// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StoryRegistry.sol";
import "./ChapterManager.sol";
import "./VotingEngine.sol";
import "./RewardDistributor.sol";
import "./StoryNFT.sol";
import "./StoryGameController.sol";
import "./ContentValidator.sol";

/**
 * @title StoryGameDeployer
 * @notice Deploys and wires all StoryGame contracts in one transaction.
 */
contract StoryGameDeployer is Ownable {
    struct Contracts {
        StoryRegistry registry;
        ChapterManager chapters;
        VotingEngine voting;
        RewardDistributor rewards;
        StoryNFT nft;
        StoryGameController controller;
        ContentValidator validator;
    }

    Contracts public contracts;

    event Deployed(address controller);

    constructor() {
        // 1. Deploy validator first
        ContentValidator validator = new ContentValidator();
        // 2. Deploy registry with placeholder controller address (0) then update later
        StoryRegistry registry = new StoryRegistry(address(this));
        // 3. Deploy chapter manager
        ChapterManager chapters = new ChapterManager(address(registry), address(validator));
        // 4. Temporary addresses for voting and rewards
        RewardDistributor rewards = new RewardDistributor(address(registry), address(this));
        VotingEngine voting = new VotingEngine(address(registry), address(chapters), address(rewards), address(this));
        // 5. Deploy NFT
        StoryNFT nft = new StoryNFT(msg.sender);
        // 6. Deploy controller finally (real orchestrator)
        StoryGameController controller = new StoryGameController(
            address(registry),
            address(chapters),
            address(voting),
            address(rewards),
            address(nft),
            address(validator)
        );
        // 7. Transfer ownerships / roles
        registry.transferOwnership(msg.sender);
        chapters.transferOwnership(msg.sender);
        rewards.transferOwnership(msg.sender);
        voting.transferOwnership(msg.sender);
        nft.grantRole(nft.MINTER_ROLE(), address(chapters));

        // store
        contracts = Contracts({
            registry: registry,
            chapters: chapters,
            voting: voting,
            rewards: rewards,
            nft: nft,
            controller: controller,
            validator: validator
        });
        emit Deployed(address(controller));
    }
}
