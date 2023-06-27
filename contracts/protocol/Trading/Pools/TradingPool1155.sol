// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ITradingPool1155} from "../../../interfaces/ITradingPool1155.sol";
import {IAddressProvider} from "../../../interfaces/IAddressProvider.sol";
import {IPricingCurve} from "../../../interfaces/IPricingCurve.sol";
import {IFeeDistributor} from "../../../interfaces/IFeeDistributor.sol";
import {ITradingPoolRegistry} from "../../../interfaces/ITradingPoolRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {DataTypes} from "../../../libraries/types/DataTypes.sol";
import {PercentageMath} from "../../../libraries/utils/PercentageMath.sol";
import {IPositionMetadata} from "../../../interfaces/IPositionMetadata.sol";
import "hardhat/console.sol";

/// @title Trading Pool Contract
/// @author leNFT
/// @notice A contract that enables the creation of liquidity pools and the trading of NFTs and ERC20 tokens.
/// @dev This contract manages liquidity pairs, each consisting of a set of NFTs and an ERC20 token, as well as the trading of these pairs.
contract TradingPool1155 is
    ERC165,
    ERC721Enumerable,
    ERC1155Holder,
    ITradingPool1155,
    Ownable,
    ReentrancyGuard
{
    uint public constant MAX_FEE = 8000; // 80%

    IAddressProvider private immutable _addressProvider;
    bool private _paused;
    address private immutable _token;
    address private immutable _nft;
    mapping(uint256 => DataTypes.LiquidityPair1155) private _liquidityPairs;
    uint256 private _lpCount;

    using SafeERC20 for IERC20;

    modifier poolNotPaused() {
        _requirePoolNotPaused();
        _;
    }

    modifier lpExists(uint256 lpId) {
        _requireLpExists(lpId);
        _;
    }

    /// @notice Trading Pool constructor.
    /// @dev The constructor should only be called by the Trading Pool Factory contract.
    /// @param addressProvider The address provider contract.
    /// @param owner The owner of the Trading Pool contract.
    /// @param token The ERC20 token used in the trading pool.
    /// @param nft The address of the ERC1155 contract.
    /// @param name The name of the ERC721 token.
    /// @param symbol The symbol of the ERC721 token.
    constructor(
        IAddressProvider addressProvider,
        address owner,
        address token,
        address nft,
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _addressProvider = addressProvider;
        _token = token;
        _nft = nft;
        _transferOwnership(owner);
    }

    /// @notice Returns the token URI for a specific liquidity pair
    /// @param tokenId The ID of the liquidity pair.
    /// @return The token URI.
    function tokenURI(
        uint256 tokenId
    ) public view override lpExists(tokenId) returns (string memory) {
        return
            IPositionMetadata(_addressProvider.getLiquidityPair1155Metadata())
                .tokenURI(address(this), tokenId);
    }

    /// @notice Gets the address of the ERC1155 traded in the pool.
    /// @return The address of the ERC1155 token.
    function getNFT() external view override returns (address) {
        return _nft;
    }

    function getNFTType() external pure returns (DataTypes.TokenStandard) {
        return DataTypes.TokenStandard.ERC1155;
    }

    /// @notice Gets the address of the ERC20 token traded in the pool.
    /// @return The address of the ERC20 token.
    function getToken() external view override returns (address) {
        return _token;
    }

    /// @notice Gets the liquidity pair with the specified ID.
    /// @param lpId The ID of the liquidity pair.
    /// @return The liquidity pair.
    function getLP(
        uint256 lpId
    )
        external
        view
        override
        lpExists(lpId)
        returns (DataTypes.LiquidityPair1155 memory)
    {
        return _liquidityPairs[lpId];
    }

    /// @notice Gets the number of liquidity pairs ever created in the trading pool.
    /// @return The number of liquidity pairs.
    function getLpCount() external view override returns (uint256) {
        return _lpCount;
    }

    /// @notice Adds liquidity to the trading pool.
    /// @dev At least one of nftIds or tokenAmount must be greater than zero.
    /// @dev The caller must approve the Trading Pool contract to transfer the NFTs and ERC20 tokens.
    /// @param receiver The recipient of the liquidity pool tokens.
    /// @param nftId The IDs of the NFTs being deposited.
    /// @param nftAmount The amounts of the NFTs being deposited.
    /// @param tokenAmount The amount of the ERC20 token being deposited.
    /// @param spotPrice The spot price of the liquidity pair being created.
    /// @param curve The pricing curve for the liquidity pair being created.
    /// @param delta The delta for the liquidity pair being created.
    /// @param fee The fee for the liquidity pair being created.
    function addLiquidity(
        address receiver,
        DataTypes.LPType lpType,
        uint256 nftId,
        uint256 nftAmount,
        uint256 tokenAmount,
        uint256 spotPrice,
        address curve,
        uint256 delta,
        uint256 fee
    ) external override nonReentrant poolNotPaused {
        ITradingPoolRegistry tradingPoolRegistry = ITradingPoolRegistry(
            _addressProvider.getTradingPoolRegistry()
        );

        // Check if pool will exceed maximum permitted amount
        require(
            tokenAmount + IERC20(_token).balanceOf(address(this)) <
                tradingPoolRegistry.getTVLSafeguard(),
            "TP:AL:SAFEGUARD_EXCEEDED"
        );

        // Different types of liquidity pairs have different requirements
        // Trade: Can contain NFTs and/or tokens
        // TradeUp: Can contain NFTs and/or tokens, delta must be > 0
        // TradeDown: Can contain NFTs and/or tokens, delta must be > 0
        // Buy: Can only contain tokens
        // Sell: Can only contain NFTs
        if (
            lpType == DataTypes.LPType.Trade ||
            lpType == DataTypes.LPType.TradeUp ||
            lpType == DataTypes.LPType.TradeDown
        ) {
            require(tokenAmount > 0 || nftAmount > 0, "TP:AL:DEPOSIT_REQUIRED");
        } else if (lpType == DataTypes.LPType.Buy) {
            require(tokenAmount > 0 && nftAmount == 0, "TP:AL:TOKENS_ONLY");
        } else if (lpType == DataTypes.LPType.Sell) {
            require(nftAmount > 0 && tokenAmount == 0, "TP:AL:NFTS_ONLY");
        }

        // Directional LPs must have a positive delta in order for the price to move or else
        // they degenerate into a Trade LPs with delta = 0
        if (
            lpType == DataTypes.LPType.TradeUp ||
            lpType == DataTypes.LPType.TradeDown
        ) {
            require(delta > 0, "TP:AL:DELTA_0");
        }

        if (lpType == DataTypes.LPType.Buy || lpType == DataTypes.LPType.Sell) {
            // Validate fee
            require(fee == 0, "TP:AL:INVALID_LIMIT_FEE");
        } else {
            // require that the fee is higher than 0 and less than the maximum fee
            require(fee > 0 && fee <= MAX_FEE, "TP:AL:INVALID_FEE");
        }

        // Require that the curve conforms to the curve interface
        require(tradingPoolRegistry.isPriceCurve(curve), "TP:AL:INVALID_CURVE");

        // Validate LP params for chosen curve
        IPricingCurve(curve).validateLpParameters(spotPrice, delta, fee);

        // Add user nfts to the pool
        IERC1155(_nft).safeTransferFrom(
            msg.sender,
            address(this),
            nftId,
            nftAmount,
            ""
        );

        // Send user token to the pool
        if (tokenAmount > 0) {
            IERC20(_token).safeTransferFrom(
                msg.sender,
                address(this),
                tokenAmount
            );
        }

        // Save the user deposit info
        _liquidityPairs[_lpCount] = DataTypes.LiquidityPair1155({
            lpType: lpType,
            nftId: nftId,
            nftAmount: nftAmount,
            tokenAmount: tokenAmount,
            spotPrice: spotPrice,
            curve: curve,
            delta: delta,
            fee: fee
        });

        // Mint liquidity position NFT
        ERC721._safeMint(receiver, _lpCount);

        emit AddLiquidity(
            receiver,
            _lpCount,
            lpType,
            nftId,
            nftAmount,
            tokenAmount,
            spotPrice,
            curve,
            delta,
            fee
        );

        _lpCount++;
    }

    /// @notice Removes liquidity pair, sending back deposited tokens and transferring the NFTs to the user
    /// @param lpId The ID of the LP token to remove
    function removeLiquidity(uint256 lpId) public override nonReentrant {
        _removeLiquidity(lpId);
    }

    /// @notice Removes liquidity pairs in batches by calling the removeLiquidity function for each LP token ID in the lpIds array
    /// @param lpIds The IDs of the LP tokens to remove liquidity from
    function removeLiquidityBatch(uint256[] calldata lpIds) external override {
        for (uint i = 0; i < lpIds.length; i++) {
            _removeLiquidity(lpIds[i]);
        }
    }

    /// @notice Private function that removes a liquidity pair, sending back deposited tokens and transferring the NFTs to the user
    /// @param lpId The ID of the LP token to remove
    function _removeLiquidity(uint256 lpId) private {
        //Require the caller owns LP
        require(msg.sender == ERC721.ownerOf(lpId), "TP:RL:NOT_OWNER");

        // Send pool nfts to the user
        IERC1155(_nft).safeTransferFrom(
            address(this),
            msg.sender,
            _liquidityPairs[lpId].nftId,
            _liquidityPairs[lpId].nftAmount,
            ""
        );

        // Send pool token back to user
        IERC20(_token).safeTransfer(
            msg.sender,
            _liquidityPairs[lpId].tokenAmount
        );

        // delete the user deposit info
        delete _liquidityPairs[lpId];

        // Burn liquidity position NFT
        ERC721._burn(lpId);

        emit RemoveLiquidity(msg.sender, lpId);
    }

    /// @notice Buys NFTs in exchange for pool tokens
    /// @param onBehalfOf The address to deposit the NFTs to
    /// @param liquidityPairs The IDs of the liquidity pairs to buy from
    /// @param nftAmounts The amounts of each NFT to buy
    /// @param maximumPrice The maximum price the user is willing to pay for the NFTs
    /// @return finalPrice The final price paid for the NFTs
    function buy(
        address onBehalfOf,
        uint256[] calldata liquidityPairs,
        uint256[] calldata nftAmounts,
        uint256 maximumPrice
    )
        external
        override
        nonReentrant
        poolNotPaused
        returns (uint256 finalPrice)
    {
        require(
            liquidityPairs.length == nftAmounts.length,
            "TP:B:LENGTH_MISMATCH"
        );

        uint256[] memory nftIds = new uint256[](liquidityPairs.length);
        uint256 totalPrice;
        uint256 fee;
        uint256 totalProtocolFee;
        DataTypes.LiquidityPair1155 memory lp;
        uint256 protocolFeePercentage = ITradingPoolRegistry(
            _addressProvider.getTradingPoolRegistry()
        ).getProtocolFeePercentage();
        for (uint i = 0; i < liquidityPairs.length; i++) {
            lp = _liquidityPairs[liquidityPairs[i]];

            // Can't buy from buy LP
            require(lp.lpType != DataTypes.LPType.Buy, "TP:B:IS_BUY_LP");

            // Check if the LP owns enough NFTs
            require(lp.nftAmount >= nftAmounts[i], "TP:B:AMOUNT_EXCEEDS_LP");

            // Update liquidity pair price
            if (lp.lpType != DataTypes.LPType.TradeDown) {
                _liquidityPairs[liquidityPairs[i]].spotPrice = IPricingCurve(
                    lp.curve
                ).priceAfterMultipleBuys(nftAmounts[i], lp.spotPrice, lp.delta);
            }

            console.log(
                "priceAfterMultipleBuys",
                IPricingCurve(lp.curve).priceAfterMultipleBuys(
                    nftAmounts[i],
                    lp.spotPrice,
                    lp.delta
                )
            );

            totalPrice = IPricingCurve(lp.curve).buyPriceSum(
                nftAmounts[i],
                lp.spotPrice,
                lp.delta
            );

            console.log("totalPrice: %s", totalPrice);

            fee = PercentageMath.percentMul(totalPrice, lp.fee);

            _liquidityPairs[liquidityPairs[i]].tokenAmount += (totalPrice +
                fee -
                PercentageMath.percentMul(fee, protocolFeePercentage));

            _liquidityPairs[liquidityPairs[i]].nftAmount -= nftAmounts[i];

            // Increase total price and fee sum
            finalPrice += (totalPrice + fee);
            totalProtocolFee += PercentageMath.percentMul(
                fee,
                protocolFeePercentage
            );

            // Add NFT id to list
            nftIds[i] = lp.nftId;
        }

        // Send NFTs to user
        IERC1155(_nft).safeBatchTransferFrom(
            address(this),
            onBehalfOf,
            nftIds,
            nftAmounts,
            ""
        );

        require(finalPrice <= maximumPrice, "TP:B:MAX_PRICE_EXCEEDED");

        // Get tokens from user
        IERC20(_token).safeTransferFrom(msg.sender, address(this), finalPrice);

        // Send protocol fee to protocol fee distributor
        IERC20(_token).safeTransfer(
            _addressProvider.getFeeDistributor(),
            totalProtocolFee
        );
        IFeeDistributor(_addressProvider.getFeeDistributor()).checkpoint(
            _token
        );

        emit Buy(onBehalfOf, liquidityPairs, nftAmounts, finalPrice);
    }

    /// @notice Allows an address to sell one or more NFTs in exchange for a token amount.
    /// @param onBehalfOf The address that owns the NFT(s) and will receive the token amount.
    /// @param liquidityPairs An array of the IDs of the liquidity pairs to use for the sale.
    /// @param minimumPrice The minimum acceptable price in tokens for the sale.
    /// @return finalPrice The final price in tokens received from the sale.
    function sell(
        address onBehalfOf,
        uint256[] calldata liquidityPairs,
        uint256[] calldata nftAmounts,
        uint256 minimumPrice
    )
        external
        override
        nonReentrant
        poolNotPaused
        returns (uint256 finalPrice)
    {
        require(liquidityPairs.length > 0, "TP:S:LPs_0");
        require(
            liquidityPairs.length == nftAmounts.length,
            "TP:S:LP_AMOUNTS_MISMATCH"
        );

        // Only the swap router can call this function on behalf of another address
        if (onBehalfOf != msg.sender) {
            require(
                msg.sender == _addressProvider.getSwapRouter(),
                "TP:S:NOT_SWAP_ROUTER"
            );
        }

        uint256[] memory nftIds = new uint256[](liquidityPairs.length);
        uint256 totalPrice;
        uint256 totalProtocolFee;
        uint256 fee;
        DataTypes.LiquidityPair1155 memory lp;
        uint256 protocolFeePercentage = ITradingPoolRegistry(
            _addressProvider.getTradingPoolRegistry()
        ).getProtocolFeePercentage();
        // Transfer the NFTs to the pool
        for (uint i = 0; i < liquidityPairs.length; i++) {
            // Check if the LP exists
            require(_exists(liquidityPairs[i]), "TP:S:LP_NOT_FOUND");

            // Get the LP details
            lp = _liquidityPairs[liquidityPairs[i]];

            // Can't sell to sell LP
            require(lp.lpType != DataTypes.LPType.Sell, "TP:S:IS_SELL_LP");

            totalPrice = IPricingCurve(lp.curve).sellPriceSum(
                nftAmounts[i],
                lp.spotPrice,
                lp.delta
            );

            // Calculate the fee and protocol fee for the sale
            fee = PercentageMath.percentMul(totalPrice, lp.fee);

            require(
                lp.tokenAmount >=
                    totalPrice -
                        fee +
                        PercentageMath.percentMul(fee, protocolFeePercentage),
                "TP:S:INSUFFICIENT_TOKENS_IN_LP"
            );

            // Update token amount in liquidity pair
            _liquidityPairs[liquidityPairs[i]].tokenAmount -= (lp.spotPrice -
                fee +
                PercentageMath.percentMul(fee, protocolFeePercentage));

            _liquidityPairs[liquidityPairs[i]].nftAmount += nftAmounts[i];

            // Update total price quote and fee sum
            finalPrice += (totalPrice - fee);
            totalProtocolFee += PercentageMath.percentMul(
                fee,
                protocolFeePercentage
            );

            // Update liquidity pair price
            if (lp.lpType != DataTypes.LPType.TradeUp) {
                _liquidityPairs[liquidityPairs[i]].spotPrice = IPricingCurve(
                    lp.curve
                ).priceAfterSell(lp.spotPrice, lp.delta, lp.fee);
            }

            // Add LP nft id to array
            nftIds[i] = lp.nftId;
        }

        // Send NFTs to pool
        IERC1155(_nft).safeBatchTransferFrom(
            msg.sender,
            address(this),
            nftIds,
            nftAmounts,
            ""
        );

        // Make sure the final price is greater than or equal to the minimum price set by the user
        require(finalPrice >= minimumPrice, "TP:S:MINIMUM_PRICE_NOT_REACHED");

        // Send tokens to user
        IERC20(_token).safeTransfer(msg.sender, finalPrice);

        // Send protocol fee to protocol fee distributor and call a checkpoint
        IERC20(_token).safeTransfer(
            _addressProvider.getFeeDistributor(),
            totalProtocolFee
        );
        IFeeDistributor(_addressProvider.getFeeDistributor()).checkpoint(
            _token
        );

        emit Sell(onBehalfOf, liquidityPairs, nftAmounts, finalPrice);
    }

    /// @notice Allows the owner of the contract to pause or unpause the contract.
    /// @param paused A boolean indicating whether to pause or unpause the contract.
    function setPause(bool paused) external onlyOwner {
        _paused = paused;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Enumerable) {
        ERC721Enumerable._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC165, ERC721Enumerable, ERC1155Receiver)
        returns (bool)
    {
        return
            type(ITradingPool1155).interfaceId == interfaceId ||
            ERC721Enumerable.supportsInterface(interfaceId) ||
            ERC1155Receiver.supportsInterface(interfaceId) ||
            ERC165.supportsInterface(interfaceId);
    }

    function _requirePoolNotPaused() internal view {
        require(!_paused, "TP:POOL_PAUSED");
    }

    function _requireLpExists(uint256 lpIndex) internal view {
        require(_exists(lpIndex), "TP:LP_NOT_FOUND");
    }
}
