//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {DataTypes} from "../libraries/types/DataTypes.sol";

interface ITradingPool {
    function getLpCount() external view returns (uint256);

    function getToken() external view returns (address);

    function getNFT() external view returns (address);

    function getNFTType() external view returns (DataTypes.TokenStandard);
}
