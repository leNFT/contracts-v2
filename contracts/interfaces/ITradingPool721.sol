//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {DataTypes} from "../libraries/types/DataTypes.sol";
import {ITradingPool} from "./ITradingPool.sol";

interface ITradingPool721 is ITradingPool {
    event AddLiquidity(
        address indexed user,
        uint256 indexed id,
        DataTypes.LPType indexed lpType,
        uint256[] nftIds,
        uint256 tokenAmount,
        uint256 spotPrice,
        address curve,
        uint256 delta,
        uint256 fee
    );
    event RemoveLiquidity(address indexed user, uint256 indexed lpId);

    event Buy(address indexed user, uint256[] nftIds, uint256 price);

    event Sell(address indexed user, uint256[] nftIds, uint256 price);

    function addLiquidity(
        address receiver,
        DataTypes.LPType lpType,
        uint256[] memory nftIds,
        uint256 tokenAmount,
        uint256 initialPrice,
        address curve,
        uint256 delta,
        uint256 fee
    ) external;

    function removeLiquidity(uint256 lpId) external;

    function removeLiquidityBatch(uint256[] memory lpIds) external;

    function buy(
        address onBehalfOf,
        uint256[] memory nftIds,
        uint256 maximumPrice
    ) external returns (uint256);

    function sell(
        address onBehalfOf,
        uint256[] memory nftIds,
        uint256[] memory liquidityPairs,
        uint256 minimumPrice
    ) external returns (uint256);

    function getLP(
        uint256 lpId
    ) external view returns (DataTypes.LiquidityPair721 memory);

    function nftToLp(uint256 nftId) external view returns (uint256);
}
