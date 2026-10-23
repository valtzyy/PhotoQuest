// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ChallengeRegistry
/// @notice Pencatatan hasil Steady Shot Challenge PhotoQuest di blockchain publik (Sepolia).
/// @dev Hanya pemilik (wallet relayer milik backend) yang boleh menulis. Siapa pun boleh membaca.
///      Angka desimal disimpan sebagai integer: holdSeconds x100, avgTilt x1000, avgShake x1000.
contract ChallengeRegistry {
    struct Record {
        uint256 attemptId; // id baris challenge_attempts di database
        uint256 userId;
        uint32 holdSeconds; // x100
        uint32 avgTilt; // x1000
        uint32 avgShake; // x1000
        bytes32 dataHash; // keccak256 dari data kanonik (dihitung backend)
        uint64 timestamp; // block.timestamp saat dicatat
    }

    address public immutable owner;
    Record[] private records;

    event ChallengeRecorded(
        uint256 indexed index,
        uint256 indexed attemptId,
        uint256 indexed userId,
        uint32 holdSeconds,
        uint32 avgTilt,
        uint32 avgShake,
        bytes32 dataHash
    );

    error NotOwner();
    error IndexOutOfRange();

    constructor() {
        owner = msg.sender;
    }

    function record(
        uint256 attemptId,
        uint256 userId,
        uint32 holdSeconds,
        uint32 avgTilt,
        uint32 avgShake,
        bytes32 dataHash
    ) external returns (uint256 index) {
        if (msg.sender != owner) revert NotOwner();
        index = records.length;
        records.push(Record(attemptId, userId, holdSeconds, avgTilt, avgShake, dataHash, uint64(block.timestamp)));
        emit ChallengeRecorded(index, attemptId, userId, holdSeconds, avgTilt, avgShake, dataHash);
    }

    function recordCount() external view returns (uint256) {
        return records.length;
    }

    function getRecord(uint256 index) external view returns (Record memory) {
        if (index >= records.length) revert IndexOutOfRange();
        return records[index];
    }
}
