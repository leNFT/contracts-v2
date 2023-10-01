//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.21;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAddressProvider} from "../interfaces/IAddressProvider.sol";

/// @title AddressProvider
/// @author leNFT
/// @notice This contract is responsible for storing and providing all the protocol contract addresses
// solhint-disable-next-line max-states-count
contract AddressProvider is OwnableUpgradeable, IAddressProvider {
    address private _liquidity721Metadata;
    address private _liquidity1155Metadata;
    address private _votingEscrow;
    address private _vault;
    address private _feeDistributor;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init();
    }

    function setVault(address vault) external override onlyOwner {
        _vault = vault;
    }

    function getVault() external view returns (address) {
        return _vault;
    }

    function setLiquidity721Metadata(
        address liquidityPair721Metadata
    ) external override {
        _liquidity721Metadata = liquidityPair721Metadata;
    }

    function getLiquidity721Metadata() external view returns (address) {
        return _liquidity721Metadata;
    }

    function setLiquidity1155Metadata(
        address liquidity1155Metadata
    ) external override {
        _liquidity1155Metadata = liquidity1155Metadata;
    }

    function getLiquidity1155Metadata() external view returns (address) {
        return _liquidity1155Metadata;
    }

    function setVotingEscrow(address votingEscrow) external override onlyOwner {
        _votingEscrow = votingEscrow;
    }

    function getVotingEscrow() external view returns (address) {
        return _votingEscrow;
    }

    function setFeeDistributor(
        address feeDistributor
    ) external override onlyOwner {
        _feeDistributor = feeDistributor;
    }

    function getFeeDistributor() external view returns (address) {
        return _feeDistributor;
    }
}
