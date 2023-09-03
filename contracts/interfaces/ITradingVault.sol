//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {DataTypes} from "../libraries/types/DataTypes.sol";

interface ITradingVault {
    function getLP721(
        uint256 liquidityId
    ) external view returns (DataTypes.LiquidityPair721 memory);

    function getLP1155(
        uint256 liquidityId
    ) external view returns (DataTypes.LiquidityPair1155 memory);

    function getSL(
        uint256 liquidityId
    ) external view returns (DataTypes.SwapLiquidity memory);
}
