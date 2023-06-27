// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAddressProvider} from "../../../interfaces/IAddressProvider.sol";
import {ISwapPool} from "../../../interfaces/ISwapPool.sol";
import {ISwapPoolFactory} from "../../../interfaces/ISwapPoolFactory.sol";
import {SwapPool721} from "../Pools/SwapPool721.sol";
import {ISwapRouter} from "../../../interfaces/ISwapRouter.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC165CheckerUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title SwapPoolFactory Contract
/// @author leNFT
/// @notice This contract is responsible for creating new swap pools
/// @dev Swap pools are created associated with a collection
contract SwapPool721Factory is
    ISwapPoolFactory,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    IAddressProvider private _addressProvider;

    // collection => pool
    mapping(address => address) private _pools;

    // mapping of valid pools
    mapping(address => bool) private _isSwapPool;

    // protocol fee percentage charged on swap fees
    uint256 private _protocolFeePercentage;

    using ERC165CheckerUpgradeable for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param addressProvider Address of the addressProvider contract
    /// @param protocolFeePercentage Protocol fee percentage charged on lp trade fees
    function initialize(
        IAddressProvider addressProvider,
        uint256 protocolFeePercentage
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        _addressProvider = addressProvider;
        _protocolFeePercentage = protocolFeePercentage;
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

    /// @notice Returns the address of the swap pool for a certain collection and token
    /// @param nft The NFT collection address
    /// @return The address of the swap pool for the given NFT collection and token
    function getSwapPool(address nft) external view returns (address) {
        return _pools[nft];
    }

    /// @notice Sets the address of the swap pool for a certain collection and token
    /// @dev Meant to be used by owner if there's a need to update or delete a pool
    /// @param nft The NFT collection address
    /// @param pool The address of the swap pool for the given NFT collection and token
    function setSwapPool(address nft, address pool) external onlyOwner {
        // Make sure the pool supports the interface or is the zero address
        require(
            pool.supportsInterface(type(ISwapPool).interfaceId) ||
                pool == address(0),
            "TPF:STP:NOT_POOL"
        );

        // If not zero address, make sure the pool is for the correct nft
        if (pool != address(0)) {
            require(ISwapPool(pool).getNFT() == nft, "TPF:STP:INVALID_POOL");
        }

        _setSwapPool(nft, pool);
    }

    function _setSwapPool(address nft, address pool) internal {
        _pools[nft] = pool;

        emit SetSwapPool(pool, nft);
    }

    /// @notice Returns whether a pool is valid or not
    /// @param pool The address of the pool to check
    /// @return Whether the pool is valid or not
    function isSwapPool(address pool) external view returns (bool) {
        return _isSwapPool[pool];
    }

    /// @notice Creates a swap pool for a certain collection and token
    /// @param nft The NFT collection address
    function createSwapPool(address nft) external nonReentrant {
        require(_pools[nft] == address(0), "TPF:CTP:POOL_ALREADY_EXISTS");
        require(
            nft.supportsInterface(type(IERC721MetadataUpgradeable).interfaceId),
            "TPF:CTP:NFT_NOT_ERC721"
        );

        ISwapPool newSwapPool = new SwapPool(
            _addressProvider,
            owner(),
            nft,
            string.concat(
                "leNFT Swap Pool ",
                IERC721MetadataUpgradeable(nft).symbol()
            ),
            string.concat("leS", IERC721MetadataUpgradeable(nft).symbol())
        );

        _setSwapPool(nft, address(newSwapPool));
        _isSwapPool[address(newSwapPool)] = true;

        emit CreateSwapPool(address(newSwapPool), nft);
    }
}
