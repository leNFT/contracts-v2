//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAddressProvider} from "../interfaces/IAddressProvider.sol";

/// @title AddressProvider
/// @author leNFT
/// @notice This contract is responsible for storing and providing all the protocol contract addresses
// solhint-disable-next-line max-states-count
contract AddressProvider is OwnableUpgradeable, IAddressProvider {
    address private _liquidityPair721Metadata;
    address private _liquidityPair1155Metadata;
    address private _swapLiquidityMetadata;
    address private _votingEscrow;
    address private _tradingVault;
    address private _feeDistributor;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init();
    }

    function setTradingVault(address tradingVault) external override onlyOwner {
        _tradingVault = tradingVault;
    }

    function getTradingVault() external view returns (address) {
        return _tradingVault;
    }

    function setLiquidityPair721Metadata(
        address liquidityPair721Metadata
    ) external override {
        _liquidityPair721Metadata = liquidityPair721Metadata;
    }

    function getLiquidityPair721Metadata() external view returns (address) {
        return _liquidityPair721Metadata;
    }

    function setLiquidityPair1155Metadata(
        address liquidityPair1155Metadata
    ) external override {
        _liquidityPair1155Metadata = liquidityPair1155Metadata;
    }

    function getLiquidityPair1155Metadata() external view returns (address) {
        return _liquidityPair1155Metadata;
    }

    function setSwapLiquidityMetadata(
        address swapLiquidityMetadata
    ) external override {
        _swapLiquidityMetadata = swapLiquidityMetadata;
    }

    function getSwapLiquidityMetadata() external view returns (address) {
        return _swapLiquidityMetadata;
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
