//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {PoseidonT3} from "./Poseidon.sol"; //an existing library to perform Poseidon hash on solidity
import "./verifier.sol"; //inherits with the MerkleTreeInclusionProof verifier contract

contract MerkleTree is Verifier {
    error TreeFull();

    uint256 public constant levels = 3;
    uint256[] public hashes; // the Merkle tree in flattened array form
    uint256 public index = 0; // the current index of the first unfilled leaf
    uint256 public root; // the current Merkle root

    constructor() {
        hashes = new uint256[](2**(levels + 1) - 1);

        uint256 child_start;
        for (uint256 level = levels; level > 0; --level) {
            uint256 parent_start = child_start + 2**level;

            for (uint256 i = 0; i < 2**(level - 1); ++i) {
                hashes[parent_start + i] = PoseidonT3.poseidon(
                    [hashes[child_start + i], hashes[child_start + i + 1]]
                );
            }

            child_start = parent_start;
        }

        root = hashes[hashes.length - 1];
    }

    function insertLeaf(uint256 hashedLeaf) public returns (uint256) {
        if (index == 2**levels) {
            revert TreeFull();
        }

        hashes[index] = hashedLeaf;

        uint256 start;
        uint256 current = index;
        for (uint256 level = levels; level > 0; --level) {
            uint256 child = start + current;
            uint256[2] memory input;

            uint256 hash;
            if (child % 2 == 0) {
                hash = PoseidonT3.poseidon([hashes[child], hashes[child + 1]]);
            } else {
                hash = PoseidonT3.poseidon([hashes[child - 1], hashes[child]]);
            }

            start += 2**level;
            current /= 2;
            hashes[start + current] = hash;
        }

        root = hashes[hashes.length - 1];

        index += 1;
    }

    function verify(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[1] memory input
    ) public view returns (bool) {
        if (input[0] != root || !verifyProof(a, b, c, input)) {
            return false;
        }

        return true;
    }
}
