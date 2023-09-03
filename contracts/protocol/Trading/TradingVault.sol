// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {LiquidityPoolToken} from "./LiquidityPoolToken.sol";
import {DataTypes} from "../../libraries/types/DataTypes.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC165CheckerUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import {ITradingVault} from "../../interfaces/ITradingVault.sol";
import {LiquidityPoolToken} from "./LiquidityPoolToken.sol";

contract TradingVault is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ITradingVault
{
    IAddressProvider private immutable _addressProvider;
    // mapping of valid price curves
    mapping(address => bool) private _isPriceCurve;
    mapping(address => mapping(address => address)) private _lpPoolTokens;
    mapping(address => address) private _slPoolTokens;
    mapping(uint256 => address) private _liquidityIdPool;
    uint256 private _liquidityCount;
    mapping(uint256 => DataTypes.LiquidityPair721) private _liquidityPairs721;
    mapping(uint256 => DataTypes.LiquidityPair1155) private _liquidityPairs1155;
    mapping(uint256 => DataTypes.LiquidityType) _liquidityType;
    bool private _paused;
    uint256 private _protocolFeePercentage;

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ERC165CheckerUpgradeable for address;

    modifier notPaused() {
        _requireNotPaused();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IAddressProvider addressProvider) {
        _addressProvider = addressProvider;
        _disableInitializers();
    }

    function initialize(uint256 protocolFeePercentage) external initializer {
        __Ownable_init();
        __ERC1155_init("");
        _protocolFeePercentage = protocolFeePercentage;
    }

    function getPoolAddress(
        uint256 liquidityId
    ) external view returns (address) {
        return _liquidityIdPool[liquidityId];
    }

    function getLP721(
        uint256 liquidityId
    ) external view returns (DataTypes.LiquidityPair721 memory) {
        return _liquidityPairs721[lpId];
    }

    function getLP1155(
        uint256 liquidityId
    ) external view returns (DataTypes.LiquidityPair1155 memory) {
        return _liquidityPairs1155[liquidityId];
    }

    function getSL(
        uint256 liquidityId
    ) external view returns (DataTypes.SwapLiquidity memory) {
        return _swapLiquidity[liquidityId];
    }

    function isPriceCurve(
        address priceCurve
    ) external view override returns (bool) {
        return _isPriceCurve[priceCurve];
    }

    function setPriceCurve(address priceCurve, bool valid) external onlyOwner {
        // Make sure the price curve is valid
        require(
            priceCurve.supportsInterface(type(IPricingCurve).interfaceId),
            "TV:SPC:NOT_PC"
        );
        _isPriceCurve[priceCurve] = valid;
    }

    function addLiquidity721(
        address receiver,
        DataTypes.LPType lpType,
        address nft,
        uint256[] calldata nftIds,
        address token,
        uint256 tokenAmount,
        uint256 spotPrice,
        address curve,
        uint256 delta,
        uint256 fee
    ) external notPaused {
        _validateAddLiquidity(
            lpType,
            nft,
            nftIds.length,
            token,
            tokenAmount,
            spotPrice,
            curve,
            delta,
            fee
        );

        address liquidityToken = _initLiquidityToken(nft, token);

        // Add user nfts to the pool
        for (uint i = 0; i < nftIds.length; i++) {
            IERC721(_nft).safeTransferFrom(
                msg.sender,
                address(this),
                nftIds[i]
            );
        }

        // Send user token to the pool
        if (tokenAmount > 0) {
            // User is sending ETH
            if (token == address(0)) {
                (bool sent, ) = msg.sender.call{value: tokenAmount}("");
                require(sent, "TV:AL:ETH_TRANSFER_FAILED");
            } else {
                IERC20(token).safeTransferFrom(
                    msg.sender,
                    address(this),
                    tokenAmount
                );
            }
        }

        uint256 liquidityCount = _liquidityCount;

        // Save the user deposit info
        _liquidityPairs721[liquidityCount] = DataTypes.LiquidityPair721({
            lpType: lpType,
            nftIds: nftIds,
            token: token,
            nft: nft,
            tokenAmount: SafeCast.toUint128(tokenAmount),
            spotPrice: SafeCast.toUint128(spotPrice),
            curve: curve,
            delta: SafeCast.toUint128(delta),
            fee: SafeCast.toUint16(fee)
        });
        _liquidityType[liquidityCount] = DataTypes.LiquidityType.LP721;
        _liquidityIdToken[liquidityCount] = lpToken;

        // Mint liquidity position NFT
        ILiquidityPoolToken(liquidityToken).mint(receiver, liquidityCount);

        _liquidityCount++;

        emit AddLiquidity(receiver, lpType, liquidityToken, liquidityCount);
    }

    function addLiquidity1155(
        address receiver,
        DataTypes.LPType lpType,
        address nft,
        uint256 nftId,
        uint256 nftAmount,
        address token,
        uint256 tokenAmount,
        uint256 spotPrice,
        address curve,
        uint256 delta,
        uint256 fee
    ) external notPaused {
        _validateAddLiquidity(
            lpType,
            nft,
            nftAmount,
            token,
            tokenAmount,
            spotPrice,
            curve,
            delta,
            fee
        );

        address liquidityToken = _initLiquidityToken(nft, token);

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
            // User is sending ETH
            if (token == address(0)) {
                (bool sent, ) = msg.sender.call{value: tokenAmount}("");
                require(sent, "TV:AL:ETH_TRANSFER_FAILED");
            } else {
                IERC20(token).safeTransferFrom(
                    msg.sender,
                    address(this),
                    tokenAmount
                );
            }
        }

        uint256 liquidityCount = _liquidityCount;

        // Save the user deposit info
        _liquidityPairs1155[lpCount] = DataTypes.LiquidityPair1155({
            lpType: lpType,
            nftId: nftId,
            nft: nft,
            token: token,
            nftAmount: nftAmount,
            tokenAmount: tokenAmount,
            spotPrice: spotPrice,
            curve: curve,
            delta: delta,
            fee: fee
        });
        _liquidityType[lpCount] = DataTypes.LiquidityType.LP1155;

        // Mint liquidity position NFT
        ILiquidityPoolToken(_lpToken).mint(receiver, liquidityCount);
        _liquidityIdToken[lpCount] = lpToken;

        _liquidityCount++;

        emit AddLiquidity(receiver, lpType, _lpToken, liquidityCount);
    }

    /// @notice Removes liquidity pair, sending back deposited tokens and transferring the NFTs to the user
    /// @param lpId The ID of the LP token to remove
    function removeLiquidity(uint256 lpId) external override nonReentrant {
        _removeLiquidity(lpId);
    }

    /// @notice Removes liquidity pairs in batches by calling the removeLiquidity function for each LP token ID in the lpIds array
    /// @param lpIds The IDs of the LP tokens to remove liquidity from
    function removeLiquidityBatch(
        uint256[] calldata lpIds
    ) external override nonReentrant {
        for (uint i = 0; i < lpIds.length; i++) {
            _removeLiquidity(lpIds[i]);
        }
    }

    /// @notice Private function that removes a liquidity pair, sending back deposited tokens and transferring the NFTs to the user
    /// @param liquidityId The ID of the LP token to remove
    function _removeLiquidity(uint256 liquidityId) private {
        address liquidityToken = _liquidityIdToken[lpId];
        //Require the caller owns LP
        require(
            msg.sender == IERC721(liquidityToken).ownerOf(lpId),
            "TV:RL:NOT_OWNER"
        );

        // Send pool nfts to the user
        address token;
        uint256 tokenAmount;
        if (_liquidityType[lpId] == DataTypes.LiquidityType.LP721) {
            for (uint i = 0; i < _liquidityPairs721[lpId].nftIds.length; i++) {
                IERC721(_nft).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _liquidityPairs721[lpId].nftIds[i]
                );
            }

            token = _liquidityPairs721[lpId].token;
            tokenAmount = _liquidityPairs721[lpId].tokenAmount;
            // delete the user deposit info
            delete _liquidityPairs721[lpId];
        } else if (_liquidityType[lpId] == DataTypes.LiquidityType.LP1155) {
            IERC1155(_nft).safeTransferFrom(
                address(this),
                msg.sender,
                _liquidityPairs1155[lpId].nftId,
                _liquidityPairs1155[lpId].nftAmount,
                ""
            );
            token = _liquidityPairs1155[lpId].token;
            tokenAmount = _liquidityPairs1155[lpId].tokenAmount;

            // delete the user deposit info
            delete _liquidityPairs1155[lpId];
        }

        // Send ERC20 tokens back to the user
        if (tokenAmount > 0) {
            // User is withdrawing ETH
            if (token == address(0)) {
                (bool sent, ) = msg.sender.call{value: tokenAmount}("");
                require(sent, "TV:RL:ETH_TRANSFER_FAILED");
            } else {
                IERC20(token).safeTransfer(msg.sender, tokenAmount);
            }
        }

        // Burn liquidity position NFT
        ILiquidityPoolToken(liquidityToken).burn(lpId);

        emit RemoveLiquidity(msg.sender, lpId);
    }

    function buy(
        address onBehalfOf,
        uint256[] lpLiquidityIds,
        uint256[] lp721Indexes,
        uint256[] lp1155Amounts,
        address token,
        uint256 maximumPrice
    ) external payable returns (uint256 finalPrice) {
        require(lpLiquidityIds.length > 0, "TV:B:EMPTY_LPS");
        // Make sure the length of the liquidityIds array matches the sum of the buyParams arrays
        require(
            lp721Indexes.length + lp1155Amounts.length == lpLiquidityIds.length,
            "TV:B:MISMATCH_LP_LENGTH"
        );

        if (token == address(0)) {
            require(msg.value == maximumPrice, "TV:B:NOT_ENOUGH_ETH");
        }

        uint256[] tokenIds721;
        uint256 fee;
        uint256 totalProtocolFee;
        uint256 protocolFee;
        DataTypes.LiquidityType liquidityType;
        DataTypes.LiquidityPair721 memory lp721;
        DataTypes.LiquidityPair1155 memory lp1155;
        for (uint i = 0; i < lpLiquidityIds.length; i++) {
            liquidityType = _liquidityType(lpLiquidityIds[i]);
            if (liquidityType == DataTypes.LiquidityType.LP721) {
                lp721 = _liquidityPairs721[lpLiquidityIds[i]];

                _validateBuyLP(lp721.token, token, lp721.lpType);

                fee = PercentageMath.percentMul(lp721.spotPrice, lp721.fee);
                protocolFee = PercentageMath.percentMul(
                    fee,
                    _protocolFeePercentage
                );

                _liquidityPairs[lpIndex].tokenAmount += SafeCast.toUint128(
                    (lp721.spotPrice + fee - protocolFee)
                );

                // Increase total price and fee sum
                finalPrice += (lp721.spotPrice + fee);
                totalProtocolFee += protocolFee;

                // Update liquidity pair price
                if (lp721.lpType != DataTypes.LPType.TradeDown) {
                    _liquidityPairs721[lpIndex].spotPrice = SafeCast.toUint128(
                        IPricingCurve(lp.curve).priceAfterBuy(
                            lp721.spotPrice,
                            lp721.delta,
                            lp721.fee
                        )
                    );
                }

                // Save the tokenId and remove it from the array
                tokenIds721.push(lp.nftIds[lp721Indexes[i]]);
                lp.nftIds[lp721Indexes[i]] = lp.nftIds[lp.nftIds.length - 1];
                lp.nftIds.pop();
            } else {
                lp1155 = _liquidityPairs1155[lpLiquidityIds[i]];

                _validateBuyLP(lp1155.token, token, lp1155.lpType);

                fee = PercentageMath.percentMul(lp1155.spotPrice, lp1155.fee);
                protocolFee = PercentageMath.percentMul(
                    fee,
                    _protocolFeePercentage
                );

                _liquidityPairs[lpIndex].tokenAmount += SafeCast.toUint128(
                    (lp1155.spotPrice + fee - protocolFee)
                );

                // Increase total price and fee sum
                finalPrice += (lp1155.spotPrice + fee);
                totalProtocolFee += protocolFee;

                // Update liquidity pair price
                if (lp1155.lpType != DataTypes.LPType.TradeDown) {
                    _liquidityPairs1155[lpIndex].spotPrice = SafeCast.toUint128(
                        IPricingCurve(lp.curve).priceAfterBuy(
                            lp1155.spotPrice,
                            lp1155.delta,
                            lp1155.fee
                        )
                    );
                }
            }
        }

        require(finalPrice <= maximumPrice, "TP:B:MAX_PRICE_EXCEEDED");

        // Get tokens from user or send ETH back
        if (token == address(0)) {
            (bool sent, ) = payable(this).call{
                value: maximumPrice - finalPrice
            }("");
            require(sent, "TV:B:ETH_TRANSFER_FAILED");
        } else {
            IERC20(token).safeTransferFrom(
                msg.sender,
                address(this),
                finalPrice
            );
        }

        // Send ERC721 tokens to user
        for (uint k = 0; k < tokenIds721.length; k++) {
            IERC721(lp.nft).safeTransferFrom(
                address(this),
                msg.sender,
                tokenIds721[k]
            );
        }

        //Send ERC1155 tokens to user
        for (uint k = 0; k < lp1155Amounts.length; k++) {
            IERC1155(lp.nft).safeTransferFrom(
                address(this),
                msg.sender,
                lp.nftId,
                lp1155Amounts[k],
                ""
            );
        }

        // Send protocol fee to protocol fee distributor
        _sendProtocolFee(token, totalProtocolFee);

        emit Buy(onBehalfOf, lpLiquidityIds, tokenIds721, lp1155Amounts);
    }

    function _validateBuyLP(
        address lpToken,
        address buyToken,
        DataTypes.LPType lpType
    ) internal view {
        // Make sure the token for the LP is the same
        require(lpToken == buyToken, "TP:B:TOKEN_MISMATCH");

        // Can't buy from buy LP
        require(lpType != DataTypes.LPType.Buy, "TP:B:IS_BUY_LP");
    }

    function sell(
        address onBehalfOf,
        uint256[] liquidityIds,
        uint256[] tokenIds721,
        uint256[] tokenAmounts1155,
        address token,
        uint256 minimumPrice
    ) external returns (uint256) {
        require(
            liquidityIds.length == tokenIds721.length + tokenAmounts1155,
            "TP:S:NFT_LP_MISMATCH"
        );

        uint256 totalProtocolFee;
        uint256 fee;
        DataTypes.LiquidityPair721 memory lp721;
        DataTypes.LiquidityPair1155 memory lp1155;
        uint256 lpIndex;

        // Transfer the NFTs to the pool
        for (uint i = 0; i < nftIds.length; i++) {
            liquidityType = _liquidityType(lpLiquidityIds[i]);
            if (liquidityType == DataTypes.LiquidityType.LP721) {
                lp721 = _liquidityPairs721[lpLiquidityIds[i]];

                // Calculate the fee and protocol fee for the sale
                fee = PercentageMath.percentMul(lp721.spotPrice, lp721.fee);

                _validateSellLP(
                    lp721.token,
                    token,
                    lp721.lpType,
                    lp721.spotPrice,
                    lp721.tokenAmount,
                    fee
                );

                // Add nft to liquidity pair nft list
                _liquidityPairs721[lpIndex].nftIds.push(tokenIds721[i]);

                // Update token amount in liquidity pair
                _liquidityPairs[lpIndex].tokenAmount -= SafeCast.toUint128(
                    (lp.spotPrice -
                        fee +
                        PercentageMath.percentMul(fee, protocolFeePercentage))
                );

                // Update total price quote and fee sum
                finalPrice += (lp.spotPrice - fee);
                totalProtocolFee += PercentageMath.percentMul(
                    fee,
                    protocolFeePercentage
                );

                // Update liquidity pair price
                if (lp.lpType != DataTypes.LPType.TradeUp) {
                    _liquidityPairs[lpIndex].spotPrice = SafeCast.toUint128(
                        IPricingCurve(lp.curve).priceAfterSell(
                            lp.spotPrice,
                            lp.delta,
                            lp.fee
                        )
                    );
                }
            } else {
                lp1155 = _liquidityPairs1155[lpLiquidityIds[i]];

                // Calculate the fee and protocol fee for the sale
                fee = PercentageMath.percentMul(lp1155.spotPrice, lp1155.fee);

                _validateSellLP(
                    lp1155.token,
                    token,
                    lp1155.lpType,
                    lp1155.spotPrice,
                    lp1155.tokenAmount,
                    fee
                );

                // Add token amount to liquidity pair token amount
                _liquidityPairs1155[lpIndex].tokenAmount += tokenAmounts1155[i];

                // Update token amount in liquidity pair
                _liquidityPairs[lpIndex].tokenAmount -= SafeCast.toUint128(
                    (lp.spotPrice -
                        fee +
                        PercentageMath.percentMul(fee, protocolFeePercentage))
                );

                // Update total price quote and fee sum
                finalPrice += (lp.spotPrice - fee);
                totalProtocolFee += PercentageMath.percentMul(
                    fee,
                    protocolFeePercentage
                );

                // Update liquidity pair price
                if (lp.lpType != DataTypes.LPType.TradeUp) {
                    _liquidityPairs[lpIndex].spotPrice = SafeCast.toUint128(
                        IPricingCurve(lp.curve).priceAfterSell(
                            lp.spotPrice,
                            lp.delta,
                            lp.fee
                        )
                    );
                }
            }
        }

        // Make sure the final price is greater than or equal to the minimum price set by the user
        require(finalPrice >= minimumPrice, "TP:S:MINIMUM_PRICE_NOT_REACHED");

        // Send tokens to user
        _transferToken(token, msg.sender, finalPrice);

        // Send ERC721 tokens to vault
        for (uint k = 0; k < tokenIds721.length; k++) {
            IERC721(lp.nft).safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds721[k]
            );
        }

        // Send ERC1155 tokens to vault
        for (uint k = 0; k < tokenAmounts1155.length; k++) {
            IERC1155(lp.nft).safeTransferFrom(
                msg.sender,
                address(this),
                lp.nftId,
                tokenAmounts1155[k],
                ""
            );
        }

        // Send protocol fee to protocol fee distributor and call a checkpoint
        _transferProtocolFee(token, totalProtocolFee);

        emit Sell(onBehalfOf, nftIds, finalPrice);
    }

    function _transferProtocolFee(
        address token,
        uint256 totalProtocolFee
    ) internal {
        // Send protocol fee to protocol fee distributor and call a checkpoint
        address feeDistributor = _addressProvider.getFeeDistributor();
        _transferToken(token, feeDistributor, totalProtocolFee);
        IFeeDistributor(feeDistributor).checkpoint(_token);
    }

    function _validateSellLP(
        address lpToken,
        address sellToken,
        DataTypes.LPType lpType,
        uint256 spotPrice,
        uint256 tokenAmount,
        uint256 fee
    ) internal view {
        // Can't sell to sell LP
        require(lpType != DataTypes.LPType.Sell, "TP:S:IS_SELL_LP");

        require(lpToken == sellToken, "TP:S:TOKEN_MISMATCH");

        require(
            tokenAmount >=
                spotPrice -
                    fee +
                    PercentageMath.percentMul(fee, _protocolFeePercentage),
            "TP:S:INSUFFICIENT_TOKENS_IN_LP"
        );
    }

    function swap(
        address onBehalfOf,
        uint256[] slLiquidityIds,
        uint256[] fromTokenIds,
        uint256[] toTokenIndexes,
        address token,
        address nft,
        uint256 maximumFee
    ) external payable returns (uint256) {
        require(slLiquidityIds.length > 0, "TP:S:EMPTY_LPS");
        require(
            slLiquidityIds.length == fromTokenIds.length &&
                slLiquidityIds.length == toTokenIds.length,
            "TP:S:MISMATCH_LP_LENGTH"
        );
        if (token == address(0)) {
            require(msg.value == maximumFee, "TV:B:NOT_ENOUGH_ETH");
        }

        uint256 totalFee;
        uint256 totalProtocolFee;
        uint256 protocolFee;
        uint256[] outNFTIds;
        DataTypes.SwapLiquidity memory sl;
        for (uint i = 0; i < slLiquidityIds.length; i++) {
            sl = _swapLiquidity[slLiquidityIds[i]];
            require(sl.nft == nft, "TP:S:NFT_MISMATCH");
            totalFee += sl.fee;
            protocolFee = PercentageMath.percentMul(
                sl.fee,
                _protocolFeePercentage
            );
            totalProtocolFee += protocolFee;

            // Swap NFTs in swap liquidity
            outNFTIds.push(sl.nftIds[toTokenIndexes[i]]);
            sl.nftIds[toTokenIndexes[i]] = fromTokenIds[i];
        }

        require(totalFee <= maximumFee, "TP:S:MAX_FEE_EXCEEDED");

        // Get tokens from user or send ETH back
        if (token == address(0)) {
            (bool sent, ) = payable(this).call{
                value: maximumPrice - finalPrice
            }("");
            require(sent, "TV:B:ETH_TRANSFER_FAILED");
        } else {
            IERC20(token).safeTransferFrom(
                msg.sender,
                address(this),
                finalPrice
            );
        }

        // Send NFTs to Vault and to user
        for (uint i = 0; i < outNFTIds.length; i++) {
            IERC721(nft).safeTransferFrom(
                address(this),
                msg.sender,
                outNFTIds[i]
            );
        }
        for (uint i = 0; i < fromTokenIds.length; i++) {
            IERC721(nft).safeTransferFrom(
                msg.sender,
                address(this),
                fromTokenIds[i]
            );
        }

        // Send protocol fee to protocol fee distributor and call a checkpoint
        address feeDistributor = _addressProvider.getFeeDistributor();
        IERC20(_token).safeTransfer(feeDistributor, totalProtocolFee);
        IFeeDistributor(feeDistributor).checkpoint(_token);

        emit Swap(onBehalfOf, slLiquidityIds, fromTokenIds, toTokenIds);
    }

    function setProtocolFeePercentage(
        uint256 protocolFeePercentage
    ) external onlyOwner {
        _protocolFeePercentage = protocolFeePercentage;
    }

    function _transferToken(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            (bool sent, ) = payable(to).call{value: amount}("");
            require(sent, "TV:ETH_TRANSFER_FAILED");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function _initLiquidityPoolToken(
        address nft,
        address token
    ) internal returns (address liquidityPoolToken) {
        liquidityPoolToken = _lpToken[nft][token];

        // Create the NFT LP contract if it doesn't exist
        if (liquidityPoolToken == address(0)) {
            // Deploy ERC721 LP contract
            liquidityPoolToken = address(
                new LiquidityPoolToken(
                    string.concat(
                        "leNFT2 Trading Pool ",
                        IERC721Metadata(nft).symbol(),
                        " - ",
                        IERC20Metadata(token).symbol()
                    ),
                    string.concat(
                        "leT2",
                        IERC721Metadata(nft).symbol(),
                        "-",
                        IERC20Metadata(token).symbol()
                    )
                )
            );
        }
    }

    function _validateAddLiquidity(
        DataTypes.LPType lpType,
        address nft,
        uint256 nftAmount,
        address token,
        uint256 tokenAmount,
        uint256 spotPrice,
        address curve,
        uint256 delta,
        uint256 fee
    ) internal view {
        // If the user is sending ETH we check the message value
        if (token == address(0)) {
            require(msg.value == tokenAmount, "TV:AL:ETH_AMOUNT_MISMATCH");
        }
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
    }

    function _requireNotPaused() internal view {
        require(!_paused, "TV:PAUSED");
    }
}
