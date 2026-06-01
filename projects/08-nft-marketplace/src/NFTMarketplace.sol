// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTMarketplace is ReentrancyGuard {
    struct Listing {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    event NFTListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event NFTListingCancelled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    event NFTSold(
        address indexed buyer,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price
    );

    constructor() {}

    // List NFTs for sale
    function listNFT(
        address nftAddress_,
        uint256 tokenId_,
        uint256 price_
    ) external nonReentrant {
        require(price_ > 0, "Price must be greater than zero");
        address owner_ = IERC721(nftAddress_).ownerOf(tokenId_);
        require(owner_ == msg.sender, "Only the owner can list the NFT");

        listings[nftAddress_][tokenId_] = Listing({
            seller: msg.sender,
            nftAddress: nftAddress_,
            tokenId: tokenId_,
            price: price_
        });

        emit NFTListed(msg.sender, nftAddress_, tokenId_, price_);
    }

    // Cancel a listing
    function cancelListing(
        address nftAddress_,
        uint256 tokenId_
    ) external nonReentrant {
        Listing memory listing_ = listings[nftAddress_][tokenId_];
        require(
            listing_.seller == msg.sender,
            "Only the seller can cancel the listing"
        );
        delete listings[nftAddress_][tokenId_];

        emit NFTListingCancelled(msg.sender, nftAddress_, tokenId_);
    }

    // Buy a listed NFT
    function buyNFT(
        address nftAddress_,
        uint256 tokenId_
    ) external payable nonReentrant {
        Listing memory listing_ = listings[nftAddress_][tokenId_];
        require(listing_.price > 0, "NFT not listed for sale");
        require(msg.value == listing_.price, "Incorrect payment amount");

        delete listings[nftAddress_][tokenId_];

        IERC721(nftAddress_).safeTransferFrom(
            listing_.seller,
            msg.sender,
            tokenId_
        );

        (bool success, ) = listing_.seller.call{value: msg.value}("");
        require(success, "Failed to transfer funds");

        emit NFTSold(
            msg.sender,
            listing_.seller,
            nftAddress_,
            tokenId_,
            listing_.price
        );
    }
}
