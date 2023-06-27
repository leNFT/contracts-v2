// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ISwapPool} from "../../../interfaces/ISwapPool.sol";
import {IAddressProvider} from "../../../interfaces/IAddressProvider.sol";
import {IFeeDistributor} from "../../../interfaces/IFeeDistributor.sol";
import {ISwapPoolFactory} from "../../../interfaces/ISwapPoolFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {DataTypes} from "../../../libraries/types/DataTypes.sol";
import {PercentageMath} from "../../../libraries/utils/PercentageMath.sol";
import {IPositionMetadata} from "../../../interfaces/IPositionMetadata.sol";

/// @title Swap Pool Contract
/// @author leNFT
/// @notice A contract that enables the creation of liquidity pools and the swapping of NFTs.
/// @dev This contract manages liquidity positions, each consisting of a certain number of NFTs, as well as the swapping of these pairs.
contract SwapPool721 is
    ERC165,
    ERC721Enumerable,
    ERC721Holder,
    ISwapPool,
    Ownable,
    ReentrancyGuard
{
    IAddressProvider private immutable _addressProvider;
    bool private _paused;
    address private immutable _nft;
    address private immutable _feeToken;
    mapping(uint256 => DataTypes.SwapLiquidity) private _swapLiquidity;
    mapping(uint256 => DataTypes.NftToSl) private _nftToSl;
    uint256 private _slCount;

    using SafeERC20 for IERC20;

    modifier poolNotPaused() {
        _requirePoolNotPaused();
        _;
    }

    modifier slExists(uint256 slId) {
        _requireSlExists(slId);
        _;
    }

    /// @notice Swap Pool constructor.
    /// @dev The constructor should only be called by the Swap Pool Factory contract.
    /// @param addressProvider The address provider contract.
    /// @param owner The owner of the Swap Pool contract.
    /// @param nft The address of the ERC721 contract.
    /// @param name The name of the ERC721 token.
    /// @param symbol The symbol of the ERC721 token.
    constructor(
        IAddressProvider addressProvider,
        address owner,
        address nft,
        address feeToken,
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        require(
            msg.sender == addressProvider.getSwapPoolFactory(),
            "SP:C:MUST_BE_FACTORY"
        );
        _addressProvider = addressProvider;
        _nft = nft;
        _feeToken = feeToken;
        _transferOwnership(owner);
    }

    /// @notice Returns the token URI for a specific liquidity position
    /// @param tokenId The ID of the liquidity pair.
    /// @return The token URI.
    function tokenURI(
        uint256 tokenId
    ) public view override slExists(tokenId) returns (string memory) {
        return
            ISwapLiquidityMetadata(_addressProvider.getSwapLiquidityMetadata())
                .tokenURI(address(this), tokenId);
    }

    /// @notice Gets the address of the ERC721 traded in the pool.
    /// @return The address of the ERC721 token.
    function getNFT() external view override returns (address) {
        return _nft;
    }

    /// @notice Gets the address of the fee token.
    /// @return The address of the fee token.
    function getFeeToken() external view override returns (address) {
        return _feeToken;
    }

    /// @notice Gets the swap liquidity with the specified ID.
    /// @param slId The ID of the swap liquidity.
    /// @return The swap liquidity.
    function getSL(
        uint256 slId
    ) external view slExists(slId) returns (DataTypes.SwapLiquidity memory) {
        return _swapLiquidity[slId];
    }

    /// @notice Gets the number of liquidity positions ever created in the swap pool.
    /// @return The number of liquidity positions.
    function getSlCount() external view returns (uint256) {
        return _slCount;
    }

    /// @notice Gets the ID of the liquidity position associated with the specified NFT.
    /// @param nftId The ID of the NFT.
    /// @return The ID of the liquidity position.
    function nftToSl(uint256 nftId) external view returns (uint256) {
        require(
            IERC721(_nft).ownerOf(nftId) == address(this),
            "SP:NTL:NOT_OWNED"
        );
        return _nftToSl[nftId].swapLiquidity;
    }

    /// @notice Adds liquidity to the swap pool.
    /// @dev Must add at least one NFT.
    /// @dev The caller must approve the Swap Pool contract to transfer the NFTs.
    /// @param receiver The recipient of the liquidity pool tokens.
    /// @param nftIds The IDs of the NFTs being deposited.
    /// @param fee The fee for the liquidity pair being created.
    function addLiquidity(
        address receiver,
        uint256[] calldata nftIds,
        uint256 fee
    ) external nonReentrant poolNotPaused {
        ISwapPoolFactory swapPoolFactory = ISwapPoolFactory(
            _addressProvider.getSwapPoolFactory()
        );

        // Make sure we deposit at least one NFT
        require(nftIds.length > 0, "SP:AL:EMPTY_NFTS");

        // Send user nfts to the pool
        for (uint i = 0; i < nftIds.length; i++) {
            IERC721(_nft).safeTransferFrom(
                msg.sender,
                address(this),
                nftIds[i]
            );
            _nftToSl[nftIds[i]] = DataTypes.NftToSl({
                swapLiquidity: _slCount,
                index: i
            });
        }

        // Save the user deposit info
        _swapLiquidity[_slCount] = DataTypes.SwapLiquidity({
            nftIds: nftIds,
            fee: fee,
            balance: 0
        });

        // Mint liquidity position NFT
        ERC721._safeMint(receiver, _slCount);

        emit AddLiquidity(receiver, _slCount, nftIds, fee);

        _slCount++;
    }

    /// @notice Removes liquidity pair, sending back deposited tokens and transferring the NFTs to the user
    /// @param slId The ID of the LP token to remove
    function removeLiquidity(uint256 slId) public nonReentrant {
        _removeLiquidity(slId);
    }

    /// @notice Removes liquidity pairs in batches by calling the removeLiquidity function for each LP token ID in the lpIds array
    /// @param lpIds The IDs of the LP tokens to remove liquidity from
    function removeLiquidityBatch(uint256[] calldata lpIds) external {
        for (uint i = 0; i < lpIds.length; i++) {
            _removeLiquidity(lpIds[i]);
        }
    }

    /// @notice Private function that removes a liquidity pair, sending back deposited tokens and transferring the NFTs to the user
    /// @param slId The ID of the LP token to remove
    function _removeLiquidity(uint256 slId) private {
        //Require the caller owns LP
        require(msg.sender == ERC721.ownerOf(slId), "SP:RL:NOT_OWNER");

        // Send pool nfts to the user
        uint256 nftIdsLength = _swapLiquidity[slId].nftIds.length;
        for (uint i = 0; i < nftIdsLength; i++) {
            IERC721(_nft).safeTransferFrom(
                address(this),
                msg.sender,
                _swapLiquidity[slId].nftIds[i]
            );
            delete _nftToSl[_swapLiquidity[slId].nftIds[i]];
        }

        // Send balance gathered from feess back to user
        IERC20(_feeToken).safeTransfer(
            msg.sender,
            _swapLiquidity[slId].balance
        );

        // delete the user deposit info
        delete _swapLiquidity[slId];

        // Burn liquidity position NFT
        ERC721._burn(slId);

        emit RemoveLiquidity(msg.sender, slId);
    }

    /// @notice Swaps NFTs for NFTs in the pool
    /// @param onBehalfOf The address to send the NFTs to
    /// @param sendNftIds The IDs of the NFTs to send to the swap
    /// @param receiveNftIds The IDs of the NFTs to receive from the swap
    /// @return fee The final fee paid for swap the NFTs
    function swap(
        address onBehalfOf,
        uint256[] calldata sendNftIds,
        uint256[] calldata receiveNftIds
    ) external nonReentrant poolNotPaused returns (uint256 fee) {
        // Make sure we swap at least one NFT
        require(sendNftIds.length > 0, "SP:S:NFTS_0");

        // Make sure we swap the same amount of NFTs
        require(
            sendNftIds.length == receiveNftIds.length,
            "SP:S:NFTS_LEN_MISMATCH"
        );

        DataTypes.NftToSl memory receivedNftToSl;

        for (uint i = 0; i < sendNftIds.length; i++) {
            // Check if the pool contract owns the NFT
            require(
                IERC721(_nft).ownerOf(receiveNftIds[i]) == address(this),
                "SP:S:NOT_OWNER"
            );
            receivedNftToSl = _nftToSl[receiveNftIds[i]];

            //  Add to the total fee
            fee += _swapLiquidity[receivedNftToSl.swapLiquidity].fee;

            // Update swap liquidity NFT tracker
            _swapLiquidity[receivedNftToSl.swapLiquidity].nftIds[
                receivedNftToSl.index
            ] = sendNftIds[i];

            // Replace nftToSl
            _nftToSl[sendNftIds[i]] = receivedNftToSl;
            delete _nftToSl[receiveNftIds[i]];

            // Send NFT to user
            IERC721(_nft).safeTransferFrom(
                address(this),
                onBehalfOf,
                receiveNftIds[i]
            );

            // Get NFT from user
            IERC721(_nft).safeTransferFrom(
                msg.sender,
                address(this),
                sendNftIds[i]
            );
        }

        // Get tokens from user
        IERC20(_feeToken).safeTransferFrom(msg.sender, address(this), fee);

        // Send protocol fee to protocol fee distributor
        IERC20(_feeToken).safeTransfer(
            _addressProvider.getFeeDistributor(),
            PercentageMath.percentMul(
                fee,
                ISwapPoolFactory(_addressProvider.getSwapPoolFactory())
                    .getProtocolFeePercentage()
            )
        );
        IFeeDistributor(_addressProvider.getFeeDistributor()).checkpoint(
            _feeToken
        );

        emit Swap(onBehalfOf, sendNftIds, receiveNftIds, fee);
    }

    /// @notice Allows the owner of the contract to pause or unpause the contract.
    /// @param paused A boolean indicating whether to pause or unpause the contract.
    function setPause(bool paused) external onlyOwner {
        _paused = paused;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Enumerable) {
        ERC721Enumerable._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC165, ERC721Enumerable) returns (bool) {
        return
            type(ISwapPool).interfaceId == interfaceId ||
            ERC721Enumerable.supportsInterface(interfaceId) ||
            ERC165.supportsInterface(interfaceId);
    }

    function _requirePoolNotPaused() internal view {
        require(!_paused, "SP:POOL_PAUSED");
    }

    function _requireSlExists(uint256 slIndex) internal view {
        require(_exists(slIndex), "SP:SL_NOT_FOUND");
    }
}
