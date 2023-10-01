// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {DataTypes} from "../../../libraries/types/DataTypes.sol";
import {IAddressProvider} from "../../../interfaces/IAddressProvider.sol";
import {IVault} from "../../../interfaces/IVault.sol";
import {ILiquidityMetadata} from "../../../interfaces/ILiquidityMetadata.sol";

/// @title Liquidity Metadata
/// @author leNFT. Based on out.eth (@outdoteth) work.
/// @notice This contract is used to generate a liquidity pair's metadata.
/// @dev Fills the metadata with dynamic data from the liquidity pair.
contract Liquidity721Metadata is ILiquidityMetadata {
    IAddressProvider private immutable _addressProvider;

    modifier liquidityExists(uint256 liquidityId) {
        _requireLiquidityExists(liquidityId);
        _;
    }

    constructor(IAddressProvider addressProvider) {
        _addressProvider = addressProvider;
    }

    /// @notice Returns the metadata for a liquidity pair
    /// @param liquidityId The address of the trading pool of the liquidity pair.
    /// @return The encoded metadata for the liquidity pair.
    function tokenURI(
        uint256 liquidityId
    )
        public
        view
        override
        liquidityExists(liquidityId)
        returns (string memory)
    {
        bytes memory metadata;
        DataTypes.Liquidity721 memory liquidity = IVault(
            _addressProvider.getVault()
        ).getLiquidity721(liquidityId);

        {
            // scope to avoid stack too deep errors
            metadata = abi.encodePacked(
                "{",
                '"name": "Liquidity Pair ',
                IERC721Metadata(liquidity.nft).symbol(),
                IERC20Metadata(liquidity.token).symbol(),
                " #",
                Strings.toString(liquidityId),
                '",'
            );
        }

        {
            metadata = abi.encodePacked(
                metadata,
                '"description": "leNFT trading liquidity pair.",',
                '"image": ',
                '"data:image/svg+xml;base64,',
                Base64.encode(svg(liquidityId)),
                '",',
                '"attributes": [',
                attributes(liquidityId),
                "]",
                "}"
            );
        }

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(metadata)
                )
            );
    }

    /// @notice Returns the attributes for a liquidity pair encoded as json.
    /// @param liquidityId The address of the trading pool of the liquidity pair.
    /// @return The encoded attributes for the liquidity pair.
    function attributes(
        uint256 liquidityId
    ) public view liquidityExists(liquidityId) returns (string memory) {
        DataTypes.Liquidity721 memory liquidity = IVault(
            _addressProvider.getVault()
        ).getLiquidity721(liquidityId);
        bytes memory _attributes;

        {
            // scope to avoid stack too deep errors
            _attributes = abi.encodePacked(
                _trait(
                    "Pool address",
                    Strings.toHexString(
                        IVault(_addressProvider.getVault()).getLiquidityToken(
                            liquidityId
                        )
                    )
                ),
                ",",
                _trait("Token", Strings.toHexString(liquidity.token)),
                ",",
                _trait("NFT", Strings.toHexString(liquidity.nft)),
                ",",
                _trait("Price", Strings.toString(liquidity.spotPrice)),
                ",",
                _trait(
                    "Token balance",
                    Strings.toString(liquidity.tokenAmount)
                ),
                ","
            );
        }

        {
            _attributes = abi.encodePacked(
                _attributes,
                _trait(
                    "NFT balance",
                    Strings.toString(liquidity.nftIds.length)
                ),
                ",",
                _trait("Curve", Strings.toHexString(liquidity.curve)),
                ",",
                _trait("Delta", Strings.toString(liquidity.delta)),
                ",",
                _trait("Fee", Strings.toString(liquidity.fee)),
                ",",
                _trait(
                    "Type",
                    Strings.toString(uint256(liquidity.liquidityType))
                )
            );
        }

        return string(_attributes);
    }

    /// @notice Returns an svg image for a liquidity pair.
    /// @param liquidityId The address of the trading pool of the liquidity pair.
    /// @return _svg The svg image for the liquidity pair.
    function svg(
        uint256 liquidityId
    ) public view liquidityExists(liquidityId) returns (bytes memory _svg) {
        DataTypes.Liquidity721 memory liquidity = IVault(
            _addressProvider.getVault()
        ).getLiquidity721(liquidityId);
        IERC721Metadata nft = IERC721Metadata(liquidity.nft);
        IERC20Metadata token = IERC20Metadata(liquidity.token);

        // break up svg building into multiple scopes to avoid stack too deep errors
        {
            _svg = abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" style="width:100%;background:#eaeaea;fill:black;font-family:monospace">',
                '<text x="50%" y="24px" font-size="12" text-anchor="middle">',
                "leNFT Trading Pair ",
                nft.symbol(),
                token.symbol(),
                " #",
                Strings.toString(liquidityId),
                "</text>",
                '<text x="24px" y="72px" font-size="8">'
            );
        }

        {
            _svg = abi.encodePacked(
                _svg,
                "Trading pool: ",
                Strings.toHexString(
                    IVault(_addressProvider.getVault()).getLiquidityToken(
                        liquidityId
                    )
                ),
                "</text>",
                '<text x="24px" y="90px" font-size="8">',
                "NFT: ",
                nft.name(),
                "</text>",
                '<text x="24px" y="108px" font-size="8">',
                "Token: ",
                token.name(),
                "</text>"
            );
        }

        {
            _svg = abi.encodePacked(
                _svg,
                '<text x="24px" y="126px" font-size="8">',
                "Price: ",
                Strings.toString(liquidity.spotPrice),
                "</text>",
                '<text x="24px" y="144px" font-size="8">',
                "NFT Balance: ",
                Strings.toString(liquidity.nftIds.length),
                "</text>",
                '<text x="24px" y="162px" font-size="8">',
                "Token Balance: ",
                Strings.toString(liquidity.tokenAmount),
                "</text>"
            );
        }

        {
            _svg = abi.encodePacked(
                _svg,
                '<text x="24px" y="180px" font-size="8">',
                "Fee: ",
                Strings.toString(liquidity.fee),
                "</text>",
                '<text x="24px" y="198px" font-size="8">',
                "Curve: ",
                Strings.toHexString(liquidity.curve),
                "</text>",
                '<text x="24px" y="216px" font-size="8">',
                "Delta: ",
                Strings.toString(liquidity.delta),
                "</text>",
                "</svg>"
            );
        }
    }

    /// @notice Returns a trait encoded as json.
    /// @param traitType The trait type.
    /// @param value The trait value.
    /// @return The encoded trait.
    function _trait(
        string memory traitType,
        string memory value
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{ "trait_type": "',
                    traitType,
                    '",',
                    '"value": "',
                    value,
                    '" }'
                )
            );
    }

    function _requireLiquidityExists(uint256 liquidityId) internal view {
        require(
            IERC721(
                IVault(_addressProvider.getVault()).getLiquidityToken(
                    liquidityId
                )
            ).ownerOf(liquidityId) != address(0),
            "LIQUIDITY_DOES_NOT_EXIST"
        );
    }
}
