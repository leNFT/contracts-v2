//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Trustus} from "../protocol/Trustus/Trustus.sol";

interface IPeerLendingMarket {
    event Borrow721(
        address indexed user,
        address indexed asset,
        address indexed nftAddress,
        uint256[] nftTokenIds,
        uint256 liquidityId,
        uint256 amount
    );

    event Borrow1155(
        address indexed user,
        address indexed asset,
        address indexed tokenAddress,
        uint256[] tokenIds,
        uint256[] tokenAmounts,
        uint256 liquidityId,
        uint256 amount
    );
}
