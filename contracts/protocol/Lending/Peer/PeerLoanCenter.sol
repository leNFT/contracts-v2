// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {IPeerLoanCenter} from "../../../interfaces/IPeerLoanCenter.sol";
import {PercentageMath} from "../../../libraries/utils/PercentageMath.sol";
import {DataTypes} from "../../../libraries/types/DataTypes.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAddressProvider} from "../../../interfaces/IAddressProvider.sol";
import {SafeCast} from "../../../libraries/utils/SafeCast.sol";
import {ILendingPool} from "../../../interfaces/ILendingPool.sol";

/// @title LoanCenter contract
/// @author leNFT
/// @notice Manages loans
/// @dev Keeps the list of loans, their states and their liquidation data
contract PeerLoanCenter is IPeerLoanCenter, OwnableUpgradeable {
    // NFT address + NFT ID to loan ID mapping
    mapping(address => mapping(uint256 => uint256)) private _nftToLoanId;

    // Loan ID to loan info mapping
    mapping(uint256 => DataTypes.PeerLoanData) private _loans;

    uint256 private _loansCount;
    IAddressProvider private immutable _addressProvider;

    // Mapping from address to active loans
    mapping(address => uint256[]) private _activeLoans;

    modifier onlyMarket() {
        _requireOnlyMarket();
        _;
    }

    modifier loanExists(uint256 loanId) {
        _requireLoanExists(loanId);
        _;
    }

    modifier loanNotExpired(uint256 loanId) {
        _requireLoanNotExpired(loanId);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IAddressProvider addressProvider) {
        _addressProvider = addressProvider;
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param defaultLiquidationThreshold The default liquidation threshold
    /// @param defaultMaxLTV The default max LTV
    function initialize(
        uint256 defaultLiquidationThreshold,
        uint256 defaultMaxLTV
    ) external initializer {
        __Ownable_init();
    }

    function createLoan() external {}

    /// @notice Repay a loan by setting its state to Repaid
    /// @dev Only the market contract can call this function
    /// @param loanId The ID of the loan to be repaid
    function repayLoan(uint256 loanId) external override onlyMarket {
        // Update loan state
        _loans[loanId].state = DataTypes.LoanState.Repaid;

        // Close the loan
        _closeLoan(loanId);
    }

    function _requireOnlyMarket() internal view {
        require(
            msg.sender == _addressProvider.getLendingMarket(),
            "LC:NOT_MARKET"
        );
    }

    function _requireLoanExists(uint256 loanId) internal view {
        require(
            _loans[loanId].state != DataTypes.LoanState.None,
            "LC:UNEXISTENT_LOAN"
        );
    }

    function _requireLoanNotExpired(uint256 loanId) internal view {
        require(
            _loans[loanId].state == DataTypes.LoanState.Auctioned,
            "LC:NOT_AUCTIONED"
        );
    }
}
