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

    function removeLiquidity(uint256 liquidityId) public override {
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
        IERC20Upgradeable(_lendingLiquidity[liquidityId].asset).safeTransfer(
            msg.sender,
            _lendingLiquidity[liquidityId].tokenAmount
        );

        // Delete the liquidity
        if (_lendingLiquidity[liquidityId].loanCount == 0) {
            delete _lendingLiquidity[liquidityId];
        }

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
        IPeerLoanCenter loanCenter = IPeerLoanCenter(
            addressProvider.getLoanCenter()
        );

        // Validate the borrow parameters
        _validateBorrow(addressProvider, address(loanCenter), params);

        emit Borrow721(
            onBehalfOf,
            asset,
            tokenAddress,
            tokenIds,
            liquidityId,
            amount
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
        IPeerLoanCenter loanCenter = IPeerLoanCenter(
            addressProvider.getLoanCenter()
        );

        // Validate the borrow parameters
        _validateBorrow(addressProvider, address(loanCenter), params);

        emit Borrow1155(
            onBehalfOf,
            asset,
            tokenAddress,
            tokenIds,
            tokenAmounts,
            liquidityId,
            amount
        );
    }

    function repay(
        uint256 loanId,
        uint256 amount
    ) external override nonReentrant {
        // Get the loan
        IPeerLoanCenter loanCenter = IPeerLoanCenter(
            addressProvider.getLoanCenter()
        );
        DataTypes.PeerLoanData memory loanData = loanCenter.getLoan(
            params.loanId
        );

        // Validate the repay parameters
        _validateRepay(amount, loanData.state, loanDebt);

        if (
            amount == loanData.amount &&
            exists(loanData.liquidityId) &&
            _lendingLiquidity[loanData.lendingLiquidity].loanAmount - 1 == 0
        ) {
            delete _lendingLiquidity[loanData.lendingLiquidity];
            loanCenter
        }

        emit Repay(msg.sender, loanId);
    }

    /// @notice Claim the collateral from a loan
    /// @param loanId The ID of the loan to claim the collateral from
    function claimCollateral(uint256 loanId) external override {
        IPeerLoanCenter peerLoanCenter = IPeerLoanCenter(
            _addressProvider.getPeerLoanCenter()
        );
        DataTypes.PeerLoanData memory loanData = peerLoanCenter.getLoan(loanId);

        _validateClaimCollateral(loanData);

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

    /// @notice Validates the parameters of the borrow function
    /// @param addressProvider The address of the addresses provider
    /// @param loanCenter The address loan center
    /// @param params A struct with the parameters of the borrow function
    function _validateBorrow(
        IAddressProvider addressProvider,
        address loanCenter,
        DataTypes.PeerBorrowParams memory params
    ) internal view {
        // Check if borrow amount is bigger than 0
        require(params.amount > 0, "VL:VB:AMOUNT_0");

        // Check if theres at least one asset to use as collateral
        require(params.tokenIds.length > 0, "VL:VB:NO_NFTS");

        // If its an ERC1155 loan, check if the token amounts are the same length as the token ids
        if (params.tokenStandard == DataTypes.TokenStandard.ERC1155) {
            require(
                params.tokenIds.length == params.tokenAmounts.length,
                "VL:VB:LENGTH_MISMATCH"
            );
        }

        // Check if the loan amount exceeds the maximum loan amount

        // Check if the loan amount exceeds the available tokens in the liquidity
    }

    /// @notice Validates the parameters of the repay function
    /// @param repayAmount The amount to repay
    /// @param loanState The state of the loan
    /// @param loanDebt The debt of the loan
    function _validateRepay(
        uint256 repayAmount,
        DataTypes.LoanState loanState,
        uint256 loanDebt
    ) internal pure {
        // Validate the movement
        // Check if borrow amount is bigger than 0
        require(repayAmount > 0, "VL:VR:AMOUNT_0");

        //Require that loan exists
        require(
            loanState == DataTypes.LoanState.Active ||
                loanState == DataTypes.LoanState.Auctioned,
            "VL:VR:LOAN_NOT_FOUND"
        );

        // Check if user is over-paying
        require(repayAmount <= loanDebt, "VL:VR:AMOUNT_EXCEEDS_DEBT");

        // Can only do partial repayments if the loan is not being auctioned
        if (repayAmount < loanDebt) {
            require(
                loanState != DataTypes.LoanState.Auctioned,
                "VL:VR:PARTIAL_REPAY_AUCTIONED"
            );
        }
    }

    function _validateClaimCollateral(
        DataTypes.PeerLoanData memory loanData
    ) internal pure {
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
    }
}
