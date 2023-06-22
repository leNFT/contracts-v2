//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Trustus} from "../protocol/Trustus/Trustus.sol";

interface INFTOracle {
    function getTokens721ETHPrice(
        address collection,
        uint256[] memory tokenIds,
        bytes32 request,
        Trustus.TrustusPacket calldata packet
    ) external view returns (uint256);

    function getTokens1155ETHPrice(
        address collection,
        uint256[] memory tokenIds,
        uint256[] memory tokenAmounts,
        bytes32 request,
        Trustus.TrustusPacket calldata packet
    ) external view returns (uint256);
}
