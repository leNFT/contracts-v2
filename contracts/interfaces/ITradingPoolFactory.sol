//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

interface ITradingPoolFactory {
    event Create(
        address indexed pool,
        address indexed nft,
        address indexed token
    );

    function create(address nft, address token) external;
}
