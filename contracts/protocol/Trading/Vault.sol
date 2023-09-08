// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {DataTypes} from "../../libraries/types/DataTypes.sol";
import {SafeCast} from "../../libraries/utils/SafeCast.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {ILiquidityPoolToken} from "../../interfaces/ILiquidityPoolToken.sol";
import {IFeeDistributor} from "../../interfaces/IFeeDistributor.sol";
import {PercentageMath} from "../../libraries/utils/PercentageMath.sol";
import {IPricingCurve} from "../../interfaces/IPricingCurve.sol";
import {VaultValidationLogic} from "../../libraries/logic/VaultValidationLogic.sol";
import {VaultGeneralLogic} from "../../libraries/logic/VaultGeneralLogic.sol";
import {IERC721ReceiverUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import {IERC1155ReceiverUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "hardhat/console.sol";

contract Vault is
    OwnableUpgradeable,
    IVault,
    IERC721ReceiverUpgradeable,
    IERC1155ReceiverUpgradeable
{
    IAddressProvider private immutable _addressProvider;
    // mapping of valid price curves
    mapping(address => bool) private _isPriceCurve;
    mapping(address => mapping(address => address)) private _lpPoolTokens;
    mapping(address => mapping(address => address)) private _slPoolTokens;
    mapping(uint256 => address) private _liquidityIdPool;
    uint256 private _liquidityCount;
    mapping(uint256 => DataTypes.LiquidityPair721) private _liquidityPairs721;
    mapping(uint256 => DataTypes.LiquidityPair1155) private _liquidityPairs1155;
    mapping(uint256 => DataTypes.SwapLiquidity) private _swapLiquidity;
    mapping(uint256 => DataTypes.LiquidityType) _liquidityType;
    bool private _paused;
    uint256 private _protocolFeePercentage;

    using SafeERC20Upgradeable for IERC20Upgradeable;

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
        _protocolFeePercentage = protocolFeePercentage;
    }

    function getPoolAddress(
        uint256 liquidityId
    ) external view override returns (address) {
        return _liquidityIdPool[liquidityId];
    }

    function getLP721(
        uint256 liquidityId
    ) external view override returns (DataTypes.LiquidityPair721 memory) {
        return _liquidityPairs721[liquidityId];
    }

    function getLP1155(
        uint256 liquidityId
    ) external view override returns (DataTypes.LiquidityPair1155 memory) {
        return _liquidityPairs1155[liquidityId];
    }

    function getSL(
        uint256 liquidityId
    ) external view returns (DataTypes.SwapLiquidity memory) {
        return _swapLiquidity[liquidityId];
    }

    function isPriceCurve(address priceCurve) public view returns (bool) {
        return _isPriceCurve[priceCurve];
    }

    function setPriceCurve(address priceCurve, bool valid) external onlyOwner {
        _isPriceCurve[priceCurve] = valid;
    }

    function addLiquidityPair721(
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
    ) external payable notPaused {
        VaultValidationLogic.validateAddLiquidityPair(
            lpType,
            nftIds.length,
            token,
            tokenAmount,
            spotPrice,
            curve,
            delta,
            fee
        );

        address liquidityToken = _lpPoolTokens[nft][token];

        if (liquidityToken == address(0)) {
            liquidityToken = VaultGeneralLogic.initLiquidityPoolToken(
                DataTypes.LiquidityType.LP721,
                nft,
                token
            );
            _lpPoolTokens[nft][token] = liquidityToken;
        }

        // Send user token to the pool
        _receiveToken(token, tokenAmount);

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
        _liquidityIdPool[liquidityCount] = liquidityToken;

        // Mint liquidity position NFT
        ILiquidityPoolToken(liquidityToken).mint(receiver, liquidityCount);

        // Add user nfts to the pool
        _transfer721Batch(msg.sender, address(this), nft, nftIds);

        _liquidityCount++;

        emit AddLiquidity(
            receiver,
            DataTypes.LiquidityType.LP721,
            liquidityToken,
            liquidityCount
        );
    }

    function addLiquidityPair1155(
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
    ) external payable notPaused {
        VaultValidationLogic.validateAddLiquidityPair(
            lpType,
            nftAmount,
            token,
            tokenAmount,
            spotPrice,
            curve,
            delta,
            fee
        );

        address liquidityToken = _lpPoolTokens[nft][token];

        if (liquidityToken == address(0)) {
            liquidityToken = VaultGeneralLogic.initLiquidityPoolToken(
                DataTypes.LiquidityType.LP1155,
                nft,
                token
            );
            _lpPoolTokens[nft][token] = liquidityToken;
        }

        // Send user token to the pool
        _receiveToken(token, tokenAmount);

        uint256 liquidityCount = _liquidityCount;

        // Save the user deposit info
        _liquidityPairs1155[liquidityCount] = DataTypes.LiquidityPair1155({
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
        _liquidityType[liquidityCount] = DataTypes.LiquidityType.LP1155;
        _liquidityIdPool[liquidityCount] = liquidityToken;

        // Add user nfts to the pool
        IERC1155Upgradeable(nft).safeTransferFrom(
            msg.sender,
            address(this),
            nftId,
            nftAmount,
            ""
        );

        // Mint liquidity position NFT
        ILiquidityPoolToken(liquidityToken).mint(receiver, liquidityCount);

        _liquidityCount++;

        emit AddLiquidity(
            receiver,
            DataTypes.LiquidityType.LP1155,
            liquidityToken,
            liquidityCount
        );
    }

    function addSwapLiquidity(
        address receiver,
        address nft,
        uint256[] calldata nftIds,
        address token,
        uint256 fee
    ) external payable notPaused {
        address liquidityToken = _slPoolTokens[nft][token];

        if (liquidityToken == address(0)) {
            liquidityToken = VaultGeneralLogic.initLiquidityPoolToken(
                DataTypes.LiquidityType.SL,
                nft,
                token
            );
            _slPoolTokens[nft][token] = liquidityToken;
        }

        uint256 liquidityCount = _liquidityCount;

        // Save the user deposit info
        _swapLiquidity[liquidityCount] = DataTypes.SwapLiquidity({
            token: token,
            nft: nft,
            nftIds: nftIds,
            fee: fee,
            balance: 0
        });
        _liquidityType[liquidityCount] = DataTypes.LiquidityType.SL;
        _liquidityIdPool[liquidityCount] = liquidityToken;

        // Mint liquidity position NFT
        ILiquidityPoolToken(liquidityToken).mint(receiver, liquidityCount);

        // Add user nfts to the pool_liquidityPairs721
        _transfer721Batch(msg.sender, address(this), nft, nftIds);

        _liquidityCount++;

        emit AddLiquidity(
            receiver,
            DataTypes.LiquidityType.SL,
            liquidityToken,
            liquidityCount
        );
    }

    function removeLiquidity(uint256 liquidityId) external {
        _removeLiquidity(liquidityId);
    }

    function removeLiquityBatch(uint256[] calldata liquidityIds) external {
        for (uint i = 0; i < liquidityIds.length; i++) {
            _removeLiquidity(liquidityIds[i]);
        }
    }

    /// @notice Private function that removes a liquidity pair, sending back deposited tokens and transferring the NFTs to the user
    /// @param liquidityId The ID of the LP token to remove
    function _removeLiquidity(uint256 liquidityId) internal {
        address liquidityToken = _liquidityIdPool[liquidityId];
        //Require the caller owns LP
        VaultValidationLogic.validateRemoveLiquidity(
            liquidityToken,
            liquidityId
        );

        // Send pool nfts to the user
        address token;
        uint256 tokenAmount;
        if (_liquidityType[liquidityId] == DataTypes.LiquidityType.LP721) {
            _transfer721Batch(
                address(this),
                msg.sender,
                _liquidityPairs721[liquidityId].nft,
                _liquidityPairs721[liquidityId].nftIds
            );

            token = _liquidityPairs721[liquidityId].token;
            tokenAmount = _liquidityPairs721[liquidityId].tokenAmount;
            // delete the user deposit info
            delete _liquidityPairs721[liquidityId];
        } else if (
            _liquidityType[liquidityId] == DataTypes.LiquidityType.LP1155
        ) {
            IERC1155Upgradeable(_liquidityPairs1155[liquidityId].nft)
                .safeTransferFrom(
                    address(this),
                    msg.sender,
                    _liquidityPairs1155[liquidityId].nftId,
                    _liquidityPairs1155[liquidityId].nftAmount,
                    ""
                );
            token = _liquidityPairs1155[liquidityId].token;
            tokenAmount = _liquidityPairs1155[liquidityId].tokenAmount;

            // delete the user deposit info
            delete _liquidityPairs1155[liquidityId];
        }

        // Send ERC20 tokens back to the user
        _sendToken(token, msg.sender, tokenAmount);

        // Burn liquidity position NFT
        ILiquidityPoolToken(liquidityToken).burn(liquidityId);

        emit RemoveLiquity(msg.sender, liquidityId);
    }

    struct BoughtToken721 {
        address token;
        uint256 tokenId;
    }

    function swap(
        address recipient,
        DataTypes.SellRequest calldata sellRequest,
        DataTypes.BuyRequest calldata buyRequest,
        DataTypes.SwapRequest calldata swapRequest,
        address token
    ) external payable returns (uint256 buyPrice, uint256 sellPrice) {
        uint256 totalProtocolFee;
        uint256 protocolFeePercentage = _protocolFeePercentage;

        // Start by performing the sells
        if (sellRequest.liquidityIds.length > 0) {
            VaultValidationLogic.validateSell(
                sellRequest.liquidityIds,
                sellRequest.tokenIds721,
                sellRequest.tokenAmounts1155
            );

            // Transfer the NFTs to the pool
            for (uint i = 0; i < sellRequest.liquidityIds.length; i++) {
                if (i < sellRequest.tokenIds721.length) {
                    uint256 tokenId721 = sellRequest.tokenIds721[i];
                    DataTypes.LiquidityPair721
                        memory lp721 = _liquidityPairs721[
                            sellRequest.liquidityIds[i]
                        ];

                    VaultValidationLogic.validateSellLP(
                        lp721.token,
                        token,
                        lp721.lpType,
                        lp721.spotPrice,
                        lp721.tokenAmount,
                        PercentageMath.percentMul(lp721.spotPrice, lp721.fee),
                        protocolFeePercentage
                    );

                    // Update total price quote and fee sum
                    sellPrice += (lp721.spotPrice -
                        PercentageMath.percentMul(lp721.spotPrice, lp721.fee));
                    totalProtocolFee += PercentageMath.percentMul(
                        PercentageMath.percentMul(lp721.spotPrice, lp721.fee),
                        protocolFeePercentage
                    );

                    IERC721Upgradeable(lp721.nft).safeTransferFrom(
                        msg.sender,
                        address(this),
                        tokenId721
                    );

                    VaultGeneralLogic.updateLp721AfterSell(
                        lp721,
                        _liquidityPairs721[sellRequest.liquidityIds[i]],
                        PercentageMath.percentMul(lp721.spotPrice, lp721.fee),
                        protocolFeePercentage,
                        tokenId721
                    );
                } else {
                    DataTypes.LiquidityPair1155
                        memory lp1155 = _liquidityPairs1155[
                            sellRequest.liquidityIds[i]
                        ];
                    uint256 tokenAmount1155 = sellRequest.tokenAmounts1155[
                        i - sellRequest.tokenIds721.length
                    ];

                    VaultValidationLogic.validateSellLP(
                        lp1155.token,
                        token,
                        lp1155.lpType,
                        lp1155.spotPrice,
                        lp1155.tokenAmount,
                        PercentageMath.percentMul(lp1155.spotPrice, lp1155.fee),
                        protocolFeePercentage
                    );

                    // Update total price quote and fee sum
                    console.log("lp1155.spotPrice", lp1155.spotPrice);
                    console.log("lp1155.fee", lp1155.fee);
                    sellPrice += (lp1155.spotPrice -
                        PercentageMath.percentMul(
                            lp1155.spotPrice,
                            lp1155.fee
                        ));
                    totalProtocolFee += PercentageMath.percentMul(
                        PercentageMath.percentMul(lp1155.spotPrice, lp1155.fee),
                        protocolFeePercentage
                    );

                    IERC1155Upgradeable(lp1155.nft).safeTransferFrom(
                        msg.sender,
                        address(this),
                        lp1155.nftId,
                        tokenAmount1155,
                        ""
                    );

                    VaultGeneralLogic.updateLp1155AfterSell(
                        lp1155,
                        _liquidityPairs1155[sellRequest.liquidityIds[i]],
                        PercentageMath.percentMul(lp1155.spotPrice, lp1155.fee),
                        protocolFeePercentage,
                        tokenAmount1155
                    );
                }
            }

            // Make sure the final price is greater than or equal to the minimum price set by the user
            if (sellPrice < sellRequest.minimumPrice) {
                console.log("sellPrice", sellPrice);
                console.log(
                    "sellRequest.minimumPrice",
                    sellRequest.minimumPrice
                );
                revert MinPriceNotReached();
            }
        }

        BoughtToken721[] memory boughtTokens721 = new BoughtToken721[](
            buyRequest.lp721Indexes.length
        );

        // Perform the buys
        if (buyRequest.liquidityIds.length > 0) {
            for (uint i = 0; i < buyRequest.liquidityIds.length; i++) {
                if (i < buyRequest.lp721Indexes.length) {
                    DataTypes.LiquidityPair721
                        memory lp721 = _liquidityPairs721[
                            buyRequest.liquidityIds[i]
                        ];

                    VaultValidationLogic.validateBuyLP(
                        lp721.token,
                        token,
                        lp721.lpType
                    );

                    if (
                        buyRequest.lp721TokenIds[i] !=
                        lp721.nftIds[buyRequest.lp721Indexes[i]]
                    ) {
                        revert NFTMismatch();
                    }

                    // Increase total price and fee sum
                    buyPrice += (lp721.spotPrice +
                        PercentageMath.percentMul(lp721.spotPrice, lp721.fee));
                    totalProtocolFee += PercentageMath.percentMul(
                        PercentageMath.percentMul(lp721.spotPrice, lp721.fee),
                        protocolFeePercentage
                    );

                    // Save the bought token
                    boughtTokens721[i] = BoughtToken721({
                        token: lp721.nft,
                        tokenId: lp721.nftIds[buyRequest.lp721Indexes[i]]
                    });

                    VaultGeneralLogic.updateLp721AfterBuy(
                        lp721,
                        _liquidityPairs721[buyRequest.liquidityIds[i]],
                        PercentageMath.percentMul(lp721.spotPrice, lp721.fee),
                        protocolFeePercentage,
                        buyRequest.lp721Indexes[i]
                    );
                } else {
                    DataTypes.LiquidityPair1155
                        memory lp1155 = _liquidityPairs1155[
                            buyRequest.liquidityIds[i]
                        ];
                    uint256 tokenAmount1155 = buyRequest.lp1155Amounts[
                        i - buyRequest.lp721Indexes.length
                    ];

                    VaultValidationLogic.validateBuyLP(
                        lp1155.token,
                        token,
                        lp1155.lpType
                    );

                    // Increase total price and fee sum
                    buyPrice += (lp1155.spotPrice +
                        PercentageMath.percentMul(
                            lp1155.spotPrice,
                            lp1155.fee
                        ));
                    totalProtocolFee += PercentageMath.percentMul(
                        PercentageMath.percentMul(lp1155.spotPrice, lp1155.fee),
                        protocolFeePercentage
                    );

                    IERC1155Upgradeable(lp1155.nft).safeTransferFrom(
                        address(this),
                        recipient,
                        lp1155.nftId,
                        tokenAmount1155,
                        ""
                    );

                    VaultGeneralLogic.updateLp1155AfterBuy(
                        lp1155,
                        _liquidityPairs1155[buyRequest.liquidityIds[i]],
                        PercentageMath.percentMul(lp1155.spotPrice, lp1155.fee),
                        protocolFeePercentage
                    );
                }
            }

            if (buyPrice > buyRequest.maximumPrice) {
                revert MaxPriceExceeded();
            }
        }

        if (swapRequest.liquidityIds.length > 0) {
            VaultValidationLogic.validateSwap(
                swapRequest.liquidityIds,
                swapRequest.fromTokenIds721,
                swapRequest.toTokenIds721
            );
            DataTypes.SwapLiquidity memory sl;
            for (uint i = 0; i < swapRequest.liquidityIds.length; i++) {
                sl = _swapLiquidity[swapRequest.liquidityIds[i]];
                VaultValidationLogic.validateSwapSL(
                    sl.nft,
                    sl.token,
                    address(this),
                    token
                );
                _swapLiquidity[swapRequest.liquidityIds[i]].balance += SafeCast
                    .toUint128(sl.fee);
                buyPrice += (sl.fee +
                    PercentageMath.percentMul(sl.fee, protocolFeePercentage));
                totalProtocolFee += PercentageMath.percentMul(
                    sl.fee,
                    protocolFeePercentage
                );

                // Swap NFTs in swap liquidity
                if (i < swapRequest.fromTokenIds721.length) {
                    IERC721Upgradeable(sl.nft).safeTransferFrom(
                        msg.sender,
                        address(this),
                        swapRequest.fromTokenIds721[i]
                    );
                    if (
                        swapRequest.toTokenIds721[i] !=
                        sl.nftIds[swapRequest.toTokenIds721Indexes[i]]
                    ) {
                        revert NFTMismatch();
                    }

                    // Swap tokens in swap liquidity
                    _swapLiquidity[swapRequest.liquidityIds[i]].nftIds[
                            swapRequest.toTokenIds721Indexes[i]
                        ] = swapRequest.fromTokenIds721[i];

                    IERC721Upgradeable(sl.nft).safeTransferFrom(
                        address(this),
                        recipient,
                        swapRequest.toTokenIds721[i]
                    );
                } else {
                    BoughtToken721 memory boughtToken = boughtTokens721[
                        swapRequest.boughtLp721Indexes[
                            i - swapRequest.fromTokenIds721.length
                        ]
                    ];

                    if (boughtToken.token != sl.nft) {
                        revert NFTMismatch();
                    }

                    // Swap tokens in swap liquidity
                    _swapLiquidity[swapRequest.liquidityIds[i]].nftIds[
                            swapRequest.toTokenIds721Indexes[i]
                        ] = boughtToken.tokenId;
                    boughtTokens721[
                        swapRequest.boughtLp721Indexes[
                            i - swapRequest.fromTokenIds721.length
                        ]
                    ] = BoughtToken721({
                        token: sl.nft,
                        tokenId: swapRequest.fromTokenIds721[i]
                    });
                }
            }
        }

        for (uint i = 0; i < boughtTokens721.length; i++) {
            console.log("token", boughtTokens721[i].token);
            IERC721Upgradeable(boughtTokens721[i].token).safeTransferFrom(
                address(this),
                recipient,
                boughtTokens721[i].tokenId
            );
        }

        // Get tokens from user or send ETH back
        if (buyPrice > sellPrice) {
            _receiveToken(token, buyPrice - sellPrice);
        } else if (sellPrice > buyPrice) {
            _sendToken(token, recipient, sellPrice - buyPrice);
        }

        // Send protocol fee to protocol fee distributor and call a checkpoint
        address feeDistributor = _addressProvider.getFeeDistributor();
        _sendToken(token, feeDistributor, totalProtocolFee);
        IFeeDistributor(feeDistributor).checkpoint(token);
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
            console.log("1", amount);
            console.log("2", msg.value);
            if (msg.value != amount) {
                revert WrongMessageValue();
            }
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
            console.log("amount", amount);
            console.log("to", to);
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
}
