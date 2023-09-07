//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

/// @title DataTypes library
/// @author leNFT
/// @notice Defines the data types used in the protocol
/// @dev Library with the data types used in the protocol
library DataTypes {
    /// @notice Enum of the liquidity pair types
    /// @dev Trade: Can buy and sell and price can increase and decrease
    /// @dev TradeUp: Can buy and sell and price can only increase
    /// @dev TradeDown: Can buy and sell and price can only decrease
    /// @dev Buy: Can only buy (price will only decrease)
    /// @dev Sell: Can only sell (price will only increase)
    enum LPType {
        Trade,
        TradeUp,
        TradeDown,
        Buy,
        Sell
    }

    /// @notice Struct to store the liquidity pair data
    /// @param lpType The type of liquidity pair
    /// @param nftIds The tokenIds of the assets
    /// @param tokenAmount The amount of tokens in the liquidity pair
    /// @param spotPrice The spot price of the liquidity pair
    /// @param curve The address of the curve
    /// @param delta The delta of the curve
    /// @param fee The fee for the buy/sell trades
    struct LiquidityPair721 {
        uint256[] nftIds;
        address token;
        address nft;
        uint128 tokenAmount;
        uint128 spotPrice;
        uint128 delta;
        address curve;
        uint16 fee;
        LPType lpType;
    }

    struct LiquidityPair1155 {
        LPType lpType;
        address token;
        address nft;
        uint256 nftId;
        uint256 nftAmount;
        uint256 tokenAmount;
        uint256 spotPrice;
        address curve;
        uint256 delta;
        uint256 fee;
    }

    struct SwapLiquidity {
        address token;
        address nft;
        uint256[] nftIds;
        uint256 fee;
        uint256 balance;
    }

    /// @notice Struct to store the working balance in gauges
    /// @param amount The amount of tokens
    /// @param weight The weight of the tokens
    /// @param timestamp The timestamp of the update
    struct WorkingBalance {
        uint128 amount;
        uint128 weight;
        uint40 timestamp;
    }

    /// @notice Struct to store the locked balance in the voting escrow
    /// @param amount The amount of tokens
    /// @param end The timestamp of the end of the lock
    struct LockedBalance {
        uint128 amount;
        uint40 end;
    }

    /// @notice Struct to store an abstract point in a weight curve
    /// @param bias The bias of the point
    /// @param slope The slope of the point
    /// @param timestamp The timestamp of the point
    struct Point {
        uint128 bias;
        uint128 slope;
        uint40 timestamp;
    }

    enum TokenStandard {
        ERC721,
        ERC1155
    }

    enum LiquidityType {
        LP721,
        LP1155,
        SL
    }

    struct SellRequest {
        uint256[] liquidityIds;
        uint256[] tokenIds721;
        uint256[] tokenAmounts1155;
        uint256 minimumPrice;
    }

    struct BuyRequest {
        uint256[] liquidityIds;
        uint256[] lp721Indexes;
        uint256[] lp721TokenIds;
        uint256[] lp1155Amounts;
        uint256 maximumPrice;
    }

    struct SwapRequest {
        uint256[] liquidityIds;
        uint256[] fromTokenIds721;
        uint256[] boughtLp721Indexes;
        uint256[] toTokenIds721;
        uint256[] toTokenIds721Indexes;
    }
}
