// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVotingManager {
    struct VotingRound {
        uint256 id;
        uint256 storyId;
        uint256 chapterNumber;
        uint256[] proposalIds;
        uint256 startTime;
        uint256 endTime;
        uint256 totalVotes;
        uint256 winningProposal;
        bool isFinalized;
    }

    struct Vote {
        address voter;
        uint256 proposalId;
        uint256 weight;
        uint256 timestamp;
    }

    function startVotingRound(uint256 storyId, uint256 chapterNumber, uint256[] calldata proposalIds) external;
    function castVote(uint256 roundId, uint256 proposalId, uint256 weight) external;
    function finalizeVoting(uint256 roundId) external;
    function getVotingRound(uint256 roundId) external view returns (VotingRound memory);
    function hasVoted(uint256 roundId, address voter) external view returns (bool);
}
