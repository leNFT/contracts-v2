// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.21;

import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {DataTypes} from "../../libraries/types/DataTypes.sol";
import {SafeCast} from "../../libraries/utils/SafeCast.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {IWETH} from "../../interfaces/IWETH.sol";
import {ILiquidityToken} from "../../interfaces/ILiquidityToken.sol";
import {IFeeDistributor} from "../../interfaces/IFeeDistributor.sol";
import {PercentageMath} from "../../libraries/utils/PercentageMath.sol";
import {IPricingCurve} from "../../interfaces/IPricingCurve.sol";
import {VaultValidationLogic} from "../../libraries/logic/VaultValidationLogic.sol";
import {VaultGeneralLogic} from "../../libraries/logic/VaultGeneralLogic.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC721ReceiverUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import {IERC1155ReceiverUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";

contract Vault is
    OwnableUpgradeable,
    IVault,
    IERC721ReceiverUpgradeable,
    IERC1155ReceiverUpgradeable,
    ReentrancyGuardUpgradeable
{
    IAddressProvider private immutable _addressProvider;
    IWETH private immutable _weth;
    // mapping of valid price curves
    mapping(address => bool) private _isPriceCurve;
    mapping(address => mapping(address => address)) private _liquidityTokens;
    mapping(uint256 => address) private _liquidityIdToken;
    uint256 private _liquidityCount;
    mapping(uint256 => DataTypes.Liquidity721) private _liquidity721;
    mapping(uint256 => DataTypes.Liquidity1155) private _liquidity1155;
    mapping(uint256 => DataTypes.TokenStandard) _liquidityTokenStandard;
    bool private _paused;
    uint256 private _protocolFeePercentage;

    using SafeERC20Upgradeable for IERC20Upgradeable;

    modifier notPaused() {
        _requireNotPaused();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IAddressProvider addressProvider, IWETH weth) {
        _addressProvider = addressProvider;
        _weth = weth;
        _disableInitializers();
    }

    function initialize(uint256 protocolFeePercentage) external initializer {
        __Ownable_init();
        _protocolFeePercentage = protocolFeePercentage;
    }

    function getLiquidityToken(
        uint256 liquidityId
    ) external view override returns (address) {
        return _liquidityIdToken[liquidityId];
    }

    function getLiquidity721(
        uint256 liquidityId
    ) external view override returns (DataTypes.Liquidity721 memory) {
        return _liquidity721[liquidityId];
    }

    function getLiquidity1155(
        uint256 liquidityId
    ) external view override returns (DataTypes.Liquidity1155 memory) {
        return _liquidity1155[liquidityId];
    }

    function isPriceCurve(address priceCurve) public view returns (bool) {
        return _isPriceCurve[priceCurve];
    }

    function setPriceCurve(address priceCurve, bool valid) external onlyOwner {
        _isPriceCurve[priceCurve] = valid;
    }

    function addLiquidity721(
        address receiver,
        DataTypes.LiquidityType liquidityType,
        address nft,
        uint256[] calldata nftIds,
        address token,
        uint256 tokenAmount,
        uint256 spotPrice,
        address curve,
        uint256 delta,
        uint256 fee,
        uint256 swapFee
    ) external payable notPaused {
        VaultValidationLogic.validateAddLiquidity(
            liquidityType,
            DataTypes.TokenStandard.ERC721,
            nftIds.length,
            token,
            tokenAmount,
            spotPrice,
            curve,
            delta,
            fee,
            swapFee
        );
        address liquidityToken = _liquidityTokens[nft][
            token == address(0) ? address(_weth) : token
        ];

        if (liquidityToken == address(0)) {
            liquidityToken = VaultGeneralLogic.initLiquidityToken(
                DataTypes.TokenStandard.ERC721,
                nft,
                token == address(0) ? address(_weth) : token
            );
            _liquidityTokens[nft][
                token == address(0) ? address(_weth) : token
            ] = liquidityToken;
        }

        // Send user token to the vault
        _receiveToken(token, tokenAmount);

        uint256 liquidityCount = _liquidityCount;

        // Save the user deposit info
        _liquidity721[liquidityCount] = DataTypes.Liquidity721({
            liquidityType: liquidityType,
            nftIds: nftIds,
            token: token == address(0) ? address(_weth) : token,
            nft: nft,
            tokenAmount: SafeCast.toUint128(tokenAmount),
            spotPrice: SafeCast.toUint128(spotPrice),
            curve: curve,
            delta: SafeCast.toUint128(delta),
            fee: SafeCast.toUint16(fee),
            swapFee: SafeCast.toUint128(swapFee)
        });
        _liquidityTokenStandard[liquidityCount] = DataTypes
            .TokenStandard
            .ERC721;
        _liquidityIdToken[liquidityCount] = liquidityToken;

        // Mint liquidity position NFT
        ILiquidityToken(liquidityToken).mint(receiver, liquidityCount);

        _liquidityCount++;

        // Add user nfts to the vault
        _transfer721Batch(msg.sender, address(this), nft, nftIds);

        emit AddLiquidity(
            receiver,
            DataTypes.TokenStandard.ERC721,
            liquidityToken,
            liquidityCount
        );
    }

    function addLiquidity1155(
        address receiver,
        DataTypes.LiquidityType liquidityType,
        address nft,
        uint256 nftId,
        uint256 nftAmount,
        address token,
        uint256 tokenAmount,
        uint256 spotPrice,
        address curve,
        uint256 delta,
        uint256 fee
    ) external payable notPaused {
        VaultValidationLogic.validateAddLiquidity(
            liquidityType,
            DataTypes.TokenStandard.ERC1155,
            nftAmount,
            token,
            tokenAmount,
            spotPrice,
            curve,
            delta,
            fee,
            0
        );

        address erc20Token = token == address(0) ? address(_weth) : token;
        address liquidityToken = _liquidityTokens[nft][erc20Token];

        if (liquidityToken == address(0)) {
            liquidityToken = VaultGeneralLogic.initLiquidityToken(
                DataTypes.TokenStandard.ERC1155,
                nft,
                erc20Token
            );
            _liquidityTokens[nft][erc20Token] = liquidityToken;
        }

        // Send user token to the vault
        _receiveToken(token, tokenAmount);

        uint256 liquidityCount = _liquidityCount;

        // Save the user deposit info
        _liquidity1155[liquidityCount] = DataTypes.Liquidity1155({
            liquidityType: liquidityType,
            nftId: nftId,
            nft: nft,
            token: erc20Token,
            nftAmount: SafeCast.toUint128(nftAmount),
            tokenAmount: SafeCast.toUint128(tokenAmount),
            spotPrice: SafeCast.toUint128(spotPrice),
            curve: curve,
            delta: SafeCast.toUint128(delta),
            fee: SafeCast.toUint16(fee)
        });
        _liquidityTokenStandard[liquidityCount] = DataTypes
            .TokenStandard
            .ERC1155;
        _liquidityIdToken[liquidityCount] = liquidityToken;

        // Mint liquidity position NFT
        ILiquidityToken(liquidityToken).mint(receiver, liquidityCount);

        _liquidityCount++;

        // Add user nfts to the vault
        IERC1155Upgradeable(nft).safeTransferFrom(
            msg.sender,
            address(this),
            nftId,
            nftAmount,
            ""
        );

        emit AddLiquidity(
            receiver,
            DataTypes.TokenStandard.ERC1155,
            liquidityToken,
            liquidityCount
        );
    }

    function removeLiquidity(uint256 liquidityId, bool unwrap) external {
        _removeLiquidity(liquidityId, unwrap);
    }

    function removeLiquityBatch(
        uint256[] calldata liquidityIds,
        bool unwrap
    ) external {
        for (uint i = 0; i < liquidityIds.length; i++) {
            _removeLiquidity(liquidityIds[i], unwrap);
        }
    }

    /// @notice Private function that removes a liquidity pair, sending back deposited tokens and transferring the NFTs to the user
    /// @param liquidityId The ID of the LP token to remove
    /// @param unwrap Whether to unwrap WETH to ETH
    function _removeLiquidity(uint256 liquidityId, bool unwrap) internal {
        address liquidityToken = _liquidityIdToken[liquidityId];
        //Require the caller owns LP
        VaultValidationLogic.validateRemoveLiquidity(
            liquidityToken,
            liquidityId
        );

        // Send vault nfts to the user
        address token;
        uint256 tokenAmount;
        if (
            _liquidityTokenStandard[liquidityId] ==
            DataTypes.TokenStandard.ERC721
        ) {
            _transfer721Batch(
                address(this),
                msg.sender,
                _liquidity721[liquidityId].nft,
                _liquidity721[liquidityId].nftIds
            );

            token = _liquidity721[liquidityId].token;
            tokenAmount = _liquidity721[liquidityId].tokenAmount;
            // delete the user deposit info
            delete _liquidity721[liquidityId];
        } else if (
            _liquidityTokenStandard[liquidityId] ==
            DataTypes.TokenStandard.ERC1155
        ) {
            IERC1155Upgradeable(_liquidity1155[liquidityId].nft)
                .safeTransferFrom(
                    address(this),
                    msg.sender,
                    _liquidity1155[liquidityId].nftId,
                    _liquidity1155[liquidityId].nftAmount,
                    ""
                );
            token = _liquidity1155[liquidityId].token;
            tokenAmount = _liquidity1155[liquidityId].tokenAmount;

            // delete the user deposit info
            delete _liquidity1155[liquidityId];
        }

        // Send ERC20 tokens back to the user
        _sendToken(
            token == address(_weth) && unwrap ? address(0) : token,
            msg.sender,
            tokenAmount
        );

        // Burn liquidity position NFT
        ILiquidityToken(liquidityToken).burn(liquidityId);

        emit RemoveLiquity(msg.sender, liquidityToken, liquidityId);
    }

    struct BoughtToken721 {
        address token;
        uint256 tokenId;
    }

    function swap(
        address receiver,
        address token,
        DataTypes.SwapParams calldata swapParams
    )
        external
        payable
        nonReentrant
        notPaused
        returns (uint256 buyPrice, uint256 sellPrice)
    {
        uint256 totalProtocolFee;
        uint256 protocolFeePercentage = _protocolFeePercentage;

        // Start by performing the sells
        if (swapParams.sell.liquidityIds.length > 0) {
            if (
                swapParams.sell.tokenIds721.length +
                    swapParams.sell.tokenAmounts1155.length !=
                swapParams.sell.liquidityIds.length
            ) {
                revert LiquidityMismatch();
            }

            // Transfer the NFTs to the vault
            for (uint i = 0; i < swapParams.sell.liquidityIds.length; i++) {
                if (i < swapParams.sell.tokenIds721.length) {
                    uint256 tokenId721 = swapParams.sell.tokenIds721[i];
                    DataTypes.Liquidity721 memory liquidity721 = _liquidity721[
                        swapParams.sell.liquidityIds[i]
                    ];

                    if (liquidity721.nft == address(0)) {
                        revert NonexistentLiquidity();
                    }
                    // Can't sell to sell or swap LP
                    if (
                        liquidity721.liquidityType ==
                        DataTypes.LiquidityType.Sell ||
                        liquidity721.liquidityType ==
                        DataTypes.LiquidityType.Swap
                    ) {
                        revert IncompatibleLiquidity(
                            swapParams.sell.liquidityIds[i]
                        );
                    }

                    if (
                        liquidity721.token !=
                        (token == address(0) ? address(_weth) : token)
                    ) {
                        revert TokenMismatch();
                    }

                    uint256 feeAmount = PercentageMath.percentMul(
                        liquidity721.spotPrice,
                        liquidity721.fee
                    );

                    if (
                        liquidity721.tokenAmount <
                        liquidity721.spotPrice -
                            feeAmount +
                            PercentageMath.percentMul(
                                feeAmount,
                                protocolFeePercentage
                            )
                    ) {
                        revert InsufficientTokensInLP();
                    }

                    // Update total price quote and fee sum
                    sellPrice += (liquidity721.spotPrice - feeAmount);
                    totalProtocolFee += PercentageMath.percentMul(
                        feeAmount,
                        protocolFeePercentage
                    );

                    IERC721Upgradeable(liquidity721.nft).safeTransferFrom(
                        msg.sender,
                        address(this),
                        tokenId721
                    );

                    VaultGeneralLogic.updateLiquidity721AfterSell(
                        liquidity721,
                        _liquidity721[swapParams.sell.liquidityIds[i]],
                        feeAmount,
                        protocolFeePercentage,
                        tokenId721
                    );
                } else {
                    DataTypes.Liquidity1155
                        memory liquidity1155 = _liquidity1155[
                            swapParams.sell.liquidityIds[i]
                        ];
                    uint256 tokenAmount1155 = swapParams.sell.tokenAmounts1155[
                        i - swapParams.sell.tokenIds721.length
                    ];
                    if (liquidity1155.nft == address(0)) {
                        revert NonexistentLiquidity();
                    }

                    // Can't sell to sell LP
                    if (
                        liquidity1155.liquidityType ==
                        DataTypes.LiquidityType.Sell
                    ) {
                        revert IncompatibleLiquidity(
                            swapParams.sell.liquidityIds[i]
                        );
                    }

                    if (
                        liquidity1155.token !=
                        (token == address(0) ? address(_weth) : token)
                    ) {
                        revert TokenMismatch();
                    }

                    uint256 price = IPricingCurve(liquidity1155.curve)
                        .sellPriceSum(
                            tokenAmount1155,
                            liquidity1155.spotPrice,
                            liquidity1155.delta
                        );
                    uint256 feeAmount = PercentageMath.percentMul(
                        price,
                        liquidity1155.fee
                    );

                    if (
                        liquidity1155.tokenAmount <
                        price -
                            feeAmount +
                            PercentageMath.percentMul(
                                feeAmount,
                                protocolFeePercentage
                            )
                    ) {
                        revert InsufficientTokensInLP();
                    }

                    // Update total price quote and fee sum
                    sellPrice += (price - feeAmount);
                    totalProtocolFee += PercentageMath.percentMul(
                        feeAmount,
                        protocolFeePercentage
                    );

                    IERC1155Upgradeable(liquidity1155.nft).safeTransferFrom(
                        msg.sender,
                        address(this),
                        liquidity1155.nftId,
                        tokenAmount1155,
                        ""
                    );

                    VaultGeneralLogic.updateLiquidity1155AfterSell(
                        liquidity1155,
                        _liquidity1155[swapParams.sell.liquidityIds[i]],
                        price,
                        feeAmount,
                        protocolFeePercentage,
                        tokenAmount1155
                    );
                }
            }

            // Make sure the final price is greater than or equal to the minimum price set by the user
            if (sellPrice < swapParams.sell.minimumPrice) {
                revert MinPriceNotReached();
            }

            emit Sell(
                receiver,
                swapParams.sell.liquidityIds,
                swapParams.sell.tokenIds721,
                swapParams.sell.tokenAmounts1155,
                sellPrice
            );
        }

        BoughtToken721[] memory boughtTokens721 = new BoughtToken721[](
            swapParams.buy.liquidity721Indexes.length
        );

        // Perform the buys
        if (swapParams.buy.liquidityIds.length > 0) {
            // Make sure the length of the liquidityIds array matches the sum of the buyParams arrays
            if (
                swapParams.buy.liquidity721TokenIds.length +
                    swapParams.buy.liquidity1155Amounts.length !=
                swapParams.buy.liquidityIds.length ||
                swapParams.buy.liquidity721Indexes.length !=
                swapParams.buy.liquidity721TokenIds.length
            ) {
                revert LiquidityMismatch();
            }

            for (uint i = 0; i < swapParams.buy.liquidityIds.length; i++) {
                if (i < swapParams.buy.liquidity721Indexes.length) {
                    DataTypes.Liquidity721 memory liquidity721 = _liquidity721[
                        swapParams.buy.liquidityIds[i]
                    ];

                    if (liquidity721.nft == address(0)) {
                        revert NonexistentLiquidity();
                    }
                    // Make sure the token for the LP is the same
                    if (
                        liquidity721.token !=
                        (token == address(0) ? address(_weth) : token)
                    ) {
                        revert TokenMismatch();
                    }

                    // Can't buy from buy LP
                    if (
                        liquidity721.liquidityType ==
                        DataTypes.LiquidityType.Buy
                    ) {
                        revert IncompatibleLiquidity(
                            swapParams.buy.liquidityIds[i]
                        );
                    }

                    if (
                        swapParams.buy.liquidity721TokenIds[i] !=
                        liquidity721.nftIds[
                            swapParams.buy.liquidity721Indexes[i]
                        ]
                    ) {
                        revert NFTMismatch();
                    }

                    uint256 feeAmount = PercentageMath.percentMul(
                        liquidity721.spotPrice,
                        liquidity721.fee
                    );

                    // Increase total price and fee sum
                    buyPrice += (liquidity721.spotPrice + feeAmount);
                    totalProtocolFee += PercentageMath.percentMul(
                        feeAmount,
                        protocolFeePercentage
                    );

                    // Save the bought token
                    boughtTokens721[i] = BoughtToken721({
                        token: liquidity721.nft,
                        tokenId: liquidity721.nftIds[
                            swapParams.buy.liquidity721Indexes[i]
                        ]
                    });

                    VaultGeneralLogic.updateLiquidity721AfterBuy(
                        liquidity721,
                        _liquidity721[swapParams.buy.liquidityIds[i]],
                        feeAmount,
                        protocolFeePercentage,
                        swapParams.buy.liquidity721Indexes[i]
                    );
                } else {
                    DataTypes.Liquidity1155
                        memory liquidity1155 = _liquidity1155[
                            swapParams.buy.liquidityIds[i]
                        ];
                    uint256 tokenAmount1155 = swapParams
                        .buy
                        .liquidity1155Amounts[
                            i - swapParams.buy.liquidity721Indexes.length
                        ];

                    if (liquidity1155.nft == address(0)) {
                        revert NonexistentLiquidity();
                    }

                    // Make sure the token for the LP is the same
                    if (
                        liquidity1155.token !=
                        (token == address(0) ? address(_weth) : token)
                    ) {
                        revert TokenMismatch();
                    }

                    // Can't buy from buy LP
                    if (
                        liquidity1155.liquidityType ==
                        DataTypes.LiquidityType.Buy
                    ) {
                        revert IncompatibleLiquidity(
                            swapParams.buy.liquidityIds[i]
                        );
                    }

                    if (
                        swapParams.buy.liquidity1155Amounts[
                            i - swapParams.buy.liquidity721Indexes.length
                        ] > liquidity1155.tokenAmount
                    ) {
                        revert InsufficientTokensInLP();
                    }

                    uint256 feeAmount = PercentageMath.percentMul(
                        liquidity1155.spotPrice,
                        liquidity1155.fee
                    );
                    uint256 price = IPricingCurve(liquidity1155.curve)
                        .buyPriceSum(
                            tokenAmount1155,
                            liquidity1155.spotPrice,
                            liquidity1155.delta
                        );

                    // Increase total price and fee sum
                    buyPrice += (price + feeAmount);
                    totalProtocolFee += PercentageMath.percentMul(
                        feeAmount,
                        protocolFeePercentage
                    );

                    IERC1155Upgradeable(liquidity1155.nft).safeTransferFrom(
                        address(this),
                        receiver,
                        liquidity1155.nftId,
                        tokenAmount1155,
                        ""
                    );

                    VaultGeneralLogic.updateLiquidity1155AfterBuy(
                        liquidity1155,
                        _liquidity1155[swapParams.buy.liquidityIds[i]],
                        price,
                        feeAmount,
                        protocolFeePercentage,
                        tokenAmount1155
                    );
                }
            }

            if (buyPrice > swapParams.buy.maximumPrice) {
                revert MaxPriceExceeded();
            }

            emit Buy(
                receiver,
                swapParams.buy.liquidityIds,
                swapParams.buy.liquidity721TokenIds,
                swapParams.buy.liquidity1155Amounts,
                buyPrice
            );
        }

        if (swapParams.swap.liquidityIds.length > 0) {
            if (
                swapParams.swap.liquidityIds.length !=
                swapParams.swap.fromTokenIds721.length +
                    swapParams.swap.bought721Indexes.length ||
                swapParams.swap.liquidityIds.length !=
                swapParams.swap.toTokenIds721Indexes.length
            ) {
                revert LiquidityMismatch();
            }
            DataTypes.Liquidity721 memory liquidity721;
            for (uint i = 0; i < swapParams.swap.liquidityIds.length; i++) {
                liquidity721 = _liquidity721[swapParams.swap.liquidityIds[i]];

                if (liquidity721.nft == address(0)) {
                    revert NonexistentLiquidity();
                }
                if (
                    liquidity721.token !=
                    (token == address(0) ? address(_weth) : token)
                ) {
                    revert TokenMismatch();
                }

                // Only allow swapping from liquidity with a swap fee
                if (liquidity721.swapFee == 0) {
                    revert IncompatibleLiquidity(
                        swapParams.swap.liquidityIds[i]
                    );
                }

                _liquidity721[swapParams.swap.liquidityIds[i]]
                    .tokenAmount += SafeCast.toUint128(
                    liquidity721.swapFee -
                        PercentageMath.percentMul(
                            liquidity721.swapFee,
                            protocolFeePercentage
                        )
                );
                buyPrice += liquidity721.swapFee;
                totalProtocolFee += PercentageMath.percentMul(
                    liquidity721.swapFee,
                    protocolFeePercentage
                );

                // Swap NFTs in swap liquidity
                if (i < swapParams.swap.fromTokenIds721.length) {
                    IERC721Upgradeable(liquidity721.nft).safeTransferFrom(
                        msg.sender,
                        address(this),
                        swapParams.swap.fromTokenIds721[i]
                    );
                    if (
                        swapParams.swap.toTokenIds721[i] !=
                        liquidity721.nftIds[
                            swapParams.swap.toTokenIds721Indexes[i]
                        ]
                    ) {
                        revert NFTMismatch();
                    }

                    // Swap tokens in swap liquidity
                    _liquidity721[swapParams.swap.liquidityIds[i]].nftIds[
                            swapParams.swap.toTokenIds721Indexes[i]
                        ] = swapParams.swap.fromTokenIds721[i];

                    IERC721Upgradeable(liquidity721.nft).safeTransferFrom(
                        address(this),
                        receiver,
                        swapParams.swap.toTokenIds721[i]
                    );
                } else {
                    BoughtToken721 memory boughtToken = boughtTokens721[
                        swapParams.swap.bought721Indexes[
                            i - swapParams.swap.fromTokenIds721.length
                        ]
                    ];

                    if (boughtToken.token != liquidity721.nft) {
                        revert NFTMismatch();
                    }

                    // Swap tokens in swap liquidity
                    _liquidity721[swapParams.swap.liquidityIds[i]].nftIds[
                            swapParams.swap.toTokenIds721Indexes[i]
                        ] = boughtToken.tokenId;

                    boughtTokens721[
                        swapParams.swap.bought721Indexes[
                            i - swapParams.swap.fromTokenIds721.length
                        ]
                    ] = BoughtToken721({
                        token: liquidity721.nft,
                        tokenId: swapParams.swap.toTokenIds721[i]
                    });
                }
            }

            emit Swap(
                receiver,
                swapParams.swap.liquidityIds,
                swapParams.swap.fromTokenIds721,
                swapParams.swap.bought721Indexes,
                swapParams.swap.toTokenIds721
            );
        }

        for (uint i = 0; i < boughtTokens721.length; i++) {
            IERC721Upgradeable(boughtTokens721[i].token).safeTransferFrom(
                address(this),
                receiver,
                boughtTokens721[i].tokenId
            );
        }

        // Get tokens from user or send ETH back
        if (buyPrice > sellPrice) {
            if (token == address(0) && msg.value < buyPrice - sellPrice) {
                revert WrongMessageValue();
            }
            _receiveToken(token, buyPrice - sellPrice);
        } else if (sellPrice > buyPrice) {
            _sendToken(token, receiver, sellPrice - buyPrice);
        }

        // Send protocol fee to protocol fee distributor and call a checkpoint
        address feeDistributor = _addressProvider.getFeeDistributor();
        _sendToken(
            (token == address(0) ? address(_weth) : token),
            feeDistributor,
            totalProtocolFee
        );
        IFeeDistributor(feeDistributor).checkpoint(
            (token == address(0) ? address(_weth) : token)
        );
    }

    function setProtocolFeePercentage(
        uint256 protocolFeePercentage
    ) external onlyOwner {
        _protocolFeePercentage = protocolFeePercentage;
    }

    function _transfer721Batch(
        address from,
        address to,
        address nft,
        uint256[] memory tokenIds
    ) internal {
        for (uint i = 0; i < tokenIds.length; i++) {
            IERC721Upgradeable(nft).safeTransferFrom(from, to, tokenIds[i]);
        }
    }

    function _receiveToken(address token, uint256 amount) internal {
        if (token == address(0)) {
            // In the case the user sends more ETH than needed, send it back
            if (msg.value > amount) {
                (bool sent, ) = msg.sender.call{value: msg.value - amount}("");
                if (!sent) {
                    revert ETHTransferFailed();
                }
            }
            // Deposit in WETH contract
            _weth.deposit{value: amount}();
        } else {
            IERC20Upgradeable(token).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }
    }

    function _sendToken(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            // Withdraw from WETH contract
            _weth.withdraw(amount);
            (bool sent, ) = to.call{value: amount}("");
            if (!sent) {
                revert ETHTransferFailed();
            }
        } else {
            IERC20Upgradeable(token).safeTransfer(to, amount);
        }
    }

    function _requireNotPaused() internal view {
        if (_paused) {
            revert Paused();
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155ReceiverUpgradeable.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == type(IERC721ReceiverUpgradeable).interfaceId ||
            interfaceId == type(IERC1155ReceiverUpgradeable).interfaceId;
    }

    receive() external payable {}
}
