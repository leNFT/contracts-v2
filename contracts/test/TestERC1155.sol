// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestERC1155 is ERC1155 {
    string private _name;
    string private _symbol;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) ERC1155(baseURI_) {
        _name = name_;
        _symbol = symbol_;
    }

    function mint(address owner, uint256 tokenId, uint256 amount) external {
        super._mint(owner, tokenId, amount, "");
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }
}
