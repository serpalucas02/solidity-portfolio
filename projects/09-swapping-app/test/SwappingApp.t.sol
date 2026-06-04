// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/SwappingApp.sol";

contract SwappingAppTest is Test {
    SwappingApp swappingApp;
    address uniswapV2Router02Address =
        0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address user = 0xe8D294F3fff2A5CB34D15eCdEF34A53b01f5A462; // Address with USDC
    address USDCAddress = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC address on Arbitrum
    address DAIAddress = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI address on Arbitrum

    function setUp() public {
        swappingApp = new SwappingApp(uniswapV2Router02Address);
    }

    function testDeployCorrectly() public view {
        assertEq(swappingApp.V2Router02Address(), uniswapV2Router02Address);
    }

    function testSwapTokens() public {
        uint256 amountIn_ = 5 * 1e6; // USDC
        uint256 amountOutMin_ = 4 * 1e18; // DAI
        uint256 deadline_ = 1780616130 + 1 hours;
        address[] memory path_ = new address[](2);
        path_[0] = USDCAddress;
        path_[1] = DAIAddress;

        vm.startPrank(user);
        IERC20(USDCAddress).approve(address(swappingApp), amountIn_);

        uint256 usdcBalanceBefore = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceBefore = IERC20(DAIAddress).balanceOf(user);
        swappingApp.swapTokens(amountIn_, amountOutMin_, path_, deadline_);
        uint256 usdcBalanceAfter = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceAfter = IERC20(DAIAddress).balanceOf(user);

        assert(usdcBalanceAfter == usdcBalanceBefore - amountIn_);
        assert(daiBalanceAfter >= daiBalanceBefore + amountOutMin_);
        vm.stopPrank();
    }
}
