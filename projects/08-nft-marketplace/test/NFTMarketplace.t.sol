// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../src/NFTMarketplace.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to_, uint256 tokenId_) external {
        _mint(to_, tokenId_);
    }
}

contract NFTMarketplaceTest is Test {
    NFTMarketplace marketplace;
    MockNFT nft;
    address deployer = vm.addr(1);
    address user = vm.addr(2);
    address user2 = vm.addr(3);
    uint256 tokenId = 0;

    function setUp() public {
        vm.startPrank(deployer);
        marketplace = new NFTMarketplace();
        nft = new MockNFT();
        vm.stopPrank();

        vm.prank(user);
        nft.mint(user, tokenId);
    }

    function testMintNFT() public view {
        address ownerOf = nft.ownerOf(tokenId);
        assert(ownerOf == user);
    }

    function testShouldRevertIfPriceIsZero() public {
        vm.startPrank(user);

        vm.expectRevert("Price must be greater than zero");
        marketplace.listNFT(address(nft), tokenId, 0);

        vm.stopPrank();
    }

    function testShouldRevertIfNotOwner() public {
        vm.startPrank(user);

        uint256 tokenId_ = 1;
        nft.mint(user2, tokenId_);

        vm.expectRevert("Only the owner can list the NFT");
        marketplace.listNFT(address(nft), tokenId_, 1 ether);

        vm.stopPrank();
    }

    function testListNFT() public {
        vm.startPrank(user);

        (address sellerBefore, , , ) = marketplace.listings(
            address(nft),
            tokenId
        );

        marketplace.listNFT(address(nft), tokenId, 1 ether);

        (address sellerAfter, , , ) = marketplace.listings(
            address(nft),
            tokenId
        );

        assert(sellerBefore == address(0) && sellerAfter == user);

        vm.stopPrank();
    }

    function testCancelListShouldRevertIfNotOwner() public {
        vm.startPrank(user);

        marketplace.listNFT(address(nft), tokenId, 1 ether);

        vm.stopPrank();

        vm.startPrank(user2);

        vm.expectRevert("Only the seller can cancel the listing");
        marketplace.cancelListing(address(nft), tokenId);

        vm.stopPrank();
    }

    function testCancelListing() public {
        vm.startPrank(user);

        marketplace.listNFT(address(nft), tokenId, 1 ether);

        (address sellerBefore, , , ) = marketplace.listings(
            address(nft),
            tokenId
        );

        marketplace.cancelListing(address(nft), tokenId);

        (address sellerAfter, , , ) = marketplace.listings(
            address(nft),
            tokenId
        );

        assert(sellerBefore == user && sellerAfter == address(0));

        vm.stopPrank();
    }

    function testCanNotBuyUnlistedNFT() public {
        vm.startPrank(user2);

        vm.expectRevert("NFT not listed for sale");
        marketplace.buyNFT(address(nft), tokenId);

        vm.stopPrank();
    }

    function testCanNotBuyWithIncorrectAmount() public {
        vm.startPrank(user);

        marketplace.listNFT(address(nft), tokenId, 1 ether);

        vm.stopPrank();

        vm.startPrank(user2);

        vm.deal(user2, 1 ether);

        vm.expectRevert("Incorrect payment amount");
        marketplace.buyNFT{value: 0.5 ether}(address(nft), tokenId);

        vm.stopPrank();
    }

    function testBuyNFTCorrectly() public {
        uint256 price_ = 1 ether;

        vm.startPrank(user);
        marketplace.listNFT(address(nft), tokenId, price_);
        nft.approve(address(marketplace), tokenId);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.deal(user2, 1 ether);
        uint256 sellerBalanceBefore = user.balance;
        marketplace.buyNFT{value: price_}(address(nft), tokenId);
        uint256 sellerBalanceAfter = user.balance;
        address newOwner = nft.ownerOf(tokenId);
        (address seller, , , ) = marketplace.listings(address(nft), tokenId);
        assert(newOwner == user2 && seller == address(0));
        assert(sellerBalanceAfter == sellerBalanceBefore + price_);
        vm.stopPrank();
    }
}
