// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFTCollection} from "../src/NFTCollection.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract NFTCollectionTest is Test {
    NFTCollection nft;

    address alice = makeAddr("alice");

    string constant NAME = "My Collection";
    string constant SYMBOL = "MYC";
    uint256 constant SUPPLY = 10;
    string constant BASE_URI = "ipfs://collectionCID/";

    event NFTMinted(address userAddress_, uint256 tokenId_);

    function setUp() public {
        nft = new NFTCollection(NAME, SYMBOL, SUPPLY, BASE_URI);
    }

    function testConstructorSetsState() public view {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.totalSupply(), SUPPLY);
        assertEq(nft.baseUri(), BASE_URI);
    }

    function testMint() public {
        vm.prank(alice);
        nft.mint();
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    function testMintIncrementsTokenIds() public {
        vm.startPrank(alice);
        nft.mint();
        nft.mint();
        vm.stopPrank();
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), alice);
    }

    function testMintEmitsEvent() public {
        vm.expectEmit(false, false, false, true, address(nft));
        emit NFTMinted(alice, 0);
        vm.prank(alice);
        nft.mint();
    }

    function testMintToContractReceiverWorks() public {
        GoodReceiver receiver = new GoodReceiver();
        receiver.mintOne(nft);
        assertEq(nft.ownerOf(0), address(receiver));
        assertEq(nft.balanceOf(address(receiver)), 1);
    }

    function testMintRevertsForNonReceiverContract() public {
        BadReceiver receiver = new BadReceiver();
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(receiver)));
        receiver.mintOne(nft);
    }

    function testCannotMintMoreThanSupply() public {
        NFTCollection small = new NFTCollection(NAME, SYMBOL, 2, BASE_URI);
        vm.startPrank(alice);
        small.mint();
        small.mint();
        vm.expectRevert("All NFTs have been minted");
        small.mint();
        vm.stopPrank();
    }

    function testTokenURI() public {
        vm.prank(alice);
        nft.mint();
        assertEq(nft.tokenURI(0), "ipfs://collectionCID/0.json");
    }

    function testTokenURIRevertsForNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 999));
        nft.tokenURI(999);
    }

    function testTokenURIEmptyWhenNoBaseURI() public {
        NFTCollection noBase = new NFTCollection(NAME, SYMBOL, SUPPLY, "");
        vm.prank(alice);
        noBase.mint();
        assertEq(noBase.tokenURI(0), "");
    }
}

contract GoodReceiver is ERC721Holder {
    function mintOne(NFTCollection nft) external {
        nft.mint();
    }
}

contract BadReceiver {
    function mintOne(NFTCollection nft) external {
        nft.mint();
    }
}
