//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.21;

interface IAddressProvider {
    function setLiquidity721Metadata(address liquidityMetadata) external;

    function getLiquidity721Metadata() external view returns (address);

    function setLiquidity1155Metadata(address liquidityMetadata) external;

    function getLiquidity1155Metadata() external view returns (address);

    function setVault(address vault) external;

    function getVault() external view returns (address);

    function setVotingEscrow(address votingEscrow) external;

    function getVotingEscrow() external view returns (address);

    function setFeeDistributor(address feeDistributor) external;

    function getFeeDistributor() external view returns (address);
}
