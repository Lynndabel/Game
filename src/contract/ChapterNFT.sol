// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interface/IChapterNFT.sol";
import "./error/StoryErrors.sol";
import "./error/AccessErrors.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ChapterNFT is IChapterNFT, ERC721, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    uint256 private _tokenCounter;
    
    mapping(uint256 => ChapterMetadata) private _chapterMetadata;
    mapping(uint256 => uint256[]) private _storyChapters;
    mapping(address => uint256[]) private _authorChapters;

    event ChapterMinted(uint256 indexed tokenId, uint256 indexed storyId, address indexed author);
    event ChapterUpdated(uint256 indexed tokenId, uint256 votes, bool canonical);

    constructor() ERC721("StoryChapter", "SCHP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
    }

    function mintChapter(
        address to,
        uint256 storyId,
        uint256 chapterNumber,
        uint256 branchId,
        string calldata content,
        string calldata ipfsHash
    ) external onlyRole(MINTER_ROLE) nonReentrant returns (uint256) {
        if (to == address(0)) revert InvalidAddress(to);
        
        uint256 tokenId = ++_tokenCounter;
        
        _chapterMetadata[tokenId] = ChapterMetadata({
            storyId: storyId,
            chapterNumber: chapterNumber,
            branchId: branchId,
            content: content,
            author: to,
            votesReceived: 0,
            mintTimestamp: block.timestamp,
            ipfsHash: ipfsHash,
            isCanonical: false
        });
        
        _storyChapters[storyId].push(tokenId);
        _authorChapters[to].push(tokenId);
        
        _safeMint(to, tokenId);
        
        emit ChapterMinted(tokenId, storyId, to);
        return tokenId;
    }

    function getChapterMetadata(uint256 tokenId) external view returns (ChapterMetadata memory) {
        if (!_exists(tokenId)) revert StoryNotFound(tokenId);
        return _chapterMetadata[tokenId];
    }

    function getStoryChapters(uint256 storyId) external view returns (uint256[] memory) {
        return _storyChapters[storyId];
    }

    function setCanonical(uint256 tokenId, bool canonical) external onlyRole(UPDATER_ROLE) {
        if (!_exists(tokenId)) revert StoryNotFound(tokenId);
        _chapterMetadata[tokenId].isCanonical = canonical;
        emit ChapterUpdated(tokenId, _chapterMetadata[tokenId].votesReceived, canonical);
    }

    function updateVoteCount(uint256 tokenId, uint256 votes) external onlyRole(UPDATER_ROLE) {
        if (!_exists(tokenId)) revert StoryNotFound(tokenId);
        _chapterMetadata[tokenId].votesReceived = votes;
        emit ChapterUpdated(tokenId, votes, _chapterMetadata[tokenId].isCanonical);
    }

    function getAuthorChapters(address author) external view returns (uint256[] memory) {
        return _authorChapters[author];
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}
