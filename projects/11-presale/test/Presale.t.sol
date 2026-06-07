// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/Presale.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SaleToken is ERC20 {
    constructor() ERC20("Sale Token", "STK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract PresaleTest is Test {
    Presale presale;
    SaleToken saleToken;

    address saleTokenAddress_;
    address daiAddress_ = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI address on Arbitrum
    address usdcAddress_ = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address fundsWallet_ = address(0x4);
    address dataFeedAddress_ = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // ETH/USD Chainlink Arbitrum
    uint256 totalSupply_ = 3000000 * 1e18;
    uint256 startingTime_ = block.timestamp;
    uint256 endingTime_ = block.timestamp + 5000;
    uint256[][3] phases_;

    address user = 0xe8D294F3fff2A5CB34D15eCdEF34A53b01f5A462; // Address with USDC

    function setUp() public {
        phases_[0] = [1000000 * 1e18, 5000, block.timestamp + 1000];
        phases_[1] = [1000000 * 1e18, 500, block.timestamp + 2000];
        phases_[2] = [1000000 * 1e18, 50, block.timestamp + 3000];

        saleToken = new SaleToken();
        saleTokenAddress_ = address(saleToken);
        saleToken.mint(address(this), totalSupply_);

        uint64 nonce = vm.getNonce(address(this));
        address presaleAddress = vm.computeCreateAddress(address(this), nonce);

        IERC20(saleTokenAddress_).approve(presaleAddress, totalSupply_);

        presale = new Presale(
            saleTokenAddress_,
            daiAddress_,
            usdcAddress_,
            fundsWallet_,
            dataFeedAddress_,
            totalSupply_,
            startingTime_,
            endingTime_,
            phases_
        );
    }

    function testCanNotDeployIfEndingTimeBeforeStartingTime() public {
        vm.expectRevert("Ending time must be greater than starting time.");
        new Presale(
            saleTokenAddress_,
            daiAddress_,
            usdcAddress_,
            fundsWallet_,
            dataFeedAddress_,
            totalSupply_,
            startingTime_,
            startingTime_,
            phases_
        );
    }

    function testBlacklistAddress() public {
        presale.blacklistAddress(user);
        assertEq(presale.isBlacklisted(user), true);
    }

    function testRemoveAddressFromBlacklist() public {
        presale.blacklistAddress(user);
        assertEq(presale.isBlacklisted(user), true);
        presale.removeAddressFromBlacklist(user);
        assertEq(presale.isBlacklisted(user), false);
    }

    function testCanNotBlacklistAddressIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        presale.blacklistAddress(user);
    }

    function testCanNotRemoveAddressFromBlacklistIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        presale.removeAddressFromBlacklist(user);
    }

    function testBuyWithStableCoinCorrectly() public {
        uint256 amount_ = 100 * 1e6;

        vm.startPrank(user);
        uint256 usdcBalanceBefore = IERC20(usdcAddress_).balanceOf(user);

        IERC20(usdcAddress_).approve(address(presale), amount_);
        presale.buyWithStableCoin(usdcAddress_, amount_);

        uint256 usdcBalanceAfter = IERC20(usdcAddress_).balanceOf(user);

        uint256 expectedTokenAmount = (amount_ * 10 ** (18 - 6) * 1e6) /
            phases_[0][1];
        assertEq(expectedTokenAmount, presale.userBalance(user));
        assert(usdcBalanceAfter == usdcBalanceBefore - amount_);
        vm.stopPrank();
    }

    function testBuyWithStableCoinCorrectlyWithDAI() public {
        uint256 amount_ = 100 * 1e18;

        vm.startPrank(user);
        uint256 daiBalanceBefore = IERC20(daiAddress_).balanceOf(user);

        IERC20(daiAddress_).approve(address(presale), amount_);
        presale.buyWithStableCoin(daiAddress_, amount_);

        uint256 daiBalanceAfter = IERC20(daiAddress_).balanceOf(user);

        uint256 expectedTokenAmount = (amount_ * 1e6) / phases_[0][1];
        assertEq(expectedTokenAmount, presale.userBalance(user));
        assert(daiBalanceAfter == daiBalanceBefore - amount_);
        vm.stopPrank();
    }

    function testCanNotBuyWithStableCoinIfBlacklisted() public {
        presale.blacklistAddress(user);
        vm.startPrank(user);
        vm.expectRevert("You are blacklisted.");
        presale.buyWithStableCoin(usdcAddress_, 100 * 1e6);
        vm.stopPrank();
    }

    function testCanNotBuyWithStableCoinIfPresaleNotStarted() public {
        vm.warp(startingTime_ - 1);
        vm.startPrank(user);
        vm.expectRevert("Presale has not started yet.");
        presale.buyWithStableCoin(usdcAddress_, 100 * 1e6);
        vm.stopPrank();
    }

    function testCanNotBuyWithStableCoinIfPresaleEnded() public {
        vm.warp(endingTime_ + 1);
        vm.startPrank(user);
        vm.expectRevert("Presale has ended. No more tokens can be sold.");
        presale.buyWithStableCoin(usdcAddress_, 100 * 1e6);
        vm.stopPrank();
    }

    function testCanNotBuyWithStableCoinIfInvalidTokenAddress() public {
        vm.startPrank(user);
        vm.expectRevert("Invalid token address.");
        presale.buyWithStableCoin(address(0), 100 * 1e6);
        vm.stopPrank();
    }

    function testCanNotBuyWithStableCoinIfSoldOut() public {
        vm.startPrank(user);
        vm.expectRevert("Presale has sold all the tokens.");
        presale.buyWithStableCoin(usdcAddress_, totalSupply_);
        vm.stopPrank();
    }

    function testBuyWithEtherCorrectly() public {
        uint256 amount_ = 1 * 1e18;

        vm.startPrank(user);
        vm.deal(user, amount_);
        uint256 ethBalanceBefore = address(user).balance;

        presale.buyWithEther{value: amount_}();

        uint256 ethBalanceAfter = address(user).balance;

        uint256 usdValue = (amount_ * presale.getEtherPrice()) / 1e18;
        uint256 expectedTokenAmount = (usdValue * 1e6) / phases_[0][1];
        assertEq(expectedTokenAmount, presale.userBalance(user));
        assert(ethBalanceAfter == ethBalanceBefore - amount_);
        vm.stopPrank();
    }

    function testCanNotBuyWithEtherIfBlacklisted() public {
        uint256 amount_ = 100 * 1e18;
        presale.blacklistAddress(user);
        vm.startPrank(user);
        vm.deal(user, amount_);
        vm.expectRevert("You are blacklisted.");
        presale.buyWithEther{value: amount_}();
        vm.stopPrank();
    }

    function testCanNotBuyWithEtherIfPresaleNotStarted() public {
        vm.warp(startingTime_ - 1);
        uint256 amount_ = 100 * 1e18;
        vm.startPrank(user);
        vm.deal(user, amount_);
        vm.expectRevert("Presale has not started yet.");
        presale.buyWithEther{value: amount_}();
        vm.stopPrank();
    }

    function testCanNotBuyWithEtherIfPresaleEnded() public {
        vm.warp(endingTime_ + 1);
        uint256 amount_ = 100 * 1e18;
        vm.startPrank(user);
        vm.deal(user, amount_);
        vm.expectRevert("Presale has ended. No more tokens can be sold.");
        presale.buyWithEther{value: amount_}();
        vm.stopPrank();
    }

    function testCanNotBuyWithEtherIfSoldOut() public {
        uint256 amount_ = totalSupply_ * 1e18;
        vm.startPrank(user);
        vm.deal(user, amount_);
        vm.expectRevert("Presale has sold all the tokens.");
        presale.buyWithEther{value: amount_}();
        vm.stopPrank();
    }

    function testClaimTokensCorrectly() public {
        uint256 amount_ = 100 * 1e6;

        vm.startPrank(user);
        uint256 usdcBalanceBefore = IERC20(usdcAddress_).balanceOf(user);

        IERC20(usdcAddress_).approve(address(presale), amount_);
        presale.buyWithStableCoin(usdcAddress_, amount_);

        uint256 usdcBalanceAfter = IERC20(usdcAddress_).balanceOf(user);

        uint256 expectedTokenAmount = (amount_ * 10 ** (18 - 6) * 1e6) /
            phases_[0][1];
        assertEq(expectedTokenAmount, presale.userBalance(user));
        assert(usdcBalanceAfter == usdcBalanceBefore - amount_);

        vm.warp(endingTime_ + 1);

        presale.claimTokens();

        uint256 usdcBalanceAfterClaim = IERC20(usdcAddress_).balanceOf(user);
        assert(usdcBalanceAfterClaim == usdcBalanceAfter);
        vm.stopPrank();
    }

    function testCanNotClaimTokensIfPresaleNotEnded() public {
        vm.startPrank(user);
        vm.expectRevert("Presale has not ended yet.");
        presale.claimTokens();
        vm.stopPrank();
    }

    function testEmergencyERC20WithdrawCorrectly() public {
        uint256 amount_ = 1000 * 1e6;
        deal(usdcAddress_, address(presale), amount_);

        uint256 ownerBalanceBefore = IERC20(usdcAddress_).balanceOf(
            address(this)
        );

        presale.emergencyERC20Withdraw(usdcAddress_, amount_);

        assertEq(IERC20(usdcAddress_).balanceOf(address(presale)), 0);
        assertEq(
            IERC20(usdcAddress_).balanceOf(address(this)),
            ownerBalanceBefore + amount_
        );
    }

    function testCanNotEmergencyERC20WithdrawIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        presale.emergencyERC20Withdraw(usdcAddress_, 1000 * 1e6);
    }

    function testCanNotEmergencyERC20WithdrawIfNotEnoughBalance() public {
        uint256 amount_ = 1000 * 1e6;
        deal(usdcAddress_, address(presale), amount_);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        presale.emergencyERC20Withdraw(usdcAddress_, amount_ + 1);
    }

    function testEmergencyETHWithdrawCorrectly() public {
        uint256 amount_ = 1000 * 1e18;
        vm.deal(address(presale), amount_);

        uint256 ownerBalanceBefore = address(this).balance;

        presale.emergencyETHWithdraw();

        assertEq(address(presale).balance, 0);
        assertEq(address(this).balance, ownerBalanceBefore + amount_);
    }

    function testCanNotEmergencyETHWithdrawIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        presale.emergencyETHWithdraw();
    }

    receive() external payable {}
}
