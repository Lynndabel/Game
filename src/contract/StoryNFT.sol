// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title StoryNFT
 * @dev ERC721 token minted for each winning chapter.
 */
contract StoryNFT is ERC721URIStorage, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public nextTokenId = 1;

    constructor(address _admin) ERC721("StoryChapter", "STORY") {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function mint(address _to, string calldata _tokenURI) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }
}
