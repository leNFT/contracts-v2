//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

interface IAddressProvider {
    function setLiquidityPair721Metadata(
        address liquidityPairMetadata
    ) external;

    function getLiquidityPair721Metadata() external view returns (address);

    function setTradingVault(address tradingVault) external;

    function getTradingVault() external view returns (address);
}
