//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.21;

import {DataTypes} from "../libraries/types/DataTypes.sol";

interface IVault {
    error NotPriceCurve();
    error NotLiquidityOwner();
    error WrongMessageValue();
    error TokenMismatch();
    error EmptyLiquidity();
    error LiquidityMismatch();
    error IncompatibleLiquidity(uint256 liquidityId);
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
        DataTypes.TokenStandard indexed tokenStandard,
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

    function getLiquidity721(
        uint256 liquidityId
    ) external view returns (DataTypes.Liquidity721 memory);

    function getLiquidity1155(
        uint256 liquidityId
    ) external view returns (DataTypes.Liquidity1155 memory);
}
