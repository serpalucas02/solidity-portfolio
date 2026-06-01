// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract NFTCollection is ERC721 {
    using Strings for uint256;

    uint256 private currentTokenId;
    uint256 public totalSupply;
    string public baseUri;

    event NFTMinted(address userAddress_, uint256 tokenId_);
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        string memory baseURI_
    ) ERC721(name_, symbol_) {
        totalSupply = totalSupply_;
        baseUri = baseURI_;
    }

    function mint() external {
        require(currentTokenId < totalSupply, "All NFTs have been minted");

        _safeMint(msg.sender, currentTokenId);
        uint256 tokenId = currentTokenId;
        currentTokenId++;

        emit NFTMinted(msg.sender, tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string.concat(baseURI, tokenId.toString(), ".json")
                : "";
    }
}
