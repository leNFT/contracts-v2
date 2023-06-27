//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Trustus} from "../protocol/Trustus/Trustus.sol";

interface IPoolLendingMarket {
    event Borrow721(
        address indexed user,
        address indexed asset,
        address indexed nftAddress,
        uint256[] nftTokenIds,
        uint256 amount
    );

    event Borrow1155(
        address indexed user,
        address indexed asset,
        address indexed tokenAddress,
        uint256[] tokenIds,
        uint256[] tokenAmounts,
        uint256 amount
    );

    event Repay(address indexed user, uint256 indexed loanId);

    event CreateLiquidationAuction(
        address indexed user,
        uint256 indexed loanId,
        uint256 bid
    );
    event BidLiquidationAuction(
        address indexed user,
        uint256 indexed loanId,
        uint256 bid
    );

    event ClaimLiquidation(address indexed user, uint256 indexed loanId);

    event CreateLendingPool(
        address indexed lendingPool,
        address indexed colletction,
        address indexed asset
    );

    event SetLendingPool(
        address indexed collection,
        address indexed asset,
        address indexed lendingPool
    );

    function borrow721(
        address onBehalfOf,
        address asset,
        uint256 amount,
        address nftAddress,
        uint256[] memory nftTokenIds,
        uint256 genesisNFTId,
        bytes32 request,
        Trustus.TrustusPacket calldata packet
    ) external;

    function borrow1155(
        address onBehalfOf,
        address asset,
        uint256 amount,
        address tokenAddress,
        uint256[] memory tokenIds,
        uint256[] memory tokenAmounts,
        uint256 genesisNFTId,
        bytes32 request,
        Trustus.TrustusPacket calldata packet
    ) external;

    function repay(uint256 loanId, uint256 amount) external;

    function createLiquidationAuction(
        address onBehalfOf,
        uint256 loanId,
        uint256 bid,
        bytes32 request,
        Trustus.TrustusPacket calldata packet
    ) external;

    function bidLiquidationAuction(
        address onBehalfOf,
        uint256 loanId,
        uint256 bid
    ) external;

    function claimLiquidation(uint256 loanId) external;

    function getLendingPool(
        address collection,
        address asset
    ) external view returns (address);

    function getTVLSafeguard() external view returns (uint256);
}
