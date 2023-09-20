// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {DataTypes} from "../types/DataTypes.sol";
import {PercentageMath} from "../utils/PercentageMath.sol";
import {SafeCast} from "../utils/SafeCast.sol";
import {IPricingCurve} from "../../interfaces/IPricingCurve.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {LiquidityPoolToken} from "../../protocol/Trading/LiquidityPoolToken.sol";
import "hardhat/console.sol";

library VaultGeneralLogic {
    event CreateLiquidityPoolToken(
        address indexed nft,
        address indexed token,
        address indexed liquidityPoolToken
    );

    function updateLp721AfterBuy(
        DataTypes.LiquidityPair721 memory liquidityPair,
        DataTypes.LiquidityPair721 storage liquidityPairPointer,
        uint256 fee,
        uint256 protocolFeePercentage,
        uint256 lp721Index
    ) external {
        // Update token amount in liquidity pair
        liquidityPairPointer.tokenAmount += SafeCast.toUint128(
            (liquidityPair.spotPrice +
                fee -
                PercentageMath.percentMul(fee, protocolFeePercentage))
        );
        // Update liquidity pair price
        if (liquidityPair.lpType != DataTypes.LPType.TradeDown) {
            liquidityPairPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidityPair.curve).priceAfterBuy(
                    liquidityPair.spotPrice,
                    liquidityPair.delta,
                    liquidityPair.fee
                )
            );
        }

        liquidityPairPointer.nftIds[lp721Index] = liquidityPair.nftIds[
            liquidityPair.nftIds.length - 1
        ];
        liquidityPairPointer.nftIds.pop();
    }

    function updateLp1155AfterBuy(
        DataTypes.LiquidityPair1155 memory liquidityPair,
        DataTypes.LiquidityPair1155 storage liquidityPairPointer,
        uint256 fee,
        uint256 protocolFeePercentage
    ) external {
        liquidityPairPointer.tokenAmount += SafeCast.toUint128(
            (liquidityPair.spotPrice +
                fee -
                PercentageMath.percentMul(fee, protocolFeePercentage))
        );

        // Update liquidity pair price
        if (liquidityPair.lpType != DataTypes.LPType.TradeDown) {
            liquidityPairPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidityPair.curve).priceAfterBuy(
                    liquidityPair.spotPrice,
                    liquidityPair.delta,
                    liquidityPair.fee
                )
            );
        }
    }

    function updateLp721AfterSell(
        DataTypes.LiquidityPair721 memory liquidityPair,
        DataTypes.LiquidityPair721 storage liquidityPairPointer,
        uint256 fee,
        uint256 protocolFeePercentage,
        uint256 tokenId721
    ) external {
        // Add nft to liquidity pair nft list
        liquidityPairPointer.nftIds.push(tokenId721);

        // Update token amount in liquidity pair
        liquidityPairPointer.tokenAmount -= SafeCast.toUint128(
            (liquidityPair.spotPrice -
                fee +
                PercentageMath.percentMul(fee, protocolFeePercentage))
        );

        // Update liquidity pair price
        if (liquidityPair.lpType != DataTypes.LPType.TradeUp) {
            liquidityPairPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidityPair.curve).priceAfterSell(
                    liquidityPair.spotPrice,
                    liquidityPair.delta,
                    liquidityPair.fee
                )
            );
        }
    }

    function updateLp1155AfterSell(
        DataTypes.LiquidityPair1155 memory liquidityPair,
        DataTypes.LiquidityPair1155 storage liquidityPairPointer,
        uint256 fee,
        uint256 protocolFeePercentage,
        uint256 tokenAmount1155
    ) external {
        // Add token amount to liquidity pair token amount
        liquidityPairPointer.tokenAmount += SafeCast.toUint128(tokenAmount1155);

        // Update token amount in liquidity pair
        liquidityPairPointer.tokenAmount -= SafeCast.toUint128(
            (liquidityPair.spotPrice -
                fee +
                PercentageMath.percentMul(fee, protocolFeePercentage))
        );
        // Update liquidity pair price
        if (liquidityPair.lpType != DataTypes.LPType.TradeUp) {
            liquidityPairPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidityPair.curve).priceAfterSell(
                    liquidityPair.spotPrice,
                    liquidityPair.delta,
                    liquidityPair.fee
                )
            );
        }
    }

    function initLiquidityPoolToken(
        DataTypes.LiquidityType liquidityType,
        address nft,
        address token
    ) external returns (address liquidityPoolToken) {
        // Create the NFT LP contract if it doesn't exist
        string memory name;
        string memory symbol;
        string memory nftSymbol = IERC721MetadataUpgradeable(nft).symbol();
        string memory tokenSymbol = token != address(0)
            ? IERC20MetadataUpgradeable(token).symbol()
            : "ETH";

        if (
            liquidityType == DataTypes.LiquidityType.LP721 ||
            liquidityType == DataTypes.LiquidityType.LP1155
        ) {
            name = "leNFT2 Trading Pool ";
            symbol = "leT2";
        } else {
            name = "leNFT2 Swap Pool ";
            symbol = "leS2";
        }

        // Deploy ERC721 LP contract
        liquidityPoolToken = address(
            new LiquidityPoolToken(
                string.concat(name, nftSymbol, " - ", tokenSymbol),
                string.concat(symbol, nftSymbol, "-", tokenSymbol)
            )
        );

        emit CreateLiquidityPoolToken(nft, token, liquidityPoolToken);
    }
}
