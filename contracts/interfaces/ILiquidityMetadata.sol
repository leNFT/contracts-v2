//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

interface ILiquidityMetadata {
    function tokenURI(
        uint256 liquidityId
    ) external view returns (string memory);
}