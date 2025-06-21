// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interface/IVotingManager.sol";
import "../interface/IStoryGovernance.sol";
import "../error/VotingErrors.sol";
import "../libraries/QuadraticVoting.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VotingManager is IVotingManager, AccessControl, ReentrancyGuard {
    bytes32 public constant VOTING_ADMIN_ROLE = keccak256("VOTING_ADMIN_ROLE");
    
    uint256 private _roundCounter;
    uint256 public votingDuration = 3 days;
    
    IERC20 public immutable storyToken;
    
    mapping(uint256 => VotingRound) private _votingRounds;
    mapping(uint256 => mapping(address => bool)) private _hasVoted;
    mapping(uint256 => mapping(uint256 => uint256)) private _proposalVotes;
    mapping(uint256 => Vote[]) private _roundVotes;

    event VotingRoundStarted(uint256 indexed roundId, uint256 indexed storyId, uint256 chapterNumber);
    event VoteCast(uint256 indexed roundId, address indexed voter, uint256 indexed proposalId, uint256 weight);
    event VotingFinalized(uint256 indexed roundId, uint256 winningProposal);

    constructor(address _storyToken) {
        if (_storyToken == address(0)) revert InvalidAddress(_storyToken);
        storyToken = IERC20(_storyToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VOTING_ADMIN_ROLE, msg.sender);
    }

    function startVotingRound(uint256 storyId, uint256 chapterNumber, uint256[] calldata proposalIds) 
        external 
        onlyRole(VOTING_ADMIN_ROLE) 
        nonReentrant 
    {
        if (proposalIds.length == 0) revert NoProposalsInRound(0);
        
        uint256 roundId = ++_roundCounter;
        
        _votingRounds[roundId] = VotingRound({
            id: roundId,
            storyId: storyId,
            chapterNumber: chapterNumber,
            proposalIds: proposalIds,
            startTime: block.timestamp,
            endTime: block.timestamp + votingDuration,
            totalVotes: 0,
            winningProposal: 0,
            isFinalized: false
        });
        
        emit VotingRoundStarted(roundId, storyId, chapterNumber);
    }

    function castVote(uint256 roundId, uint256 proposalId, uint256 weight) 
        external 
        nonReentrant 
    {
        VotingRound storage round = _votingRounds[roundId];
        if (round.id == 0) revert VotingRoundNotFound(roundId);
        if (block.timestamp < round.startTime) revert VotingRoundNotStarted(roundId);
        if (block.timestamp > round.endTime) revert VotingRoundExpired(roundId);
        if (_hasVoted[roundId][msg.sender]) revert AlreadyVoted(msg.sender, roundId);
        
        bool validProposal = false;
        for (uint256 i = 0; i < round.proposalIds.length; i++) {
            if (round.proposalIds[i] == proposalId) {
                validProposal = true;
                break;
            }
        }
        if (!validProposal) revert InvalidProposal(proposalId);
        
        uint256 userBalance = storyToken.balanceOf(msg.sender);
        uint256 maxWeight = QuadraticVoting.calculateVoteWeight(userBalance);
        if (weight > maxWeight) revert InsufficientVotingPower(msg.sender, weight);
        
        _hasVoted[roundId][msg.sender] = true;
        _proposalVotes[roundId][proposalId] += weight;
        round.totalVotes += weight;
        
        _roundVotes[roundId].push(Vote({
            voter: msg.sender,
            proposalId: proposalId,
            weight: weight,
            timestamp: block.timestamp
        }));
        
        emit VoteCast(roundId, msg.sender, proposalId, weight);
    }

    function finalizeVoting(uint256 roundId) external onlyRole(VOTING_ADMIN_ROLE) {
        VotingRound storage round = _votingRounds[roundId];
        if (round.id == 0) revert VotingRoundNotFound(roundId);
        if (block.timestamp <= round.endTime) revert VotingRoundNotStarted(roundId);
        if (round.isFinalized) revert VotingRoundAlreadyFinalized(roundId);
        
        uint256 winningProposal = 0;
        uint256 maxVotes = 0;
        
        for (uint256 i = 0; i < round.proposalIds.length; i++) {
            uint256 proposalId = round.proposalIds[i];
            uint256 votes = _proposalVotes[roundId][proposalId];
            if (votes > maxVotes) {
                maxVotes = votes;
                winningProposal = proposalId;
            }
        }
        
        round.winningProposal = winningProposal;
        round.isFinalized = true;
        
        emit VotingFinalized(roundId, winningProposal);
    }

    function getVotingRound(uint256 roundId) external view returns (VotingRound memory) {
        VotingRound memory round = _votingRounds[roundId];
        if (round.id == 0) revert VotingRoundNotFound(roundId);
        return round;
    }

    function hasVoted(uint256 roundId, address voter) external view returns (bool) {
        return _hasVoted[roundId][voter];
    }

    function getProposalVotes(uint256 roundId, uint256 proposalId) external view returns (uint256) {
        return _proposalVotes[roundId][proposalId];
    }

    function setVotingDuration(uint256 _duration) external onlyRole(VOTING_ADMIN_ROLE) {
        votingDuration = _duration;
    }
}
