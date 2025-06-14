// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./StoryRegistry.sol";
import "./StoryGameTypes.sol";
import "./Errors.sol";

/**
 * @title RewardDistributor
 * @dev Processes all payments, manages treasury & refunds.
 */
contract RewardDistributor is Ownable, ReentrancyGuard {
    using StoryGameTypes for *;

    StoryRegistry public immutable registry;
    address public immutable controller;

    uint256 public treasuryBalance;
    mapping(uint256 => uint256) public abandonedStoryRewards;
    mapping(uint256 => mapping(address => uint256)) public voterContributions;

    modifier onlyController() {
        if (msg.sender != controller) revert StoryGameErrors.OnlyController();
        _;
    }

    event FeeCollected(uint256 indexed storyId, uint256 amount);
    event Payout(uint256 indexed storyId, uint256 winnerReward, uint256 creatorReward);
    event RefundClaimed(uint256 indexed storyId, address indexed voter, uint256 amount);

    constructor(address _registry, address _controller) {
        require(_registry != address(0) && _controller != address(0), "zero addr");
        registry = StoryRegistry(_registry);
        controller = _controller;
    }

    // --------------------------------------------------
    // Called by Controller to move ETH into the pool
    // --------------------------------------------------
    function collectFee(uint256 _storyId) external payable onlyController {
        treasuryBalance += msg.value;
        voterContributions[_storyId][tx.origin] += msg.value; // simplistic
        emit FeeCollected(_storyId, msg.value);
    }

    // --------------------------------------------------
    // Called by VotingEngine after winner determined
    // --------------------------------------------------
    function payOut(
        uint256 _storyId,
        address _winner,
        address _creator,
        uint256 _totalReward
    ) external onlyController nonReentrant {
        // 40 / 20 / 25 / 15 split of _totalReward for now
        uint256 winnerShare = (_totalReward * 40) / 100;
        uint256 creatorShare = (_totalReward * 20) / 100;
        uint256 treasuryShare = _totalReward - winnerShare - creatorShare;
        treasuryBalance += treasuryShare;
        (bool s1, ) = _winner.call{value: winnerShare}("");
        if (!s1) revert StoryGameErrors.TransferFailed();
        (bool s2, ) = _creator.call{value: creatorShare}("");
        if (!s2) revert StoryGameErrors.TransferFailed();
        emit Payout(_storyId, winnerShare, creatorShare);
    }

    // --------------------------------------------------
    // Called by Controller when story is marked abandoned.
    // --------------------------------------------------
    function registerAbandoned(uint256 _storyId, uint256 _amount) external onlyController {
        abandonedStoryRewards[_storyId] = _amount;
    }

    function claimRefund(uint256 _storyId) external nonReentrant {
        uint256 contrib = voterContributions[_storyId][msg.sender];
        require(contrib > 0, "no contrib");
        require(abandonedStoryRewards[_storyId] >= contrib, "insufficient pool");
        voterContributions[_storyId][msg.sender] = 0;
        abandonedStoryRewards[_storyId] -= contrib;
        (bool ok, ) = msg.sender.call{value: contrib}("");
        if (!ok) revert StoryGameErrors.TransferFailed();
        emit RefundClaimed(_storyId, msg.sender, contrib);
    }

    function withdrawTreasury(uint256 _amount) external onlyOwner {
        require(_amount <= treasuryBalance, "exceeds");
        treasuryBalance -= _amount;
        (bool ok, ) = owner().call{value: _amount}("");
        if (!ok) revert StoryGameErrors.TransferFailed();
    }

    // fallback
    receive() external payable {
        treasuryBalance += msg.value;
    }
}
