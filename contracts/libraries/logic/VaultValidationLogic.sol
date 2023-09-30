// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {DataTypes} from "../types/DataTypes.sol";
import {PercentageMath} from "../utils/PercentageMath.sol";
import {IPricingCurve} from "../../interfaces/IPricingCurve.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

error NotLiquidityOwner();
error WrongMessageValue();
error NFTMismatch();
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
error InvalidSwapFee();
error InvalidSwap1155();
error InvalidCurveParams();
error NonexistentLiquidity();

library VaultValidationLogic {
    uint256 constant MAX_FEE = 8000;

    using ERC165Checker for address;

    function validateAddLiquidityPair(
        DataTypes.LiquidityType liquidityType,
        DataTypes.TokenStandard tokenStandard,
        uint256 nftAmount,
        address token,
        uint256 tokenAmount,
        uint256 spotPrice,
        address curve,
        uint256 delta,
        uint256 fee,
        uint256 swapFee
    ) external view {
        // If the user is sending ETH we check the message value
        if (token == address(0) && msg.value != tokenAmount) {
            revert WrongMessageValue();
        }
        // Different types of liquidity pairs have different requirements
        // Trade: Can contain NFTs and/or tokens
        // TradeUp: Can contain NFTs and/or tokens, delta must be > 0
        // TradeDown: Can contain NFTs and/or tokens, delta must be > 0
        // Buy: Can only contain tokens
        // Sell: Can only contain NFTs
        if (
            (liquidityType == DataTypes.LiquidityType.Trade ||
                liquidityType == DataTypes.LiquidityType.TradeUp ||
                liquidityType == DataTypes.LiquidityType.TradeDown) &&
            (tokenAmount == 0 && nftAmount == 0)
        ) {
            revert EmptyDeposit();
        } else if (
            liquidityType == DataTypes.LiquidityType.Buy &&
            (tokenAmount == 0 || nftAmount > 0)
        ) {
            revert TokensOnly();
        } else if (
            (liquidityType == DataTypes.LiquidityType.Sell ||
                liquidityType == DataTypes.LiquidityType.Swap) &&
            (tokenAmount > 0 || nftAmount == 0)
        ) {
            revert NFTsOnly();
        }

        // Directional Liquidity must have a positive delta in order for the price to move or else
        // they degenerate into a Trade Liquidity with delta = 0
        if (
            (liquidityType == DataTypes.LiquidityType.TradeUp ||
                liquidityType == DataTypes.LiquidityType.TradeDown) &&
            delta == 0
        ) {
            revert InvalidDelta();
        }

        if (
            liquidityType == DataTypes.LiquidityType.Buy ||
            liquidityType == DataTypes.LiquidityType.Sell ||
            liquidityType == DataTypes.LiquidityType.Swap
        ) {
            // Validate fee
            if (fee > 0) {
                revert InvalidFee();
            }
        } else {
            // require that the fee is higher than 0 and less than the maximum fee
            if (fee == 0 || fee > MAX_FEE) {
                revert InvalidFee();
            }
        }

        // Require that the curve conforms to the curve interface
        if (liquidityType != DataTypes.LiquidityType.Swap) {
            if (
                !address(curve).supportsInterface(
                    type(IPricingCurve).interfaceId
                )
            ) {
                revert InvalidCurve();
            }
        } else if (curve != address(0)) {
            revert InvalidCurve();
        }

        // Validate LP params for chosen curve
        if (liquidityType != DataTypes.LiquidityType.Swap) {
            IPricingCurve(curve).validateLpParameters(spotPrice, delta, fee);
        } else if (spotPrice > 0 || delta > 0 || fee > 0) {
            revert InvalidCurveParams();
        }

        // Validate swap fee
        if (swapFee > MAX_FEE) {
            revert InvalidSwapFee();
        }

        if (liquidityType == DataTypes.LiquidityType.Swap && swapFee == 0) {
            revert InvalidSwapFee();
        }

        if (
            tokenStandard == DataTypes.TokenStandard.ERC1155 &&
            (swapFee != 0 || liquidityType == DataTypes.LiquidityType.Swap)
        ) {
            revert InvalidSwap1155();
        }
    }

    function validateRemoveLiquidity(
        address liquidityToken,
        uint256 liquidityId
    ) external view {
        if (msg.sender != IERC721(liquidityToken).ownerOf(liquidityId)) {
            revert NotLiquidityOwner();
        }
    }
}
