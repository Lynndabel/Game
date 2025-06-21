// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProposalManager {
    struct Proposal {
        uint256 id;
        uint256 storyId;
        uint256 chapterNumber;
        uint256 branchId;
        address author;
        string title;
        string content;
        string ipfsHash;
        uint256 submissionTime;
        uint256 votes;
        bool isActive;
        ProposalType proposalType;
    }

    enum ProposalType {
        CONTINUATION,
        BRANCH,
        REMIX,
        MERGE
    }

    function submitProposal(
        uint256 storyId,
        uint256 chapterNumber,
        uint256 branchId,
        string calldata title,
        string calldata content,
        string calldata ipfsHash,
        ProposalType proposalType
    ) external returns (uint256);

    function getProposal(uint256 proposalId) external view returns (Proposal memory);
    function getChapterProposals(uint256 storyId, uint256 chapterNumber) external view returns (uint256[] memory);
    function updateProposalVotes(uint256 proposalId, uint256 votes) external;
}