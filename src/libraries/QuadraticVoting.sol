// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library QuadraticVoting {
    function calculateVoteWeight(uint256 tokens) internal pure returns (uint256) {
        if (tokens == 0) return 0;
        return sqrt(tokens);
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function calculateCost(uint256 currentVotes, uint256 newVotes) internal pure returns (uint256) {
        if (newVotes <= currentVotes) return 0;
        uint256 currentCost = (currentVotes * (currentVotes + 1)) / 2;
        uint256 newCost = (newVotes * (newVotes + 1)) / 2;
        return newCost - currentCost;
    }
}

// libraries/StoryMath.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StoryMath {
    uint256 constant PERCENTAGE_BASE = 10000; // 100.00%

    function calculatePercentage(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        return (amount * percentage) / PERCENTAGE_BASE;
    }

    function calculateReaderReward(uint256 chaptersRead, uint256 totalChapters) internal pure returns (uint256) {
        if (totalChapters == 0) return 0;
        uint256 completionRate = (chaptersRead * PERCENTAGE_BASE) / totalChapters;
        return sqrt(completionRate);
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
