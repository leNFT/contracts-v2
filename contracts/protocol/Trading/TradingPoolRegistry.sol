// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";
import {ITradingPool721} from "../../interfaces/ITradingPool721.sol";
import {ITradingPool1155} from "../../interfaces/ITradingPool1155.sol";
import {ITradingPool} from "../../interfaces/ITradingPool.sol";
import {ITradingPoolFactory} from "../../interfaces/ITradingPoolFactory.sol";
import {ITradingPoolRegistry} from "../../interfaces/ITradingPoolRegistry.sol";
import {ISwapRouter} from "../../interfaces/ISwapRouter.sol";
import {IPricingCurve} from "../../interfaces/IPricingCurve.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC165CheckerUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title TradingPoolRegistry Contract
/// @author leNFT
/// @notice This contract is responsible for keeping information about the trading pools
/// @dev Trading pools are ERC721 AND ERC1155
contract TradingPoolRegistry is
    ITradingPoolRegistry,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    IAddressProvider private immutable _addressProvider;

    // collection + asset = pool
    mapping(address => mapping(address => address)) private _pools;

    // mapping of valid pools
    mapping(address => bool) private _isTradingPool;

    // mapping of valid price curves
    mapping(address => bool) private _isPriceCurve;

    // mapping of valid factories
    mapping(address => bool) private _isFactory;

    uint256 private _protocolFeePercentage;
    uint256 private _tvlSafeguard;

    using ERC165CheckerUpgradeable for address;

    modifier onlyFactory() {
        _requireOnlyFactory();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IAddressProvider addressProvider) {
        _addressProvider = addressProvider;
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param protocolFeePercentage Protocol fee percentage charged on lp trade fees
    /// @param tvlSafeguard default TVL safeguard for pools
    function initialize(
        uint256 protocolFeePercentage,
        uint256 tvlSafeguard
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        _protocolFeePercentage = protocolFeePercentage;
        _tvlSafeguard = tvlSafeguard;
    }

    function isPriceCurve(
        address priceCurve
    ) external view override returns (bool) {
        return _isPriceCurve[priceCurve];
    }

    function setPriceCurve(address priceCurve, bool valid) external onlyOwner {
        // Make sure the price curve is valid
        require(
            priceCurve.supportsInterface(type(IPricingCurve).interfaceId),
            "TPF:SPC:NOT_PC"
        );
        _isPriceCurve[priceCurve] = valid;
    }

    /// @notice Set the protocol fee percentage
    /// @param newProtocolFeePercentage New protocol fee percentage
    function setProtocolFeePercentage(
        uint256 newProtocolFeePercentage
    ) external onlyOwner {
        _protocolFeePercentage = newProtocolFeePercentage;
    }

    /// @notice Get the current protocol fee percentage
    /// @return Current protocol fee percentage
    function getProtocolFeePercentage() external view returns (uint256) {
        return _protocolFeePercentage;
    }

    /// @notice Get the current TVL safeguard
    /// @return Current TVL safeguard
    function getTVLSafeguard() external view returns (uint256) {
        return _tvlSafeguard;
    }

    /// @notice Sets a new value for the TVL safeguard
    /// @param newTVLSafeguard The new TVL safeguard value to be set
    function setTVLSafeguard(uint256 newTVLSafeguard) external onlyOwner {
        _tvlSafeguard = newTVLSafeguard;
    }

    /// @notice Returns the address of the trading pool for a certain collection and token
    /// @param nft The NFT collection address
    /// @param token The token address
    /// @return The address of the trading pool for the given NFT collection and token
    function getTradingPool(
        address nft,
        address token
    ) external view returns (address) {
        return _pools[nft][token];
    }

    /// @notice Sets the address of the trading pool for a certain collection and token
    /// @dev Meant to be used by owner if there's a need to update or delete a pool
    /// @dev Pools must've been created by a factory
    /// @param nft The NFT collection address
    /// @param token The token address
    /// @param pool The address of the trading pool for the given NFT collection and token
    function setTradingPool(
        address nft,
        address token,
        address pool
    ) external onlyOwner {
        // Make sure the pool supports the interface or is the zero address
        require(
            pool.supportsInterface(type(ITradingPool).interfaceId) ||
                pool == address(0),
            "TPF:STP:NOT_POOL"
        );

        // If not zero address, make sure the pool is for the correct nft and token
        if (pool != address(0)) {
            require(
                ITradingPool(pool).getNFT() == nft &&
                    ITradingPool(pool).getToken() == token,
                "TPF:STP:INVALID_POOL"
            );
            require(_isTradingPool[pool], "TPF:STP:UNREGISTERED_POOL");
        }

        _setTradingPool(nft, token, pool);
    }

    function _setTradingPool(
        address nft,
        address token,
        address pool
    ) internal {
        _pools[nft][token] = pool;

        emit SetTradingPool(pool, nft, token);
    }

    /// @notice Returns whether a pool is valid or not
    /// @param pool The address of the pool to check
    /// @return Whether the pool is valid or not
    function isTradingPool(address pool) external view returns (bool) {
        return _isTradingPool[pool];
    }

    /// @notice Creates a trading pool for a certain collection and token
    /// @param nft The NFT collection address
    /// @param token The token address to trade against
    function registerTradingPool(
        address nft,
        address token,
        address pool
    ) external nonReentrant onlyFactory {
        require(!_isTradingPool[pool], "TPF:RTP:POOL_ALREADY_REGISTERED");
        require(
            _pools[nft][token] == address(0),
            "TPF:CTP:POOL_ALREADY_EXISTS"
        );

        _setTradingPool(nft, token, pool);
        _isTradingPool[pool] = true;

        // Approve trading pool in swap router
        ISwapRouter(_addressProvider.getSwapRouter()).approveTradingPool(
            token,
            pool
        );

        emit RegisterTradingPool(pool, nft, token);
    }

    function addFactory(address factory) external onlyOwner {
        require(
            factory.supportsInterface(type(ITradingPoolFactory).interfaceId),
            "TPR:AF:NOT_FACTORY"
        );
        require(!_isFactory[factory], "TPR:AF:ALREADY_FACTORY");
        _isFactory[factory] = true;
    }

    function removeFactory(address factory) external onlyOwner {
        require(_isFactory[factory], "TPR:RF:NOT_FACTORY");
        delete _isFactory[factory];
    }

    function _requireOnlyFactory() internal view {
        require(_isFactory[msg.sender], "TPR:NOT_FACTORY");
    }
}
