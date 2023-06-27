//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Trustus} from "../../protocol/Trustus/Trustus.sol";

/// @title DataTypes library
/// @author leNFT
/// @notice Defines the data types used in the protocol
/// @dev Library with the data types used in the protocol
library DataTypes {
    /// @notice Struct to store the price data of an array of assets from the same collection
    /// @param collection The address of the collection
    /// @param tokenIds The tokenIds of the assets
    /// @param amount The price of the assets
    struct Assets721Price {
        address collection;
        uint256[] tokenIds;
        uint256 amount;
    }

    struct Assets1155Price {
        address collection;
        uint256[] tokenIds;
        uint256[] tokenAmounts;
        uint256 amount;
    }

    /// @notice Struct to store the risk parameters for a collection
    /// @param maxLTV The maximum loan to value ratio
    /// @param liquidationThreshold The threshold at which the loan can be liquidated
    struct CollectionRiskParameters {
        uint16 maxLTV;
        uint16 liquidationThreshold;
    }

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
        uint128 tokenAmount;
        uint128 spotPrice;
        uint128 delta;
        address curve;
        uint16 fee;
        LPType lpType;
    }

    struct LiquidityPair1155 {
        LPType lpType;
        uint256 nftId;
        uint256 nftAmount;
        uint256 tokenAmount;
        uint256 spotPrice;
        address curve;
        uint256 delta;
        uint256 fee;
    }

    struct SwapLiquidity {
        uint256[] nftIds;
        uint256 fee;
        uint256 balance;
    }

    /// @notice Struct serving as a pointer from an NFT to a liquidity pair
    /// @param liquidityPair The index of the liquidity pair
    /// @param index The index of the NFT in the liquidity pair
    struct NftToLp {
        uint128 liquidityPair;
        uint128 index;
    }

    /// @notice Struct serving as a pointer from an NFT to a swap liquidity object
    /// @param swapLiquidity The index of the swap Liquidity
    /// @param index The index of the NFT in the swap Liquidity
    struct NftToSl {
        uint128 swapLiquidity;
        uint128 index;
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

    /// @notice Enum of all the states a loan can be in
    /// @dev State change flow: None -> Created -> Active -> Repaid -> Auction -> Liquidated
    /// @dev None (Default Value): We need a default that is not 'Created' - this is the zero value
    /// @dev Created: The loan data is stored; but not initiated yet.
    /// @dev Active: The loan has been initialized; funds have been delivered to the borrower and the collateral is held.
    /// @dev Repaid: The loan has been repaid; and the collateral has been returned to the borrower.
    /// @dev Auctioned: The loan's collateral has been auctioned off and its in the process of being liquidated.
    /// @dev Liquidated: The loan's collateral was claimed by the liquidator.
    enum LoanState {
        None,
        Created,
        Active,
        Repaid,
        Auctioned,
        Liquidated
    }

    enum TokenStandard {
        ERC721,
        ERC1155
    }

    struct PeerLendingLiquidity {
        address owner;
        uint256 loanCount;
        uint256 tokenAmount;
        uint256 maxBorrowableAmount;
        uint256 maxDuration;
        address interestRateCurve;
        uint256 delta;
        uint256 resetPeriod;
    }

    struct PeerLoanData {
        address owner;
        uint256 amount;
        uint256[] tokenIds;
        uint256[] tokenAmounts; // Only used for ERC1155 loans
        address asset;
        uint256 borrowRate;
        LoanState state;
    }

    /// @notice Stores the data for a loan
    /// @param owner The owner of the loan
    /// @param amount The amount borrowed
    /// @param collateralType The type of collateral
    /// @param tokenIds The tokenIds of the NFT collaterals
    /// @param tokenAmounts The token amounts of the NFT collaterals (only used for ERC1155 loans)
    /// @param asset The address of the NFT asset
    /// @param borrowRate The interest rate at which the loan was written
    /// @param initTimestamp The timestamp for the initial creation of the loan
    /// @param debtTimestamp The timestamp for debt computation
    /// @param pool The address of the lending pool associated with the loan
    /// @param genesisNFTId The genesis NFT id for the boost (0 if not used)
    /// @param state The current state of the loan
    struct PoolLoanData {
        address owner;
        uint256 amount;
        uint256[] tokenIds;
        uint256[] tokenAmounts; // Only used for ERC1155 loans
        address asset;
        uint16 borrowRate;
        uint40 initTimestamp;
        uint40 debtTimestamp;
        address pool;
        uint16 genesisNFTId;
        LoanState state;
        TokenStandard collateralType;
    }

    /// @notice Stores the data for a loan auction
    /// @param auctioneer The address of the auctioneer (user who first auctioned the loan)
    /// @param liquidator The address of the liquidator (user with the highest bid)
    /// @param auctionStartTimestamp The timestamp for the start of the auction
    /// @param auctionMaxBid The maximum bid for the auction
    struct LoanLiquidationData {
        address auctioneer;
        address liquidator;
        uint40 auctionStartTimestamp;
        uint256 auctionMaxBid;
    }

    /// @notice Struct to store mint details for each Genesis NFT
    /// @param timestamp The timestamp of the mint
    /// @param locktime The locktime of the mint
    /// @param lpAmount The amount of LP tokens minted
    struct MintDetails {
        uint40 timestamp;
        uint40 locktime;
        uint128 lpAmount;
    }

    struct PeerBorrowParams {
        address caller;
        address onBehalfOf;
        address asset;
        uint256 amount;
        TokenStandard collateralType;
        address tokenAddress;
        uint256[] tokenIds;
        uint256[] tokenAmounts;
        uint256 liquidityId;
    }

    /// @notice Struct to store the parameters for a borrow call
    /// @param caller The caller of the borrow function
    /// @param onBehalfOf The address of the user on whose behalf the caller is borrowing
    /// @param asset The address of the asset being borrowed
    /// @param amount The amount of the asset being borrowed
    /// @param tokenAddress The address of the NFT asset
    /// @param tokenIds The tokenIds of the NFT collaterals
    /// @param tokenAmounts The token amounts of the NFT collaterals (only used for ERC1155 loans)
    /// @param genesisNFTId The genesis NFT id for the boost (0 if not used)
    /// @param request The request ID for the borrow
    /// @param packet The Trustus packet for the borrow
    struct PoolBorrowParams {
        address caller;
        address onBehalfOf;
        address asset;
        uint256 amount;
        TokenStandard collateralType;
        address tokenAddress;
        uint256[] tokenIds;
        uint256[] tokenAmounts;
        uint256 genesisNFTId;
        bytes32 request;
        Trustus.TrustusPacket packet;
    }

    /// @notice Struct to store the parameters for a repay call
    /// @param caller The caller of the repay function
    /// @param loanId The ID of the loan being repaid
    /// @param amount The amount of debt being repaid
    struct RepayParams {
        address caller;
        uint256 loanId;
        uint256 amount;
    }

    /// @notice Struct to store the parameters for a create auction (liquidate) call
    /// @param caller The caller of the create auction function
    /// @param onBehalfOf The address of the user on whose behalf the caller is liquidating
    /// @param loanId The ID of the loan being liquidated
    /// @param bid The bid for the auction
    /// @param request The request ID for the liquidation
    /// @param packet The Trustus packet for the liquidation
    struct CreateAuctionParams {
        address caller;
        address onBehalfOf;
        uint256 loanId;
        uint256 bid;
        bytes32 request;
        Trustus.TrustusPacket packet;
    }

    /// @notice Struct to store the parameters for an auction bid call
    /// @param caller The caller of the auction bid function
    /// @param onBehalfOf The address of the user on whose behalf the caller is bidding
    /// @param loanId The ID of the loan being liquidated
    /// @param bid The bid for the auction
    struct BidAuctionParams {
        address caller;
        address onBehalfOf;
        uint256 loanId;
        uint256 bid;
    }

    /// @notice Struct to store the parameters for a claim liquidation call
    /// @param loanId The ID of the loan whose liquidation is being claimed
    struct ClaimLiquidationParams {
        uint256 loanId;
    }

    /// @notice Struct to store the parameters a user's VestingParams
    /// @param timestamp The timestamp of the vesting start
    /// @param period The vesting period
    /// @param cliff The vesting cliff
    /// @param amount The amount of tokens to vest
    struct VestingParams {
        uint256 timestamp;
        uint256 period;
        uint256 cliff;
        uint256 amount;
    }

    /// @notice Struct to store the parameters for the Genesis NFT balancer pool
    /// @param poolId The ID of the balancer pool
    /// @param pool The address of the balancer pool
    /// @param vault The address of the balancer vault
    /// @param queries The address of the balancer queries contract
    struct BalancerDetails {
        bytes32 poolId;
        address pool;
        address vault;
        address queries;
    }
}
