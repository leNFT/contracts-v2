// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";
import {ITradingPool} from "../../interfaces/ITradingPool.sol";
import {ITradingPool721} from "../../interfaces/ITradingPool721.sol";
import {ITradingPoolRegistry} from "../../interfaces/ITradingPoolRegistry.sol";
import {ISwapPoolFactory} from "../../interfaces/ISwapPoolFactory.sol";
import {ISwapPool} from "../../interfaces/ISwapPool.sol";
import {ISwapRouter} from "../../interfaces/ISwapRouter.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title SwapRouter Contract
/// @author leNFT
/// @notice This contract is responsible for swapping between assets in different pools
/// @dev Coordenates a buy and sell between two different trading pools
contract SwapRouter is ISwapRouter {
    IAddressProvider private immutable _addressProvider;

    using SafeERC20 for IERC20;

    /// @notice Constructor of the contract
    /// @param addressProvider The address of the addressProvider contract
    constructor(IAddressProvider addressProvider) {
        _addressProvider = addressProvider;
    }

    /// @notice Swaps tokens within the same collection
    /// @param tradingPool The address of the trading pool
    /// @param swapPool The address of the swap pool
    /// @param buyNftIds The IDs of the NFTs that the user will buy
    /// @param maximumBuyPrice The maximum price that the user is willing to pay for the NFTs
    /// @param sellNftIds The IDs of the NFTs that the user will sell
    /// @param sellLps The amounts of liquidity provider tokens to be sold
    /// @param minimumSellPrice The minimum price that the user is willing to accept for the NFTs
    /// @return change The amount of tokens returned to the user
    function swapWithin(
        address tradingPool,
        address swapPool,
        uint256[] calldata buyNftIds,
        uint256 maximumBuyPrice,
        uint256[] calldata sellNftIds,
        uint256[] calldata sellLps,
        uint256 minimumSellPrice,
        uint256[] calldata swapSendNftIds,
        uint256[] calldata swapReceiveNftIds,
        uint256 swapFees
    ) external returns (uint256 change) {
        // Pools need to be registered in the factory
        require(
            ITradingPoolRegistry(_addressProvider.getTradingPoolRegistry())
                .isTradingPool(tradingPool),
            "SR:SW:INVALID_TRADING_POOL"
        );

        // If we are also using the swap pool
        address tradingPoolToken = ITradingPool(tradingPool).getToken();
        if (swapPool != address(0)) {
            require(
                ISwapPoolFactory(_addressProvider.getSwapPoolFactory())
                    .isSwapPool(swapPool),
                "SR:SW:INVALID_SWAP_POOL"
            );

            // Pools need to have the same underlying token
            require(
                ISwapPool(swapPool).getFeeToken() == tradingPoolToken,
                "SR:SW:DIFFERENT_TOKENS"
            );
        }

        uint256 sellPrice = ITradingPool(tradingPool).sell(
            msg.sender,
            sellNftIds,
            sellLps,
            minimumSellPrice
        );

        // If the buy price is greater than the sell price + swap fees, transfer the remaining amount to the swap contract + the swap fees
        uint256 priceDiff;
        if (maximumBuyPrice > minimumSellPrice + swapFees) {
            priceDiff = maximumBuyPrice - minimumSellPrice + swapFees;
            IERC20(tradingPoolToken).safeTransferFrom(
                msg.sender,
                address(this),
                priceDiff
            );
        }

        // Buy the NFTs
        uint256 buyPrice = ITradingPool(tradingPool).buy(
            msg.sender,
            buyNftIds,
            maximumBuyPrice
        );

        // If we are also using the swap pool, swap the NFTs
        uint256 swapPrice;
        if (swapPool != address(0)) {
            swapPrice = ISwapPool(swapPool).swap(
                msg.sender,
                swapSendNftIds,
                swapReceiveNftIds
            );
        }

        // If the price difference + sell price + swapPrice is greater than the buy price, return the difference to the user
        if (sellPrice + priceDiff + swapPrice > buyPrice) {
            change = sellPrice + priceDiff + swapPrice - buyPrice;
            IERC20(tradingPool).safeTransfer(msg.sender, change);
        }
    }

    /// @notice Swaps tokens between two different trading pools
    /// @dev The pools must have the same underlying token
    /// @param buyPool The address of the trading pool from which the user will buy NFTs
    /// @param sellPool The address of the trading pool from which the user will sell NFTs
    /// @param buyNftIds The IDs of the NFTs that the user will buy
    /// @param maximumBuyPrice The maximum price that the user is willing to pay for the NFTs
    /// @param sellNftIds The IDs of the NFTs that the user will sell
    /// @param sellLps The amounts of liquidity provider tokens to be sold
    /// @param minimumSellPrice The minimum price that the user is willing to accept for the NFTs
    /// @return change The amount of tokens returned to the user
    function swap(
        address buyPool,
        address sellPool,
        uint256[] calldata buyNftIds,
        uint256 maximumBuyPrice,
        uint256[] calldata sellNftIds,
        uint256[] calldata sellLps,
        uint256 minimumSellPrice
    ) external returns (uint256 change) {
        // Pools need to be different
        require(buyPool != sellPool, "SR:S:SAME_POOL");
        // Pools need to be registered in the factory
        require(
            ITradingPoolRegistry(_addressProvider.getTradingPoolRegistry())
                .isTradingPool(buyPool),
            "SR:S:INVALID_BUY_POOL"
        );

        require(
            ITradingPoolRegistry(_addressProvider.getTradingPoolRegistry())
                .isTradingPool(sellPool),
            "SR:S:INVALID_SELL_POOL"
        );
        // Pools need to have the same underlying token
        address sellPoolToken = ITradingPool(sellPool).getToken();
        if (buyPool != sellPool) {
            require(
                ITradingPoolRegistry(_addressProvider.getTradingPoolRegistry())
                    .isTradingPool(sellPool),
                "SR:S:INVALID_SELL_POOL"
            );
            require(
                tradingPoolFactory.isTradingPool(buyPool),
                "SR:S:INVALID_BUY_POOL"
            );
            sellPoolToken = ITradingPool(sellPool).getToken();
            if (buyPool != sellPool) {
                require(
                    tradingPoolFactory.isTradingPool(sellPool),
                    "SR:S:INVALID_SELL_POOL"
                );
                // Pools need to have the same underlying token
                require(
                    ITradingPool(buyPool).getToken() == sellPoolToken,
                    "SR:S:DIFFERENT_TOKENS"
                );
            }
        }

        uint256 sellPrice = ITradingPool721(sellPool).sell(
            msg.sender,
            sellNftIds,
            sellLps,
            minimumSellPrice
        );

        // If the buy price is greater than the sell price, transfer the remaining amount to the swap contract
        uint256 priceDiff;
        if (maximumBuyPrice > minimumSellPrice) {
            priceDiff = maximumBuyPrice - minimumSellPrice;
            IERC20(sellPoolToken).safeTransferFrom(
                msg.sender,
                address(this),
                priceDiff
            );
        }

        // Buy the NFTs
        uint256 buyPrice = ITradingPool721(buyPool).buy(
            msg.sender,
            buyNftIds,
            maximumBuyPrice
        );

        // If the price difference + sell price is greater than the buy price, return the difference to the user
        if (sellPrice + priceDiff > buyPrice) {
            change = sellPrice + priceDiff - buyPrice;
            IERC20(sellPoolToken).safeTransfer(msg.sender, change);
        }
    }

    /// @notice Approves a trading pool to spend an unlimited amount of tokens on behalf of this contract
    /// @param token The address of the token to approve
    /// @param tradingPool The address of the trading pool to approve
    function approveTradingPool(address token, address tradingPool) external {
        require(
            msg.sender == _addressProvider.getTradingPoolRegistry(),
            "SR:ATP:NOT_REGISTRY"
        );
        IERC20(token).safeApprove(tradingPool, type(uint256).max);
    }
}
