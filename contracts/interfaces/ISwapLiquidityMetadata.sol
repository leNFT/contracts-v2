//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

interface ISwapLiquidityMetadata {
    function tokenURI(
        address swapPool,
        uint256 tokenId
    ) external view returns (string memory);
}
