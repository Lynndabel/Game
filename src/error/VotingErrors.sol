// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error VotingRoundNotFound(uint256 roundId);
error VotingRoundExpired(uint256 roundId);
error VotingRoundNotStarted(uint256 roundId);
error AlreadyVoted(address voter, uint256 roundId);
error InsufficientVotingPower(address voter, uint256 required);
error InvalidProposal(uint256 proposalId);
error VotingRoundAlreadyFinalized(uint256 roundId);
error NoProposalsInRound(uint256 roundId);