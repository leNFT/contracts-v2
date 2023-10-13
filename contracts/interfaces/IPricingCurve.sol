//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.21;

interface IPricingCurve {
    error InvalidPrice();
    error InvalidDelta();
    error InvalidFeeDeltaRatio();

    function priceAfterBuy(
        uint256 price,
        uint256 delta,
        uint256 fee
    ) external view returns (uint256);

    function priceAfterMultipleBuys(
        uint256 amount,
        uint256 price,
        uint256 delta
    ) external view returns (uint256);

    function buyPriceSum(
        uint256 amount,
        uint256 spotPrice,
        uint256 delta
    ) external view returns (uint256);

    function priceAfterSell(
        uint256 price,
        uint256 delta,
        uint256 fee
    ) external view returns (uint256);

    function priceAfterMultipleSells(
        uint256 amount,
        uint256 price,
        uint256 delta,
        uint256 fee
    ) external view returns (uint256);

    function sellPriceSum(
        uint256 amount,
        uint256 spotPrice,
        uint256 delta
    ) external view returns (uint256);

    function validateLiquidityParameters(
        uint256 spotPrice,
        uint256 delta,
        uint256 fee,
        uint256 protocolFeePercentage
    ) external view;
}
