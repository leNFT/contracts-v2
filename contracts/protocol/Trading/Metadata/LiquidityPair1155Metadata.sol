// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {DataTypes} from "../../../libraries/types/DataTypes.sol";
import {IAddressProvider} from "../../../interfaces/IAddressProvider.sol";
import {IVault} from "../../../interfaces/IVault.sol";

/// @title LiquidityPair Metadata
/// @author leNFT. Based on out.eth (@outdoteth) work.
/// @notice This contract is used to generate a liquidity pair's metadata.
/// @dev Fills the metadata with dynamic data from the liquidity pair.
contract LiquidityPair1155Metadata {
    IAddressProvider private immutable _addressProvider;

    modifier lpExists(uint256 liquidityId) {
        _requireLpExists(liquidityId);
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
    ) public view lpExists(liquidityId) returns (string memory) {
        bytes memory metadata;
        string memory nftSymbol;
        DataTypes.LiquidityPair1155 memory lp = IVault(
            _addressProvider.getVault()
        ).getLP1155(liquidityId);

        // Make an external call to get the ERC1155 token's symbol
        (bool success, bytes memory data) = lp.nft.staticcall(
            abi.encodeWithSignature("symbol()")
        );
        if (!success) {
            nftSymbol = "N/A";
        } else {
            // Decode the response
            nftSymbol = abi.decode(data, (string));
        }

        {
            // scope to avoid stack too deep errors
            metadata = abi.encodePacked(
                "{",
                '"name": "Liquidity Pair ',
                nftSymbol,
                IERC20Metadata(lp.token).symbol(),
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
    ) public view lpExists(liquidityId) returns (string memory) {
        DataTypes.LiquidityPair1155 memory lp = IVault(
            _addressProvider.getVault()
        ).getLP1155(liquidityId);

        bytes memory _attributes;

        {
            // scope to avoid stack too deep errors
            _attributes = abi.encodePacked(
                trait(
                    "Pool address",
                    Strings.toHexString(
                        IVault(_addressProvider.getVault()).getLiquidityToken(
                            liquidityId
                        )
                    )
                ),
                ",",
                trait("Token", Strings.toHexString(lp.token)),
                ",",
                trait("NFT", Strings.toHexString(lp.nft)),
                ",",
                trait("Price", Strings.toString(lp.spotPrice)),
                ",",
                trait("Token balance", Strings.toString(lp.tokenAmount)),
                ","
            );
        }

        {
            _attributes = abi.encodePacked(
                _attributes,
                trait("NFT balance", Strings.toString(lp.nftAmount)),
                ",",
                trait("Curve", Strings.toHexString(lp.curve)),
                ",",
                trait("Delta", Strings.toString(lp.delta)),
                ",",
                trait("Fee", Strings.toString(lp.fee)),
                ",",
                trait("Type", Strings.toString(uint256(lp.lpType)))
            );
        }

        return string(_attributes);
    }

    /// @notice Returns an svg image for a liquidity pair.
    /// @param liquidityId The address of the trading pool of the liquidity pair.
    /// @return _svg The svg image for the liquidity pair.
    function svg(
        uint256 liquidityId
    ) public view lpExists(liquidityId) returns (bytes memory _svg) {
        DataTypes.LiquidityPair1155 memory lp = IVault(
            _addressProvider.getVault()
        ).getLP1155(liquidityId);
        string memory nftSymbol;
        string memory nftName;

        // TRy and get the nft symbol
        (bool symbolSuccess, bytes memory symbolData) = lp.nft.staticcall(
            abi.encodeWithSignature("symbol()")
        );
        if (!symbolSuccess) {
            nftSymbol = "N/A";
        } else {
            // Decode the response
            nftSymbol = abi.decode(symbolData, (string));
        }

        // Try to get the NFT name
        (bool nameSuccess, bytes memory nameData) = lp.nft.staticcall(
            abi.encodeWithSignature("name()")
        );
        if (!nameSuccess) {
            nftName = "Not Available";
        } else {
            // Decode the response
            nftName = abi.decode(nameData, (string));
        }

        IERC20Metadata token = IERC20Metadata(lp.token);

        // break up svg building into multiple scopes to avoid stack too deep errors
        {
            _svg = abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" style="width:100%;background:#eaeaea;fill:black;font-family:monospace">',
                '<text x="50%" y="24px" font-size="12" text-anchor="middle">',
                "leNFT Trading Pair ",
                nftSymbol,
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
                    address(
                        IVault(_addressProvider.getVault()).getLiquidityToken(
                            liquidityId
                        )
                    )
                ),
                "</text>",
                '<text x="24px" y="90px" font-size="8">',
                "NFT: ",
                nftName,
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
                Strings.toString(lp.spotPrice),
                "</text>",
                '<text x="24px" y="144px" font-size="8">',
                "NFT Balance: ",
                Strings.toString(lp.nftAmount),
                "</text>",
                '<text x="24px" y="162px" font-size="8">',
                "Token Balance: ",
                Strings.toString(lp.tokenAmount),
                "</text>"
            );
        }

        {
            _svg = abi.encodePacked(
                _svg,
                '<text x="24px" y="180px" font-size="8">',
                "Fee: ",
                Strings.toString(lp.fee),
                "</text>",
                '<text x="24px" y="198px" font-size="8">',
                "Curve: ",
                Strings.toHexString(lp.curve),
                "</text>",
                '<text x="24px" y="216px" font-size="8">',
                "Delta: ",
                Strings.toString(lp.delta),
                "</text>",
                "</svg>"
            );
        }
    }

    /// @notice Returns a trait encoded as json.
    /// @param traitType The trait type.
    /// @param value The trait value.
    /// @return The encoded trait.
    function trait(
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

    function _requireLpExists(uint256 liquidityId) internal view {
        require(
            IERC721(
                IVault(_addressProvider.getVault()).getLiquidityToken(
                    liquidityId
                )
            ).ownerOf(liquidityId) != address(0),
            "LP_DOES_NOT_EXIST"
        );
    }
}
