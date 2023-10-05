//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.21;

import {IPricingCurve} from "../../../interfaces/IPricingCurve.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {PercentageMath} from "../../../libraries/utils/PercentageMath.sol";

/// @title LinearPriceCurve Contract
/// @author leNFT
/// @notice Calculates the price of a token based on a linear curve
/// @dev Contract module using for linear price curve logic
contract LinearPriceCurve is IPricingCurve, ERC165 {
    /// @notice Calculates the price after buying 1 token
    /// @param price The current price of the token
    /// @param delta The delta factor to increase the price
    /// @return The updated price after buying
    function priceAfterBuy(
        uint256 price,
        uint256 delta,
        uint256
    ) external pure override returns (uint256) {
        return price + delta;
    }

    function priceAfterMultipleBuys(
        uint256 amount,
        uint256 price,
        uint256 delta
    ) external pure override returns (uint256) {
        return price + delta * amount;
    }

    function buyPriceSum(
        uint256 amount,
        uint256 spotPrice,
        uint256 delta
    ) external pure override returns (uint256) {
        return (2 * spotPrice + amount * delta) / 2;
    }

    /// @notice Calculates the price after selling 1 token
    /// @param price The current price of the token
    /// @param delta The delta factor to decrease the price
    /// @return The updated price after selling
    function priceAfterSell(
        uint256 price,
        uint256 delta,
        uint256 fee
    ) external pure override returns (uint256) {
        // So we can't go to negative prices
        if (delta > price) {
            return price;
        }

        // If the next price makes it so the next buy price is lower than the current sell price we dont update
        if (
            (price - delta) * (PercentageMath.PERCENTAGE_FACTOR + fee) >
            price * (PercentageMath.PERCENTAGE_FACTOR - fee)
        ) {
            return price - delta;
        }

        return price;
    }

    function priceAfterMultipleSells(
        uint256 amount,
        uint256 price,
        uint256 delta,
        uint256 fee
    ) external pure override returns (uint256) {
        uint256 priceChange = delta * amount;
        // So we can't go to negative prices
        if (priceChange > price) {
            return price;
        }

        // If the next price makes it so the next buy price is lower than the current sell price we dont update
        if (
            (price - priceChange) * (PercentageMath.PERCENTAGE_FACTOR + fee) >
            price * (PercentageMath.PERCENTAGE_FACTOR - fee)
        ) {
            return price - priceChange;
        }

        return price;
    }

    function sellPriceSum(
        uint256 amount,
        uint256 spotPrice,
        uint256 delta
    ) external pure override returns (uint256) {
        uint256 priceChange = delta * amount;
        // So we can't go to negative prices
        if (priceChange > spotPrice) {
            return amount * spotPrice;
        }
        return (2 * spotPrice + amount * delta) / 2;
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
        require(spotPrice > 0, "LPC:VLP:INVALID_PRICE");
        require(delta < spotPrice, "LPC:VLP:INVALID_DELTA");

        if (fee > 0 && delta > 0) {
            // Make sure the liquidity can't be drained by buying and selling from the same liquidity
            require(
                (spotPrice - delta) * (PercentageMath.PERCENTAGE_FACTOR + fee) >
                    spotPrice * (PercentageMath.PERCENTAGE_FACTOR - fee),
                "LPC:VLP:INVALID_FEE_DELTA_RATIO"
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
