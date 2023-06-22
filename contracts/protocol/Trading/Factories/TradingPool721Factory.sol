// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {IAddressProvider} from "../../../interfaces/IAddressProvider.sol";
import {ITradingPoolRegistry} from "../../../interfaces/ITradingPoolRegistry.sol";
import {ITradingPool721} from "../../../interfaces/ITradingPool721.sol";
import {TradingPool721} from "../Pools/TradingPool721.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITradingPoolFactory} from "../../../interfaces/ITradingPoolFactory.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title TradingPool721Factory Contract
/// @author leNFT
/// @notice This contract is responsible for keeping information about the trading pools
/// @dev Trading pools are ERC721 AND ERC1155
contract TradingPool721Factory is
    ERC165,
    ITradingPoolFactory,
    ReentrancyGuard,
    Ownable
{
    IAddressProvider private _addressProvider;

    using ERC165Checker for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IAddressProvider addressProvider) {
        _addressProvider = addressProvider;
    }

    /// @notice Creates a trading pool for a certain collection and token
    /// @param nft The NFT collection address
    /// @param token The token address to trade against
    function create(address nft, address token) external nonReentrant {
        require(
            nft.supportsInterface(type(IERC721Metadata).interfaceId),
            "TPF:CTP:NOT_ERC721"
        );

        string memory tokenSymbol = IERC20Metadata(token).symbol();
        string memory nftSymbol = IERC721Metadata(nft).symbol();
        ITradingPool721 newTradingPool = new TradingPool721(
            _addressProvider,
            owner(),
            token,
            nft,
            string.concat("leNFT Trading Pool ", nftSymbol, " - ", tokenSymbol),
            string.concat("leT", nftSymbol, "-", tokenSymbol)
        );

        ITradingPoolRegistry(_addressProvider.getTradingPoolRegistry())
            .registerTradingPool(nft, token, address(newTradingPool));

        emit Create(address(newTradingPool), nft, token);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC165) returns (bool) {
        return
            interfaceId == type(ITradingPoolFactory).interfaceId ||
            ERC165.supportsInterface(interfaceId);
    }
}
