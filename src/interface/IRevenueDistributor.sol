// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRevenueDistributor {
    struct RevenueShare {
        address recipient;
        uint256 percentage;
        uint256 amount;
        bool claimed;
    }

    function distributeRevenue(uint256 chapterId, uint256 totalRevenue) external;
    function claimRevenue(uint256 chapterId) external;
    function getRevenueShare(uint256 chapterId, address recipient) external view returns (uint256);
    function setRevenuePercentages(uint256 authorShare, uint256 voterShare, uint256 platformShare) external;
}