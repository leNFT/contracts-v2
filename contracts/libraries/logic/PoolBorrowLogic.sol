// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {DataTypes} from "../types/DataTypes.sol";
import {PercentageMath} from "../utils/PercentageMath.sol";
import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";
import {IPoolLoanCenter} from "../../interfaces/IPoolLoanCenter.sol";
import {ITokenOracle} from "../../interfaces/ITokenOracle.sol";
import {INFTOracle} from "../../interfaces/INFTOracle.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IGenesisNFT} from "../../interfaces/IGenesisNFT.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @title BorrowLogic
/// @author leNFT
/// @notice Contains the logic for the borrow and repay functions
/// @dev Library dealing with the logic for the borrow and repay functions
library PoolBorrowLogic {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice Creates a new loan, transfers the collateral to the loan center and mints the debt token
    /// @param addressProvider The address of the addresses provider
    /// @param lendingPool The address of the lending pool
    /// @param params A struct with the parameters of the borrow function
    /// @return loanId The id of the new loan
    function borrow(
        IAddressProvider addressProvider,
        address lendingPool,
        DataTypes.PoolBorrowParams memory params
    ) external returns (uint256 loanId) {
        ILoanCenter loanCenter = ILoanCenter(addressProvider.getLoanCenter());

        // If a genesis NFT was used with this loan we need to lock it
        uint256 maxLTVBoost;
        if (params.genesisNFTId != 0) {
            maxLTVBoost = IGenesisNFT(addressProvider.getGenesisNFT())
                .lockGenesisNFT(
                    params.onBehalfOf,
                    params.caller,
                    params.genesisNFTId
                );
        }

        // ------------------------- VALIDATION ------------------------- //

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

        // Check if the lending pool exists
        require(lendingPool != address(0), "VL:VB:INVALID_LENDING_POOL");

        // Check if borrow amount exceeds allowed amount
        (uint256 ethPrice, uint256 precision) = ITokenOracle(
            addressProvider.getTokenOracle()
        ).getTokenETHPrice(params.asset);

        require(
            params.amount <=
                (PercentageMath.percentMul(
                    INFTOracle(addressProvider.getNFTOracle())
                        .getTokensETHPrice(
                            params.tokenAddress,
                            params.tokenIds,
                            params.request,
                            params.packet
                        ),
                    ILoanCenter(loanCenter).getCollectionMaxLTV(
                        params.nftAddress
                    ) + maxLTVBoost
                ) * precision) /
                    ethPrice,
            "VL:VB:MAX_LTV_EXCEEDED"
        );

        // Check if the pool has enough underlying to borrow
        require(
            params.amount <= ILendingPool(lendingPool).getUnderlyingBalance(),
            "VL:VB:INSUFFICIENT_UNDERLYING"
        );

        // ------------------------- END VALIDATION ------------------------- //

        // Transfer the collateral to the the lending market
        if (params.collateralType == DataTypes.TokenStandard.ERC1155) {
            IERC1155Upgradeable(params.tokenAddress).safeBatchTransferFrom(
                params.caller,
                address(this),
                params.tokenIds,
                params.tokenAmounts,
                ""
            );
        } else {
            for (uint256 i = 0; i < params.tokenIds.length; i++) {
                IERC721Upgradeable(params.tokenAddress).safeTransferFrom(
                    params.caller,
                    address(this),
                    params.tokenIds[i]
                );
            }
        }

        // Get the current borrow rate index
        uint256 borrowRate = ILendingPool(lendingPool).getBorrowRate();

        // Create the loan
        loanId = loanCenter.createLoan(
            params.onBehalfOf,
            lendingPool,
            params.amount,
            params.tokenAddress,
            params.collateralType,
            params.tokenIds,
            params.tokenAmounts,
            params.genesisNFTId,
            borrowRate
        );

        // Send the principal to the borrower
        ILendingPool(lendingPool).transferUnderlying(
            params.caller,
            params.amount,
            borrowRate
        );
    }

    /// @notice Repays a loan, transfers the principal and interest to the lending pool and returns the collateral to the owner
    /// @param addressProvider The address of the addresses provider
    /// @param params A struct with the parameters of the repay function
    function repay(
        IAddressProvider addressProvider,
        DataTypes.RepayParams memory params
    ) external {
        // Get the loan
        ILoanCenter loanCenter = ILoanCenter(addressProvider.getLoanCenter());
        DataTypes.LoanData memory loanData = loanCenter.getLoan(params.loanId);
        uint256 interest = loanCenter.getLoanInterest(params.loanId);
        uint256 loanDebt = interest + loanData.amount;

        // ------------------------- VALIDATION ------------------------- //

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

        // ------------------------- END VALIDATION ------------------------- //

        // If we are paying the entire loan debt
        if (params.amount == loanDebt) {
            // If the loan was being liquidated we send the liquidators payment back with a fee
            if (loanData.state == DataTypes.LoanState.Auctioned) {
                address asset = IERC4626(loanData.pool).asset();

                DataTypes.LoanLiquidationData
                    memory liquidationData = loanCenter.getLoanLiquidationData(
                        params.loanId
                    );

                // Give max bid back to liquidator
                IERC20Upgradeable(asset).safeTransfer(
                    liquidationData.liquidator,
                    liquidationData.auctionMaxBid
                );
                // Get the fee from the user and give it to the auctioneer
                IERC20Upgradeable(asset).safeTransferFrom(
                    params.caller,
                    liquidationData.auctioneer,
                    loanCenter.getLoanAuctioneerFee(params.loanId)
                );
            }

            // Return the principal + interest
            ILendingPool(loanData.pool).receiveUnderlying(
                params.caller,
                loanData.amount,
                uint256(loanData.borrowRate),
                interest
            );

            // Repay the loan through the loan center contract
            loanCenter.repayLoan(params.loanId);

            // If a genesis NFT was used with this loan we need to unlock it
            if (loanData.genesisNFTId != 0) {
                // Unlock Genesis NFT
                IGenesisNFT(addressProvider.getGenesisNFT()).unlockGenesisNFT(
                    uint256(loanData.genesisNFTId)
                );
            }

            // Transfer the collateral back to the owner
            if (loanData.collateralType == DataTypes.TokenStandard.ERC1155)
                IERC1155Upgradeable(loanData.asset).safeBatchTransferFrom(
                    address(this),
                    loanData.owner,
                    loanData.tokenIds,
                    loanData.tokenAmounts,
                    ""
                );
            else {
                for (uint256 i = 0; i < loanData.tokenIds.length; i++) {
                    IERC721Upgradeable(loanData.asset).safeTransferFrom(
                        address(this),
                        loanData.owner,
                        loanData.tokenIds[i]
                    );
                }
            }
        }
        // User is sending less than the total debt
        else {
            // User is sending less than interest or the interest entirely
            if (params.amount <= interest) {
                ILendingPool(loanData.pool).receiveUnderlying(
                    params.caller,
                    0,
                    uint256(loanData.borrowRate),
                    params.amount
                );

                // Calculate how much time the user has paid off with sent amount
                loanCenter.updateLoanDebtTimestamp(
                    params.loanId,
                    uint256(loanData.debtTimestamp) +
                        ((365 days *
                            params.amount *
                            PercentageMath.PERCENTAGE_FACTOR) /
                            (loanData.amount * uint256(loanData.borrowRate)))
                );
            }
            // User is sending the full interest and closing part of the loan
            else {
                ILendingPool(loanData.pool).receiveUnderlying(
                    params.caller,
                    params.amount - interest,
                    uint256(loanData.borrowRate),
                    interest
                );
                loanCenter.updateLoanDebtTimestamp(
                    params.loanId,
                    block.timestamp
                );
                loanCenter.updateLoanAmount(
                    params.loanId,
                    loanData.amount - params.amount + interest
                );
            }
        }
    }
}
