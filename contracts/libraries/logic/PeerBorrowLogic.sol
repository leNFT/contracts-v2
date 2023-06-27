// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {DataTypes} from "../types/DataTypes.sol";
import {PercentageMath} from "../utils/PercentageMath.sol";
import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";
import {IPeerLoanCenter} from "../../interfaces/IPeerLoanCenter.sol";
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
library PeerBorrowLogic {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice Creates a new loan, transfers the collateral to the loan center and mints the debt token
    /// @param addressProvider The address of the addresses provider
    /// @param lendingPool The address of the lending pool
    /// @param params A struct with the parameters of the borrow function
    /// @return loanId The id of the new loan
    function borrow(
        IAddressProvider addressProvider,
        DataTypes.PeerBorrowParams memory params
    ) external returns (uint256 loanId) {
        IPeerLoanCenter loanCenter = IPeerLoanCenter(
            addressProvider.getLoanCenter()
        );

        // Validate the borrow parameters
        _validateBorrow(
            addressProvider,
            lendingPool,
            address(loanCenter)
            params
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
        IPeerLoanCenter loanCenter = IPeerLoanCenter(
            addressProvider.getLoanCenter()
        );
        DataTypes.PeerLoanData memory loanData = loanCenter.getLoan(
            params.loanId
        );
        uint256 interest = loanCenter.getLoanInterest(params.loanId);
        uint256 loanDebt = interest + loanData.amount;

        // Validate the repay parameters
        _validateRepay(params.amount, loanData.state, loanDebt);
    }

    /// @notice Validates the parameters of the borrow function
    /// @param addressProvider The address of the addresses provider
    /// @param lendingPool The address of the lending pool
    /// @param loanCenter The address loan center
    /// @param params A struct with the parameters of the borrow function
    function _validateBorrow(
        IAddressProvider addressProvider,
        address lendingPool,
        address loanCenter,
        uint256 maxLTVBoost,
        DataTypes.PeerBorrowParams memory params
    ) internal view {
        // Check if borrow amount is bigger than 0
        require(params.amount > 0, "VL:VB:AMOUNT_0");

        // Check if theres at least one asset to use as collateral
        require(params.tokenIds.length > 0, "VL:VB:NO_NFTS");

        // Check if the lending pool exists
        require(lendingPool != address(0), "VL:VB:INVALID_LENDING_POOL");
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
}
