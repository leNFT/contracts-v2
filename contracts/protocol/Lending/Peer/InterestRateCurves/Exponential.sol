//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {IInterestRateCurve} from "../../../../interfaces/IInterestRateCurve.sol";
import {PercentageMath} from "../../../../libraries/utils/PercentageMath.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import "hardhat/console.sol";

/// @title Exponential Price Curve Contract
/// @author leNFT
/// @notice This contract implements an exponential price curve
/// @dev Calculates the price after buying or selling tokens using the exponential price curve
contract ExponentialInterestRateCurve is IInterestRateCurve, ERC165 {
    uint256 private constant PRECISION = 1e18;

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IPricingCurve).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
