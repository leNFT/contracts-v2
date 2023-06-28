//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

interface IInterestRateCurve {
    function getNextInterestRate(
        uint256 loanAmount,
        uint256 baseInterestRate,
        uint256 delta,
        uint256 loanCount,
        uint256 resetPeriod,
        uint256 lastLoanTimestamp
    ) external returns (uint256 nextInterestRate, uint256 loanInterestRate);
}
