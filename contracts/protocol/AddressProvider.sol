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
    address private _tradingVault;

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
}
