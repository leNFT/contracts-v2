// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {IPeerLendingMarket} from "../../../interfaces/IPeerLendingMarket.sol";
import {PeerBorrowLogic} from "../../../libraries/logic/PeerBorrowLogic.sol";
import {IPeerLoanCenter} from "../../../interfaces/IPeerLoanCenter.sol";
import {DataTypes} from "../../../libraries/types/DataTypes.sol";
import {ConfigTypes} from "../../../libraries/types/ConfigTypes.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAddressProvider} from "../../../interfaces/IAddressProvider.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ERC165CheckerUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title PeerLendingMarket Contract
/// @author leNFT
/// @notice This contract is the entrypoint for the leNFT peer-to-peer lending protocol
/// @dev Call these contract functions to interact with the lending part of the protocol
contract PeerLendingMarket is
    IPeerLendingMarket,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ERC721HolderUpgradeable,
    ERC1155HolderUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ERC165CheckerUpgradeable for address;

    IAddressProvider private immutable _addressProvider;

    uint256 private _liquidityCount;

    mapping(address => bool) private _isInterestRateCurve;

    // PeerLendingLiquidity
    mapping(uint256 => DataTypes.LendingLiquidity) private _lendingLiquidity;

    // Supported collections per lending liquidity
    mapping(uint256 => mapping(address => bool)) private _supportedCollections;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IAddressProvider addressProvider) {
        _addressProvider = addressProvider;
        _disableInitializers();
    }

    /// @notice Initialize the PeerLendingMarket contract
    function initialize() external initializer {
        __Ownable_init();
        __ERC721Holder_init();
        __ReentrancyGuard_init();
    }

    function isInterestRateCurve(
        address interestRateCurve
    ) external view override returns (bool) {
        return _isInterestRateCurve[priceCurve];
    }

    function setInterestRateCurve(
        address interestRateCurve,
        bool valid
    ) external onlyOwner {
        // Make sure the price curve is valid
        require(
            priceCurve.supportsInterface(type(IInterestRateCurve).interfaceId),
            "TPF:SPC:NOT_IRC"
        );
        _isInterestRateCurve[priceCurve] = valid;
    }

    function addLiquidity(
        address onBehalfOf,
        address asset,
        uint256 amount,
        uint256 maxBorrowableAmount,
        uint256 maxDuration,
        address interestRateCurve,
        uint256 delta,
        uint256 resetPeriod
    ) external override {
        require(amount > 0, "PLM:AL:AMOUNT_ZERO");
        require(maxBorrowableAmount > 0, "PLM:AL:MAX_AMOUNT_ZERO");
        require(maxDuration > 0, "PLM:AL:MAX_DURATION_ZERO");
        require(resetPeriod > 0, "PLM:AL:RESET_PERIOD_ZERO");

        // Make sure the price curve is valid
        require(
            priceCurve.supportsInterface(type(IInterestRateCurve).interfaceId),
            "PLM:AL:NOT_IRC"
        );

        // Save a new peer lending liquidity struct
        _lendingLiquidity[_liquidityCount] = DataTypes.LendingLiquidity({
            owner: onBehalfOf,
            loanCount: 0,
            tokenAmount: amount,
            maxBorrowableAmount: maxBorrowableAmount,
            maxDuration: maxDuration,
            interestRateCurve: interestRateCurve,
            delta: delta,
            resetPeriod: resetPeriod
        });

        // Increase the liquidity count
        _liquidityCount++;

        // Transfer the asset to the contract
        IERC20Upgradeable(asset).safeTransferFrom(
            onBehalfOf,
            address(this),
            amount
        );

        _safeMint(onBehalfOf, _liquidityCount);
    }

    function removeLiquidity(uint256 liquidityId) external override {
        // Make sure the caller is the owner of the liquidity
        require(
            _lendingLiquidity[liquidityId].owner == msg.sender,
            "PLM:RL:NOT_OWNER"
        );
        // Make sure there are no loans using this liquidity at the moment
        require(
            _lendingLiquidity[liquidityId].loanCount == 0,
            "PLM:RL:LOAN_EXISTS"
        );

        // Transfer the asset back to the owner
        IERC20Upgradeable(asset).safeTransfer(
            msg.sender,
            _lendingLiquidity[liquidityId].tokenAmount
        );

        // Delete the liquidity
        delete _lendingLiquidity[liquidityId];

        // Burn the liquidity token
        _burn(liquidityId);
    }

    function removeLiquidityBatch(uint256[] liquidityIds) external override {
        for (uint256 i = 0; i < liquidityIds.length; i++) {
            removeLiquidity(liquidityIds[i]);
        }
    }

    function borrow721(
        address onBehalfOf,
        address asset,
        uint256 amount,
        address tokenAddress,
        uint256[] tokenIds,
        uint256 liquidityId
    ) external override {
        PeerBorrowLogic.borrow(
            _addressProvider,
            DataTypes.PeerBorrowParams({
                caller: msg.sender,
                onBehalfOf: onBehalfOf,
                asset: asset,
                amount: amount,
                collateralType: DataTypes.TokenStandard.ERC721,
                tokenAddress: tokenAddress,
                tokenIds: tokenIds,
                tokenAmounts: new uint256[](0),
                liquidityId: liquidityId
            })
        );

        emit Borrow721(
            onBehalfOf,
            asset,
            amount,
            tokenAddress,
            tokenIds,
            liquidityId
        );
    }

    function borrow1155(
        address onBehalfOf,
        address asset,
        uint256 amount,
        address tokenAddress,
        uint256[] tokenIds,
        uint256[] tokenAmounts,
        uint256 liquidityId
    ) external override {
        PeerBorrowLogic.borrow(
            _addressProvider,
            DataTypes.PeerBorrowParams({
                caller: msg.sender,
                onBehalfOf: onBehalfOf,
                asset: asset,
                amount: amount,
                collateralType: DataTypes.TokenStandard.ERC721,
                tokenAddress: tokenAddress,
                tokenIds: tokenIds,
                tokenAmounts: tokenAmounts,
                liquidityId: liquidityId
            })
        );

        emit Borrow1155(
            onBehalfOf,
            asset,
            amount,
            tokenAddress,
            tokenIds,
            tokenAmounts,
            liquidityId
        );
    }

    function repay(
        uint256 loanId,
        uint256 amount
    ) external override nonReentrant {
        PeerBorrowLogic.repay(
            _addressProvider,
            DataTypes.RepayParams({
                caller: msg.sender,
                loanId: loanId,
                amount: amount
            })
        );

        emit Repay(msg.sender, loanId);
    }

    /// @notice Claim the collateral from a loan
    /// @param loanId The ID of the loan to claim the collateral from
    function claimCollateral(uint256 loanId) external override {
        IPeerLoanCenter peerLoanCenter = IPeerLoanCenter(
            _addressProvider.getPeerLoanCenter()
        );
        DataTypes.PeerLoanData memory loanData = peerLoanCenter.getLoan(loanId);

        // Make sure the loan is active
        require(
            loanData.state == DataTypes.LoanState.Active,
            "PLM:CC:LOAN_NOT_ACTIVE"
        );

        // Make sure the loan is expired
        require(
            loanData.expiryTimestamp < block.timestamp,
            "PLM:CC:LOAN_NOT_EXPIRED"
        );

        // Make sure the caller is the lender
        require(
            _lendingLiquidity[loanData.lendingLiqudity].owner == msg.sender,
            "PLM:CC:NOT_LENDER"
        );

        // Mark the loan as liquidated
        peerLoanCenter.liquidateLoan(loanId);

        // Transfer the collateral to the lender
        if (loanData.collateralType == DataTypes.TokenStandard.ERC721) {
            for (uint256 i = 0; i < loanData.tokenIds; i++) {
                IERC721Upgradeable(loanData.asset).safeTransferFrom(
                    address(this),
                    msg.sender,
                    i
                );
            }
        } else {
            IERC1155Upgradeable(loanData.asset).safeBatchTransferFrom(
                address(this),
                msg.sender,
                loanData.tokenIds,
                loanData.tokenAmounts,
                ""
            );
        }
    }
}
