//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

interface ISwapPoolFactory {
    event CreateSwapPool(address indexed pool, address indexed nft);
    event SetSwapPool(address indexed pool, address indexed nft);

    function getProtocolFeePercentage() external view returns (uint256);

    function isSwapPool(address pool) external view returns (bool);
}
