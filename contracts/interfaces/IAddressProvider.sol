//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

interface IAddressProvider {
    function setLiquidityPair721Metadata(
        address liquidityPairMetadata
    ) external;

    function getLiquidityPair721Metadata() external view returns (address);

    function setLiquidityPair1155Metadata(
        address liquidityPairMetadata
    ) external;

    function getLiquidityPair1155Metadata() external view returns (address);

    function setSwapLiquidityMetadata(address swapLiquidityMetadata) external;

    function getSwapLiquidityMetadata() external view returns (address);

    function setVault(address vault) external;

    function getVault() external view returns (address);

    function setVotingEscrow(address votingEscrow) external;

    function getVotingEscrow() external view returns (address);

    function setFeeDistributor(address feeDistributor) external;

    function getFeeDistributor() external view returns (address);
}
