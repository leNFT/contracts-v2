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
    function initialize() external initializer {
        __Ownable_init();
    }

    function createLoan(
        address onBehalfOf,
        address asset,
        uint256 amount,
        uint256 borrowRate,
        address tokenAddress,
        uint256[] tokenIds,
        uint256[] tokenAmounts,
        uint256 liquidityId
    ) external {}

    /// @notice Repay a loan by setting its state to Repaid
    /// @dev Only the market contract can call this function
    /// @param loanId The ID of the loan to be repaid
    function repayLoan(uint256 loanId) external override onlyMarket {
        // Update loan state
        _loans[loanId].state = DataTypes.LoanState.Repaid;
    }

    function liquidateLoan(uint256 loanId) external override onlyMarket {
        // Update loan state
        _loans[loanId].state = DataTypes.LoanState.Liquidated;
    }

    function updateLoanAmount(
        uint256 loanId,
        uint256 amount
    ) external onlyMarket {
        _loans[loanId].amount = amount;
    }

    /// @notice Get the debt owed on a loan
    /// @param loanId The ID of the loan
    /// @return The total amount of debt owed on the loan quoted in the same asset of the loan's lending pool
    function getLoanDebt(
        uint256 loanId
    ) external view override loanExists(loanId) returns (uint256) {
        return _getLoanDebt(loanId);
    }

    /// @notice Get the interest owed on a loan
    /// @param loanId The ID of the loan
    /// @return The amount of interest owed on the loan
    function getLoanInterest(
        uint256 loanId
    ) external view override loanExists(loanId) returns (uint256) {
        return _getLoanInterest(loanId, block.timestamp);
    }

    /// @notice GEts the loan interest for a given timestamp
    /// @param loanId The ID of the loan
    /// @param timestamp The timestamp to get the interest for
    /// @return The amount of interest owed on the loan
    function _getLoanInterest(
        uint256 loanId,
        uint256 timestamp
    ) internal view returns (uint256) {
        //Interest increases every 30 minutes
        uint256 incrementalTimestamp = (((timestamp - 1) / (30 * 60)) + 1) *
            (30 * 60);
        DataTypes.PeerLoanData memory loan = _loans[loanId];

        return
            (loan.amount *
                uint256(loan.borrowRate) *
                (incrementalTimestamp - uint256(loan.debtTimestamp))) /
            (PercentageMath.PERCENTAGE_FACTOR * 365 days);
    }

    /// @notice Internal function to get the debt owed on a loan
    /// @param loanId The ID of the loan
    /// @return The total amount of debt owed on the loan
    function _getLoanDebt(uint256 loanId) internal view returns (uint256) {
        return
            _getLoanInterest(loanId, block.timestamp) + _loans[loanId].amount;
    }

    function _requireOnlyMarket() internal view {
        require(
            msg.sender == _addressProvider.getPeerLendingMarket(),
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
