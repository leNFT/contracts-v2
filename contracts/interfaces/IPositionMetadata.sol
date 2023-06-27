//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

interface IPositionMetadata {
    function tokenURI(
        address pool,
        uint256 tokenId
    ) external view returns (string memory);
}
