// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {IPeerLendingMarket} from "../../../interfaces/IPeerLendingMarket.sol";
import {PercentageMath} from "../../../libraries/utils/PercentageMath.sol";
import {IPeerLoanCenter} from "../../../interfaces/IPeerLoanCenter.sol";
import {IInterestRateCurve} from "../../../interfaces/IInterestRateCurve.sol";
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

    // Supported collections for ERC721 liquidity
    mapping(uint256 => mapping(address => uint256))
        private _supportedERC721Collections;

    // Supported tokens for ERC1155 liquidity
    mapping(uint256 => mapping(address => mapping(uint256 => bool)))
        private _supportedERC1155Tokens;

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
        return _isInterestRateCurve[interestRateCurve];
    }

    function setInterestRateCurve(
        address interestRateCurve,
        bool valid
    ) external onlyOwner {
        // Make sure the price curve is valid
        require(
            interestRateCurve.supportsInterface(
                type(IInterestRateCurve).interfaceId
            ),
            "TPF:SPC:NOT_IRC"
        );
        _isInterestRateCurve[interestRateCurve] = valid;
    }

    function addLiquidity721(
        address onBehalfOf,
        address token,
        uint256 amount,
        address supportedAsset,
        uint256 maxBorrowableAmount,
        uint256 maxDuration,
        uint256 baseInterestRate,
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
            interestRateCurve.supportsInterface(
                type(IInterestRateCurve).interfaceId
            ),
            "PLM:AL:NOT_IRC"
        );

        // Save a new peer lending liquidity struct
        _lendingLiquidity[_liquidityCount] = DataTypes.LendingLiquidity({
            owner: onBehalfOf,
            token: token,
            tokenAmount: amount,
            maxDuration: maxDuration,
            baseInterestRate: baseInterestRate,
            interestRateCurve: interestRateCurve,
            delta: delta,
            resetPeriod: resetPeriod,
            lastLoanTimestamp: block.timestamp
        });

        // Add the supported asset and max borrowable amount to the mapping
        _supportedCollections[_liquidityCount][
            supportedAsset
        ] = maxBorrowableAmount;

        // Increase the liquidity count
        _liquidityCount++;

        // Transfer the asset to the contract
        IERC20Upgradeable(token).safeTransferFrom(
            onBehalfOf,
            address(this),
            amount
        );

        _safeMint(onBehalfOf, _liquidityCount);
    }

    function addLiquidity1155(
        address onBehalfOf,
        address asset,
        uint256 amount,
        address supportedAsset,
        uint256[] supportedTokenIds,
        uint256[] maxBorrowableAmounts,
        uint256 maxDuration,
        uint256 baseInterestRate,
        address interestRateCurve,
        uint256 delta,
        uint256 resetPeriod
    ) external override {
        require(amount > 0, "PLM:AL:AMOUNT_ZERO");
        require(maxDuration > 0, "PLM:AL:MAX_DURATION_ZERO");
        require(resetPeriod > 0, "PLM:AL:RESET_PERIOD_ZERO");
        require(
            supportedTokenIds.length == maxBorrowableAmounts.length,
            "PLM:AL:INVALID_LENGTH"
        );
        // Make sure there are no duplicate token ids and all the max borrowable amounts are greater than 0
        for (uint256 i = 0; i < supportedTokenIds.length; i++) {
            require(maxBorrowableAmounts[i] > 0, "PLM:AL:MAX_AMOUNT_ZERO");
            for (uint256 j = i + 1; j < supportedTokenIds.length; j++) {
                require(
                    supportedTokenIds[i] != supportedTokenIds[j],
                    "PLM:AL:DUPLICATE_TOKEN_ID"
                );
            }
        }

        // Make sure the price curve is valid
        require(
            interestRateCurve.supportsInterface(
                type(IInterestRateCurve).interfaceId
            ),
            "PLM:AL:NOT_IRC"
        );

        // Save a new peer lending liquidity struct
        _lendingLiquidity[_liquidityCount] = DataTypes.LendingLiquidity({
            owner: onBehalfOf,
            tokenAmount: amount,
            maxDuration: maxDuration,
            baseInterestRate: baseInterestRate,
            interestRateCurve: interestRateCurve,
            delta: delta,
            resetPeriod: resetPeriod
        });

        // Add the supported asset, tokens ids max borrowable amount to the mapping
        for (uint256 i = 0; i < supportedTokenIds.length; i++) {
            _supportedERC1155Tokens[_liquidityCount][supportedAsset][
                supportedTokenIds[i]
            ] = maxBorrowableAmounts[i];
        }

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
            _addressProvider.getLoanCenter()
        );

        // Check if borrow amount is bigger than 0
        require(amount > 0, "VL:VB:AMOUNT_0");

        // Check if theres at least one asset to use as collateral
        require(tokenIds.length > 0, "VL:VB:NO_NFTS");

        // Check if the loan amount exceeds the maximum loan amount

        // Check if the loan amount exceeds the available tokens in the liquidity

        uint256 loanInterestRate = IInterestRateCurve(
            _lendingLiquidity[liquidityId].interestRateCurve
        ).getLoanInterestRate(
                amount,
                _lendingLiquidity[liquidityId].baseInterestRate,
                _lendingLiquidity[liquidityId].delta,
                _lendingLiquidity[liquidityId].loanCount,
                _lendingLiquidity[liquidityId].resetPeriod,
                _lendingLiquidity[liquidityId].lastLoanTimestamp
            );

        // Create the loan
        loanCenter.createLoan(
            onBehalfOf,
            asset,
            amount,
            loanInterestRate,
            tokenAddress,
            tokenIds,
            [], // tokenAmounts
            liquidityId
        );

        // Update the lending liquidity
        _lendingLiquidity[liquidityId].tokenAmount -= amount;
        _lendingLiquidity[liquidityId].loanCount++;
        _lendingLiquidity[liquidityId].lastLoanTimestamp = block.timestamp;

        // Send the asset to the borrower
        IERC20Upgradeable(asset).safeTransfer(onBehalfOf, amount);

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
            _addressProvider.getLoanCenter()
        );

        // Check if borrow amount is bigger than 0
        require(amount > 0, "VL:VB:AMOUNT_0");

        // Check if theres at least one asset to use as collateral
        require(tokenIds.length > 0, "VL:VB:NO_NFTS");

        // Check if the token amounts are the same length as the token ids
        require(
            tokenIds.length == tokenAmounts.length,
            "VL:VB:LENGTH_MISMATCH"
        );

        // Check if the loan amount exceeds the maximum loan amount

        // Check if the loan amount exceeds the available tokens in the liquidity

        uint256 loanInterestRate = IInterestRateCurve(
            _lendingLiquidity[liquidityId].interestRateCurve
        ).getNextInterestRate(
                amount,
                _lendingLiquidity[liquidityId].baseInterestRate,
                _lendingLiquidity[liquidityId].delta,
                _lendingLiquidity[liquidityId].loanCount,
                _lendingLiquidity[liquidityId].resetPeriod,
                _lendingLiquidity[liquidityId].lastLoanTimestamp
            );

        // Create the loan
        loanCenter.createLoan(
            onBehalfOf,
            asset,
            amount,
            loanInterestRate,
            tokenAddress,
            tokenIds,
            tokenAmounts,
            liquidityId
        );

        // Update the lending liquidity
        _lendingLiquidity[liquidityId].tokenAmount -= amount;
        _lendingLiquidity[liquidityId].loanCount++;
        _lendingLiquidity[liquidityId].lastLoanTimestamp = block.timestamp;

        // Send the asset to the borrower
        IERC20Upgradeable(asset).safeTransfer(onBehalfOf, amount);

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
            _addressProvider.getLoanCenter()
        );
        DataTypes.PeerLoanData memory loanData = loanCenter.getLoan(loanId);
        uint256 interest = loanCenter.getLoanInterest(loanId);
        uint256 loanDebt = interest + loanData.amount;

        // Validate the repay parameters
        // Validate the movement
        // Check if borrow amount is bigger than 0
        require(amount > 0, "VL:VR:AMOUNT_0");

        //Require that loan exists
        require(
            loanData.state == DataTypes.LoanState.Active ||
                loanData.state == DataTypes.LoanState.Auctioned,
            "VL:VR:LOAN_NOT_FOUND"
        );

        // Check if user is over-paying
        require(amount <= loanDebt, "VL:VR:AMOUNT_EXCEEDS_DEBT");

        // Can only do partial repayments if the loan is not being auctioned
        if (amount < loanDebt) {
            require(
                loanData.state != DataTypes.LoanState.Auctioned,
                "VL:VR:PARTIAL_REPAY_AUCTIONED"
            );
        }

        // If we are paying the entire loan debt
        if (amount == loanDebt) {
            // Delete the lending liquidity if it has been removed and has no more loans
            if (
                !exists(loanData.liquidityId) &&
                _lendingLiquidity[loanData.lendingLiquidity].loanAmount == 1
            ) {
                delete _lendingLiquidity[loanData.lendingLiquidity];
            }

            // Mark the loan as repaid
            loanCenter.repayLoan(loanId);

            // Update the lending liquidity object
            _lendingLiquidity[loanData.lendingLiquidity].loanAmount--;
            _lendingLiquidity[loanData.lendingLiquidity].tokenAmount += loanData
                .amount;

            // Send the collateral back to the borrower
            if (loanData.collateralType == DataTypes.CollateralType.ERC721) {
                for (uint256 i = 0; i < loanData.tokenIds.length; i++) {
                    IERC721Upgradeable(loanData.tokenAddress).safeTransferFrom(
                        address(this),
                        loanData.owner,
                        loanData.tokenIds[i]
                    );
                }
            } else {
                IERC1155Upgradeable(loanData.tokenAddress)
                    .safeBatchTransferFrom(
                        address(this),
                        loanData.owner,
                        loanData.tokenIds,
                        loanData.tokenAmounts,
                        ""
                    );
            }
        }
        // User is sending less than the total debt
        else {
            // User is sending less than interest or the interest entirely
            if (amount <= interest) {
                IERC20Upgradeable(loanData.asset).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amount
                );

                // Calculate how much time the user has paid off with sent amount
                loanCenter.updateLoanDebtTimestamp(
                    loanId,
                    uint256(loanData.debtTimestamp) +
                        ((365 days *
                            amount *
                            PercentageMath.PERCENTAGE_FACTOR) /
                            (amount * uint256(loanData.borrowRate)))
                );
            }
            // User is sending the full interest and closing part of the loan
            else {
                IERC20Upgradeable(loanData.asset).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amount
                );
                loanCenter.updateLoanDebtTimestamp(loanId, block.timestamp);
                loanCenter.updateLoanAmount(loanId, amount - amount + interest);
            }
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
