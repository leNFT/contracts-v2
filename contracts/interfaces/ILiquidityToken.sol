//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {DataTypes} from "../libraries/types/DataTypes.sol";

interface ILiquidityToken {
    function mint(address to, uint256 tokenId) external;

    function burn(uint256 tokenId) external;
}
