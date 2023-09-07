// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {DataTypes} from "../types/DataTypes.sol";
import {PercentageMath} from "../utils/PercentageMath.sol";
import {IPricingCurve} from "../../interfaces/IPricingCurve.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

error NotPriceCurve();
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

library VaultValidationLogic {
    uint256 constant MAX_FEE = 8000;

    using ERC165Checker for address;

    function validateAddLiquidityPair(
        DataTypes.LPType lpType,
        uint256 nftAmount,
        address token,
        uint256 tokenAmount,
        uint256 spotPrice,
        address curve,
        uint256 delta,
        uint256 fee
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
            (lpType == DataTypes.LPType.Trade ||
                lpType == DataTypes.LPType.TradeUp ||
                lpType == DataTypes.LPType.TradeDown) &&
            (tokenAmount == 0 && nftAmount == 0)
        ) {
            revert EmptyDeposit();
        } else if (
            lpType == DataTypes.LPType.Buy &&
            (tokenAmount == 0 || nftAmount > 0)
        ) {
            revert TokensOnly();
        } else if (
            lpType == DataTypes.LPType.Sell &&
            (tokenAmount > 0 || nftAmount == 0)
        ) {
            revert NFTsOnly();
        }

        // Directional LPs must have a positive delta in order for the price to move or else
        // they degenerate into a Trade LPs with delta = 0
        if (
            (lpType == DataTypes.LPType.TradeUp ||
                lpType == DataTypes.LPType.TradeDown) && delta == 0
        ) {
            revert InvalidDelta();
        }

        if (lpType == DataTypes.LPType.Buy || lpType == DataTypes.LPType.Sell) {
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
        if (
            !address(curve).supportsInterface(type(IPricingCurve).interfaceId)
        ) {
            revert NotPriceCurve();
        }

        // Validate LP params for chosen curve
        IPricingCurve(curve).validateLpParameters(spotPrice, delta, fee);
    }

    function validateSwapSL(
        address slNft,
        address slToken,
        address nft,
        address token
    ) external pure {
        if (slNft != nft) {
            revert NFTMismatch();
        }
        if (slToken != token) {
            revert TokenMismatch();
        }
    }

    function validateSellLP(
        address lpToken,
        address sellToken,
        DataTypes.LPType lpType,
        uint256 spotPrice,
        uint256 tokenAmount,
        uint256 fee,
        uint256 protocolFeePercentage
    ) external pure {
        // Can't sell to sell LP
        if (lpType == DataTypes.LPType.Sell) {
            revert IsSellLP();
        }

        if (lpToken != sellToken) {
            revert TokenMismatch();
        }

        if (
            tokenAmount <
            spotPrice -
                fee +
                PercentageMath.percentMul(fee, protocolFeePercentage)
        ) {
            revert InsufficientTokensInLP();
        }
    }

    function validateBuyLP(
        address lpToken,
        address buyToken,
        DataTypes.LPType lpType
    ) external pure {
        // Make sure the token for the LP is the same
        if (lpToken != buyToken) {
            revert TokenMismatch();
        }

        // Can't buy from buy LP
        if (lpType == DataTypes.LPType.Buy) {
            revert IsBuyLP();
        }
    }

    function validateBuy(
        address token,
        uint256 maximumPrice,
        uint256[] memory liquidityIds,
        uint256[] memory lp721Indexes,
        uint256[] memory lp1155Amounts
    ) external view {
        if (liquidityIds.length == 0) {
            revert EmptyLiquidity();
        }
        // Make sure the length of the liquidityIds array matches the sum of the buyParams arrays
        if (lp721Indexes.length + lp1155Amounts.length != liquidityIds.length) {
            revert LiquidityMismatch();
        }

        if (token == address(0) && msg.value != maximumPrice) {
            revert WrongMessageValue();
        }
    }

    function validateSell(
        uint256[] memory liquidityIds,
        uint256[] memory lp721Indexes,
        uint256[] memory lp1155Amounts
    ) external pure {
        // Make sure the length of the liquidityIds array matches the sum of the buyParams arrays
        if (lp721Indexes.length + lp1155Amounts.length != liquidityIds.length) {
            revert LiquidityMismatch();
        }
    }

    function validateSwap(
        uint256[] calldata slLiquidityIds,
        uint256[] calldata fromTokenIds,
        uint256[] calldata toTokenIndexes
    ) external pure {
        if (slLiquidityIds.length == 0) {
            revert EmptyLiquidity();
        }
        if (
            slLiquidityIds.length != fromTokenIds.length ||
            slLiquidityIds.length != toTokenIndexes.length
        ) {
            revert LiquidityMismatch();
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
