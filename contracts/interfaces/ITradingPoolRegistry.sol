//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

interface ITradingPoolRegistry {
    event SetTradingPool(
        address indexed pool,
        address indexed nft,
        address indexed token
    );

    event RegisterTradingPool(
        address indexed pool,
        address indexed nft,
        address indexed token
    );

    function registerTradingPool(
        address nft,
        address token,
        address pool
    ) external;

    function getProtocolFeePercentage() external view returns (uint256);

    function getTVLSafeguard() external view returns (uint256);

    function isTradingPool(address pool) external view returns (bool);

    function isPriceCurve(address priceCurve) external view returns (bool);
}
