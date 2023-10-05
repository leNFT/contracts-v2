//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.21;

import {IPricingCurve} from "../../../interfaces/IPricingCurve.sol";
import {PercentageMath} from "../../../libraries/utils/PercentageMath.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import "hardhat/console.sol";

/// @title Exponential Price Curve Contract
/// @author leNFT
/// @notice This contract implements an exponential price curve
/// @dev Calculates the price after buying or selling tokens using the exponential price curve
contract ExponentialPriceCurve is IPricingCurve, ERC165 {
    uint256 private constant PRECISION = 1e18;

    /// @notice Calculates the price after buying 1 token
    /// @dev Meant to to be used for ERC721 trades
    /// @param price The current price of the token
    /// @param delta The delta factor to increase the price
    /// @return The updated price after buying
    function priceAfterBuy(
        uint256 price,
        uint256 delta,
        uint256
    ) external pure override returns (uint256) {
        return
            PercentageMath.percentMul(
                price,
                PercentageMath.PERCENTAGE_FACTOR + delta
            );
    }

    function priceAfterMultipleBuys(
        uint256 amount,
        uint256 price,
        uint256 delta
    ) external pure override returns (uint256) {
        return
            (price *
                FixedPointMathLib.rpow(
                    (PercentageMath.PERCENTAGE_FACTOR + delta) * PRECISION,
                    amount,
                    PercentageMath.PERCENTAGE_FACTOR * PRECISION
                )) / (PercentageMath.PERCENTAGE_FACTOR * PRECISION);
    }

    function buyPriceSum(
        uint256 amount,
        uint256 spotPrice,
        uint256 delta
    ) external pure override returns (uint256) {
        uint256 commonRatio = (PercentageMath.PERCENTAGE_FACTOR + delta) *
            PRECISION;

        // Use a geometric progression formula to calculate price sum
        return
            (spotPrice *
                (FixedPointMathLib.rpow(
                    commonRatio,
                    amount,
                    PercentageMath.PERCENTAGE_FACTOR * PRECISION
                ) - PercentageMath.PERCENTAGE_FACTOR * PRECISION)) /
            (commonRatio - PercentageMath.PERCENTAGE_FACTOR * PRECISION);
    }

    /// @notice Calculates the price after selling 1 token
    /// @dev Meant to be used for ERC721 trades
    /// @param price The current price of the token
    /// @param delta The delta factor to decrease the price
    /// @return The updated price after selling
    function priceAfterSell(
        uint256 price,
        uint256 delta,
        uint256
    ) external pure override returns (uint256) {
        return
            PercentageMath.percentDiv(
                price,
                PercentageMath.PERCENTAGE_FACTOR + delta
            );
    }

    function priceAfterMultipleSells(
        uint256 amount,
        uint256 price,
        uint256 delta,
        uint256
    ) external pure override returns (uint256) {
        return
            (price * PercentageMath.PERCENTAGE_FACTOR * PRECISION) /
            FixedPointMathLib.rpow(
                (PercentageMath.PERCENTAGE_FACTOR + delta) * PRECISION,
                amount,
                PercentageMath.PERCENTAGE_FACTOR * PRECISION
            );
    }

    function sellPriceSum(
        uint256 amount,
        uint256 spotPrice,
        uint256 delta
    ) external pure override returns (uint256) {
        uint256 commonRatio = (PRECISION *
            PercentageMath.PERCENTAGE_FACTOR ** 2) /
            (PercentageMath.PERCENTAGE_FACTOR + delta);

        // Use a geometric progression formula to calculate price sum
        return
            (spotPrice *
                (PRECISION *
                    PercentageMath.PERCENTAGE_FACTOR -
                    FixedPointMathLib.rpow(
                        commonRatio,
                        amount,
                        PRECISION * PercentageMath.PERCENTAGE_FACTOR
                    ))) /
            (PRECISION * PercentageMath.PERCENTAGE_FACTOR - commonRatio);
    }

    /// @notice Validates the parameters for a liquidity provider deposit
    /// @param spotPrice The initial spot price of the liquidity
    /// @param delta The delta of the liquidity
    /// @param fee The fee of the liquidity
    function validateLiquidityParameters(
        uint256 spotPrice,
        uint256 delta,
        uint256 fee
    ) external pure override {
        require(spotPrice > 0, "EPC:VLP:INVALID_PRICE");
        require(
            delta < PercentageMath.PERCENTAGE_FACTOR,
            "EPC:VLP:INVALID_DELTA"
        );
        if (fee > 0 && delta > 0) {
            // If this doesn't happen then a user would be able to profitably buy and sell from the same liquidity and drain its funds
            require(
                PercentageMath.PERCENTAGE_FACTOR *
                    (PercentageMath.PERCENTAGE_FACTOR + fee) >
                    (PercentageMath.PERCENTAGE_FACTOR + delta) *
                        (PercentageMath.PERCENTAGE_FACTOR - fee),
                "EPC:VLP:INVALID_FEE_DELTA_RATIO"
            );
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IPricingCurve).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
