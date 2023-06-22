// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {IAddressProvider} from "../../../interfaces/IAddressProvider.sol";
import {ITradingPoolRegistry} from "../../../interfaces/ITradingPoolRegistry.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {TradingPool1155} from "../Pools/TradingPool1155.sol";
import {ITradingPool1155} from "../../../interfaces/ITradingPool1155.sol";
import {ITradingPoolFactory} from "../../../interfaces/ITradingPoolFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title TradingPool1155Factory Contract
/// @author leNFT
/// @notice This contract is responsible for keeping information about the trading pools
/// @dev Trading pools are ERC721 AND ERC1155
contract TradingPool1155Factory is
    ERC165,
    ITradingPoolFactory,
    ReentrancyGuard,
    Ownable
{
    IAddressProvider private _addressProvider;

    using ERC165Checker for address;

    constructor(IAddressProvider addressProvider) {
        _addressProvider = addressProvider;
    }

    /// @notice Creates a trading pool for a certain collection and token
    /// @param nft The NFT collection address
    /// @param token The token address to trade against
    function create(address nft, address token) external nonReentrant {
        require(
            nft.supportsInterface(type(IERC1155).interfaceId),
            "TPF:CTP:NOT_ERC1155"
        );

        string memory tokenSymbol = IERC20Metadata(token).symbol();
        string memory nftSymbol;
        // Make an external call to get the ERC1155 token's symbol
        (bool success, bytes memory data) = nft.staticcall(
            abi.encodeWithSignature("symbol()")
        );
        if (!success) {
            nftSymbol = "N/A";
        } else {
            // Decode the response
            nftSymbol = abi.decode(data, (string));
        }

        ITradingPool1155 newTradingPool = new TradingPool1155(
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
