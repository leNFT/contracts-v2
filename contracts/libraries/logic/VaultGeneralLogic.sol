// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.21;

import {DataTypes} from "../types/DataTypes.sol";
import {PercentageMath} from "../utils/PercentageMath.sol";
import {SafeCast} from "../utils/SafeCast.sol";
import {IPricingCurve} from "../../interfaces/IPricingCurve.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {LiquidityToken} from "../../protocol/Trading/LiquidityToken.sol";
import "hardhat/console.sol";

library VaultGeneralLogic {
    event CreateLiquidityToken(
        address indexed nft,
        address indexed token,
        address indexed liquidityToken
    );

    function updateLp721AfterBuy(
        DataTypes.Liquidity721 memory liquidity,
        DataTypes.Liquidity721 storage liquidityPointer,
        uint256 fee,
        uint256 protocolFeePercentage,
        uint256 lp721Index
    ) external {
        // Update token amount in liquidity
        liquidityPointer.tokenAmount += SafeCast.toUint128(
            (liquidity.spotPrice +
                fee -
                PercentageMath.percentMul(fee, protocolFeePercentage))
        );
        // Update liquidity pair price
        if (liquidity.liquidityType != DataTypes.LiquidityType.TradeDown) {
            liquidityPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidity.curve).priceAfterBuy(
                    liquidity.spotPrice,
                    liquidity.delta,
                    liquidity.fee
                )
            );
        }

        liquidityPointer.nftIds[lp721Index] = liquidity.nftIds[
            liquidity.nftIds.length - 1
        ];
        liquidityPointer.nftIds.pop();
    }

    function updateLp1155AfterBuy(
        DataTypes.Liquidity1155 memory liquidity,
        DataTypes.Liquidity1155 storage liquidityPointer,
        uint256 fee,
        uint256 protocolFeePercentage
    ) external {
        liquidityPointer.tokenAmount += SafeCast.toUint128(
            (liquidity.spotPrice +
                fee -
                PercentageMath.percentMul(fee, protocolFeePercentage))
        );

        // Update liquidity pair price
        if (liquidity.liquidityType != DataTypes.LiquidityType.TradeDown) {
            liquidityPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidity.curve).priceAfterBuy(
                    liquidity.spotPrice,
                    liquidity.delta,
                    liquidity.fee
                )
            );
        }
    }

    function updateLiquidity721AfterSell(
        DataTypes.Liquidity721 memory liquidity,
        DataTypes.Liquidity721 storage liquidityPointer,
        uint256 protocolFeePercentage,
        uint256 tokenId721
    ) external {
        uint256 fee = PercentageMath.percentMul(
            liquidity.spotPrice,
            liquidity.fee
        );
        // Add nft to liquidity pair nft list
        liquidityPointer.nftIds.push(tokenId721);

        // Update token amount in liquidity pair
        liquidityPointer.tokenAmount -= SafeCast.toUint128(
            (liquidity.spotPrice -
                fee +
                PercentageMath.percentMul(fee, protocolFeePercentage))
        );

        // Update liquidity pair price
        if (liquidity.liquidityType != DataTypes.LiquidityType.TradeUp) {
            liquidityPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidity.curve).priceAfterSell(
                    liquidity.spotPrice,
                    liquidity.delta,
                    liquidity.fee
                )
            );
        }
    }

    function updateLiquidity1155AfterSell(
        DataTypes.Liquidity1155 memory liquidity,
        DataTypes.Liquidity1155 storage liquidityPointer,
        uint256 protocolFeePercentage,
        uint256 tokenAmount1155
    ) external {
        uint256 fee = PercentageMath.percentMul(
            liquidity.spotPrice,
            liquidity.fee
        );
        // Add token amount to liquidity  token amount
        liquidityPointer.tokenAmount += SafeCast.toUint128(tokenAmount1155);

        // Update token amount in liquidity
        liquidityPointer.tokenAmount -= SafeCast.toUint128(
            (liquidity.spotPrice -
                fee +
                PercentageMath.percentMul(fee, protocolFeePercentage))
        );
        // Update liquidity  price
        if (liquidity.liquidityType != DataTypes.LiquidityType.TradeUp) {
            liquidityPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidity.curve).priceAfterSell(
                    liquidity.spotPrice,
                    liquidity.delta,
                    liquidity.fee
                )
            );
        }
    }

    function initLiquidityToken(
        DataTypes.TokenStandard tokenStandard,
        address nft,
        address token
    ) external returns (address liquidityToken) {
        // Create the NFT LP contract if it doesn't exist
        string memory name = "leNFT2 Liquidity Token";
        string memory symbol = "leNFT2";
        string memory tokenSymbol = IERC20MetadataUpgradeable(token).symbol();
        string memory nftSymbol;

        if (tokenStandard == DataTypes.TokenStandard.ERC721) {
            nftSymbol = IERC721MetadataUpgradeable(nft).symbol();
        } else if (tokenStandard == DataTypes.TokenStandard.ERC1155) {
            // Make an external call to get the ERC1155 token's symbol
            (bool success, bytes memory data) = nft.staticcall(
                abi.encodeWithSignature("symbol()")
            );
            if (!success) {
                nftSymbol = "N/A";
            } else {
                // Decode the response
                nftSymbol = abi.decode(data, (string));
            }
        }

        // Deploy ERC721 LP contract
        liquidityToken = address(
            new LiquidityToken(
                string.concat(name, nftSymbol, "-", tokenSymbol),
                string.concat(symbol, nftSymbol, "-", tokenSymbol)
            )
        );

        emit CreateLiquidityToken(nft, token, liquidityToken);
    }
}
