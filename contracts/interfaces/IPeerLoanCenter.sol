//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {DataTypes} from "../libraries/types/DataTypes.sol";

interface IPeerLoanCenter {
    function getLoan(
        uint256 loanId
    ) external view returns (DataTypes.PeerLoanData memory);
}
