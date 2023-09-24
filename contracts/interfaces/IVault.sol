//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {DataTypes} from "../libraries/types/DataTypes.sol";

interface IVault {
    error NotPriceCurve();
    error NotLiquidityOwner();
    error WrongMessageValue();
    error TokenMismatch();
    error EmptyLiquidity();
    error LiquidityMismatch();
    error IsBuyLP();
    error IsSellLP();
    error InsufficientTokensInLP();
    error EmptyDeposit();
    error TokensOnly();
    error NFTsOnly();
    error InvalidDelta();
    error InvalidCurve();
    error InvalidFee();
    error MaxPriceExceeded();
    error MinPriceNotReached();
    error ETHTransferFailed();
    error NFTMismatch();
    error Paused();
    error NonexistentLiquidity();
    event AddLiquidity(
        address indexed user,
        DataTypes.LiquidityType indexed liquidityType,
        address indexed liquidityToken,
        uint256 liquidityId
    );

    event RemoveLiquity(
        address indexed user,
        address indexed liquidityToken,
        uint256 indexed liquidityId
    );
    event CreateLiquidityToken(
        address indexed nft,
        address indexed token,
        address indexed liquidityToken
    );

    event Sell(
        address indexed user,
        uint256[] liquidityIds,
        uint256[] tokenIds721,
        uint256[] tokenAmounts1155,
        uint256 price
    );

    event Buy(
        address indexed user,
        uint256[] liquidityIds,
        uint256[] tokenIds721,
        uint256[] tokenAmounts1155,
        uint256 price
    );

    event Swap(
        address indexed user,
        uint256[] liquidityIds,
        uint256[] fromTokenIds721,
        uint256[] boughtLp721Indexes,
        uint256[] toTokenIds721
    );

    function getLiquidityToken(
        uint256 liquidityId
    ) external view returns (address);

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
