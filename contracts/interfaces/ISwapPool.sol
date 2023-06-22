//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {DataTypes} from "../libraries/types/DataTypes.sol";

interface ISwapPool {
    event AddLiquidity(
        address indexed user,
        uint256 indexed id,
        uint256[] nftIds,
        uint256 fee
    );
    event RemoveLiquidity(address indexed user, uint256 indexed lpId);

    event Swap(
        address indexed user,
        uint256[] sendNftIds,
        uint256[] receiveNftIds,
        uint256 totalFee
    );

    function getNFT() external view returns (address);

    function getFeeToken() external view returns (address);

    function swap(
        address onBehalfOf,
        uint256[] calldata sendNftIds,
        uint256[] calldata receiveNftIds
    ) external returns (uint256);

    function getSL(uint256 slId) external view;
}
