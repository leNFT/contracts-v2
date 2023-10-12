// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.21;

import {DataTypes} from "../types/DataTypes.sol";
import {PercentageMath} from "../utils/PercentageMath.sol";
import {SafeCast} from "../utils/SafeCast.sol";
import {IPricingCurve} from "../../interfaces/IPricingCurve.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {LiquidityToken} from "../../protocol/Trading/LiquidityToken.sol";

library VaultGeneralLogic {
    event CreateLiquidityToken(
        address indexed nft,
        address indexed token,
        address indexed liquidityToken
    );

    function updateLiquidity721AfterBuy(
        DataTypes.Liquidity721 memory liquidity,
        DataTypes.Liquidity721 storage liquidityPointer,
        uint256 fee,
        uint256 protocolFeePercentage,
        uint256 liquidity721Index
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

        liquidityPointer.nftIds[liquidity721Index] = liquidity.nftIds[
            liquidity.nftIds.length - 1
        ];
        liquidityPointer.nftIds.pop();
    }

    function updateLiquidity1155AfterBuy(
        DataTypes.Liquidity1155 memory liquidity,
        DataTypes.Liquidity1155 storage liquidityPointer,
        uint256 price,
        uint256 feeAmount,
        uint256 protocolFeePercentage,
        uint256 nftAmount
    ) external {
        liquidityPointer.tokenAmount += SafeCast.toUint128(
            (price +
                feeAmount -
                PercentageMath.percentMul(feeAmount, protocolFeePercentage))
        );

        // Update liquidity pair price
        if (liquidity.liquidityType != DataTypes.LiquidityType.TradeDown) {
            liquidityPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidity.curve).priceAfterMultipleBuys(
                    nftAmount,
                    liquidity.spotPrice,
                    liquidity.delta
                )
            );
        }
    }

    function updateLiquidity721AfterSell(
        DataTypes.Liquidity721 memory liquidity,
        DataTypes.Liquidity721 storage liquidityPointer,
        uint256 feeAmount,
        uint256 protocolFeePercentage,
        uint256 tokenId721
    ) external {
        // Add nft to liquidity pair nft list
        liquidityPointer.nftIds.push(tokenId721);

        // Update token amount in liquidity pair
        liquidityPointer.tokenAmount -= SafeCast.toUint128(
            (liquidity.spotPrice -
                feeAmount +
                PercentageMath.percentMul(feeAmount, protocolFeePercentage))
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
        uint256 price,
        uint256 feeAmount,
        uint256 protocolFeePercentage,
        uint256 nftAmount
    ) external {
        // Add token amount to liquidity  token amount
        liquidityPointer.nftAmount += SafeCast.toUint128(nftAmount);

        // Update token amount in liquidity
        liquidityPointer.tokenAmount -= SafeCast.toUint128(
            (price -
                feeAmount +
                PercentageMath.percentMul(feeAmount, protocolFeePercentage))
        );
        // Update liquidity  price
        if (liquidity.liquidityType != DataTypes.LiquidityType.TradeUp) {
            liquidityPointer.spotPrice = SafeCast.toUint128(
                IPricingCurve(liquidity.curve).priceAfterMultipleSells(
                    nftAmount,
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
        // Create the NFT Liquidity contract if it doesn't exist
        string memory name = "leNFT2 Liquidity Token";
        string memory symbol = "leNFT2";
        string memory tokenSymbol = IERC20Metadata(token).symbol();
        string memory nftSymbol;

        if (tokenStandard == DataTypes.TokenStandard.ERC721) {
            nftSymbol = IERC721Metadata(nft).symbol();
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

        // Deploy ERC721 liquidity contract
        liquidityToken = address(
            new LiquidityToken(
                string.concat(name, nftSymbol, "-", tokenSymbol),
                string.concat(symbol, nftSymbol, "-", tokenSymbol)
            )
        );

        emit CreateLiquidityToken(nft, token, liquidityToken);
    }
}
