// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ContentValidator
 * @dev Simple profanity filter & duplicate checker. In production replace with
 *      more sophisticated off-chain moderation.
 */
contract ContentValidator is Ownable {
    mapping(bytes32 => bool) public bannedWords;

    event BannedWordAdded(string word);
    event BannedWordRemoved(string word);

    constructor() {
        // seed with a few placeholders
        bannedWords[keccak256(bytes("badword1"))] = true;
        bannedWords[keccak256(bytes("badword2"))] = true;
    }

    /**
     * @notice Validate the given UTF-8 string.
     * @return true if OK, false if any banned word is found.
     */
    function validateContent(string calldata _content) external view returns (bool) {
        // *** NOTE ***  extremely naive implementation – splits only by space.
        bytes memory raw = bytes(_content);
        bytes memory buffer;
        for (uint256 i = 0; i < raw.length; i++) {
            byte b = raw[i];
            if (b == 0x20 /* space */) {
                if (_isBanned(buffer)) return false;
                delete buffer;
            } else {
                buffer.push(b);
            }
        }
        // last word
        if (_isBanned(buffer)) return false;
        return true;
    }

    function addBannedWord(string calldata _word) external onlyOwner {
        bannedWords[keccak256(bytes(_toLower(_word)))] = true;
        emit BannedWordAdded(_word);
    }

    function removeBannedWord(string calldata _word) external onlyOwner {
        bannedWords[keccak256(bytes(_toLower(_word)))] = false;
        emit BannedWordRemoved(_word);
    }

    // --------------------------------------------------
    // internal helpers
    // --------------------------------------------------
    function _isBanned(bytes memory word) internal view returns (bool) {
        if (word.length == 0) return false;
        return bannedWords[keccak256(_toLower(word))];
    }

    function _toLower(string memory str) internal pure returns (bytes memory) {
        return _toLower(bytes(str));
    }

    function _toLower(bytes memory str) internal pure returns (bytes memory) {
        bytes memory lower = new bytes(str.length);
        for (uint256 i = 0; i < str.length; i++) {
            bytes1 c = str[i];
            if (c >= 0x41 && c <= 0x5A) {
                lower[i] = bytes1(uint8(c) + 32);
            } else {
                lower[i] = c;
            }
        }
        return lower;
    }
}
