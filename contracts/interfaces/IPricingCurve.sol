//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.21;

interface IPricingCurve {
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

    function validateLpParameters(
        uint256 spotPrice,
        uint256 delta,
        uint256 fee
    ) external view;
}
