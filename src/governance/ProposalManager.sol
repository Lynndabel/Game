// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interface/IProposalManager.sol";
import "../error/StoryErrors.sol";
import "../error/AccessErrors.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ProposalManager is IProposalManager, AccessControl, ReentrancyGuard {
    bytes32 public constant PROPOSAL_ADMIN_ROLE = keccak256("PROPOSAL_ADMIN_ROLE");

    uint256 private _proposalCounter;
    uint256 public submissionFee = 0.01 ether;
    uint256 public proposalDeadline = 2 days;

    mapping(uint256 => Proposal) private _proposals;
    mapping(uint256 => mapping(uint256 => uint256[])) private _chapterProposals; // storyId => chapterNumber => proposalIds
    mapping(address => uint256[]) private _authorProposals;
    mapping(uint256 => bool) private _activeProposals;

    event ProposalSubmitted(uint256 indexed proposalId, uint256 indexed storyId, address indexed author);
    event ProposalUpdated(uint256 indexed proposalId, uint256 votes);
    event ProposalActivated(uint256 indexed proposalId);
    event ProposalDeactivated(uint256 indexed proposalId);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSAL_ADMIN_ROLE, msg.sender);
    }

    function submitProposal(
        uint256 storyId,
        uint256 chapterNumber,
        uint256 branchId,
        string calldata title,
        string calldata content,
        string calldata ipfsHash,
        ProposalType proposalType
    ) external payable nonReentrant returns (uint256) {
        if (msg.value < submissionFee) revert Unauthorized(msg.sender);
        if (bytes(title).length == 0 || bytes(content).length == 0) revert InvalidStoryData();

        uint256 proposalId = ++_proposalCounter;

        _proposals[proposalId] = Proposal({
            id: proposalId,
            storyId: storyId,
            chapterNumber: chapterNumber,
            branchId: branchId,
            author: msg.sender,
            title: title,
            content: content,
            ipfsHash: ipfsHash,
            submissionTime: block.timestamp,
            votes: 0,
            isActive: true,
            proposalType: proposalType
        });

        _chapterProposals[storyId][chapterNumber].push(proposalId);
        _authorProposals[msg.sender].push(proposalId);
        _activeProposals[proposalId] = true;

        emit ProposalSubmitted(proposalId, storyId, msg.sender);
        return proposalId;
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        Proposal memory proposal = _proposals[proposalId];
        if (proposal.id == 0) revert InvalidProposal(proposalId);
        return proposal;
    }

    function getChapterProposals(uint256 storyId, uint256 chapterNumber) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return _chapterProposals[storyId][chapterNumber];
    }

    function updateProposalVotes(uint256 proposalId, uint256 votes) 
        external 
        onlyRole(PROPOSAL_ADMIN_ROLE) 
    {
        if (_proposals[proposalId].id == 0) revert InvalidProposal(proposalId);
        _proposals[proposalId].votes = votes;
        emit ProposalUpdated(proposalId, votes);
    }

    function deactivateProposal(uint256 proposalId) external onlyRole(PROPOSAL_ADMIN_ROLE) {
        if (_proposals[proposalId].id == 0) revert InvalidProposal(proposalId);
        _proposals[proposalId].isActive = false;
        _activeProposals[proposalId] = false;
        emit ProposalDeactivated(proposalId);
    }

    function getAuthorProposals(address author) external view returns (uint256[] memory) {
        return _authorProposals[author];
    }

    function setSubmissionFee(uint256 _fee) external onlyRole(PROPOSAL_ADMIN_ROLE) {
        submissionFee = _fee;
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }
}
