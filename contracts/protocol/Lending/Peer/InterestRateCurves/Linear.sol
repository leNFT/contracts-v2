//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {IInterestRateCurve} from "../../../../interfaces/IInterestRateCurve.sol";
import {PercentageMath} from "../../../../libraries/utils/PercentageMath.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import "hardhat/console.sol";

/// @title Linear Price Curve Contract
/// @author leNFT
/// @notice This contract implements an exponential price curve
/// @dev Calculates the price after buying or selling tokens using the exponential price curve
contract LinearInterestRateCurve is IInterestRateCurve, ERC165 {
    uint256 private constant PRECISION = 1e18;

    function getNextInterestRate(
        uint256 loanAmount,
        uint256 baseInterestRate,
        uint256 delta,
        uint256 loanCount,
        uint256 resetPeriod,
        uint256 lastLoanTimestamp
    )
        external
        pure
        override
        returns (uint256 nextInterestRate, uint256 loanInterestRate)
    {
        return (0, 0);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IInterestRateCurve).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
