// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/SwappingApp.sol";

contract SwappingAppTest is Test {
    SwappingApp swappingApp;
    address uniswapV2Router02Address =
        0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address uniswapV2FactoryAddress =
        0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9;
    address user = 0xe8D294F3fff2A5CB34D15eCdEF34A53b01f5A462; // Address with USDC
    address USDCAddress = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC address on Arbitrum
    address DAIAddress = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI address on Arbitrum

    function setUp() public {
        swappingApp = new SwappingApp(
            uniswapV2Router02Address,
            uniswapV2FactoryAddress,
            USDCAddress,
            DAIAddress
        );
    }

    function testDeployCorrectly() public view {
        assertEq(swappingApp.V2Router02Address(), uniswapV2Router02Address);
    }

    function testSwapTokens() public {
        uint256 amountIn_ = 5 * 1e6; // USDC
        uint256 amountOutMin_ = 4 * 1e18; // DAI
        uint256 deadline_ = block.timestamp + 1 hours;
        address[] memory path_ = new address[](2);
        path_[0] = USDCAddress;
        path_[1] = DAIAddress;

        vm.startPrank(user);
        IERC20(USDCAddress).approve(address(swappingApp), amountIn_);

        uint256 usdcBalanceBefore = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceBefore = IERC20(DAIAddress).balanceOf(user);
        swappingApp.swapTokens(
            amountIn_,
            amountOutMin_,
            path_,
            user,
            deadline_
        );
        uint256 usdcBalanceAfter = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceAfter = IERC20(DAIAddress).balanceOf(user);

        assert(usdcBalanceAfter == usdcBalanceBefore - amountIn_);
        assert(daiBalanceAfter >= daiBalanceBefore + amountOutMin_);
        vm.stopPrank();
    }

    function testSwapAndAddLiquidity() public {
        uint256 amountIn_ = 10 * 1e6; // USDC
        uint256 amountOutMin_ = 4 * 1e18; // DAI
        uint256 amountAMin_ = 4 * 1e6; // USDC
        uint256 amountBMin_ = 4 * 1e18; // DAI
        uint256 deadline_ = block.timestamp + 1 hours;
        address[] memory path_ = new address[](2);
        path_[0] = USDCAddress;
        path_[1] = DAIAddress;

        vm.startPrank(user);
        uint256 usdcBalanceBefore = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceBefore = IERC20(DAIAddress).balanceOf(user);
        IERC20(USDCAddress).approve(address(swappingApp), amountIn_);
        swappingApp.addLiquidity(
            amountIn_,
            amountOutMin_,
            path_,
            amountAMin_,
            amountBMin_,
            deadline_
        );
        uint256 usdcBalanceAfter = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceAfter = IERC20(DAIAddress).balanceOf(user);

        assert(usdcBalanceAfter < usdcBalanceBefore - amountIn_ / 2);
        assert(daiBalanceAfter < daiBalanceBefore + amountOutMin_);

        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        uint256 amountIn_ = 10 * 1e6; // USDC
        uint256 amountOutMin_ = 4 * 1e18; // DAI
        uint256 amountAMin_ = 4 * 1e6; // USDC
        uint256 amountBMin_ = 4 * 1e18; // DAI
        uint256 deadline_ = block.timestamp + 1 hours;
        address[] memory path_ = new address[](2);
        path_[0] = USDCAddress;
        path_[1] = DAIAddress;

        vm.startPrank(user);
        uint256 usdcBalanceBefore = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceBefore = IERC20(DAIAddress).balanceOf(user);
        IERC20(USDCAddress).approve(address(swappingApp), amountIn_);
        swappingApp.addLiquidity(
            amountIn_,
            amountOutMin_,
            path_,
            amountAMin_,
            amountBMin_,
            deadline_
        );
        uint256 usdcBalanceAfter = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceAfter = IERC20(DAIAddress).balanceOf(user);

        assert(usdcBalanceAfter < usdcBalanceBefore - amountIn_ / 2);
        assert(daiBalanceAfter < daiBalanceBefore + amountOutMin_);

        uint256 liquidity_ = IERC20(
            IV2Factory(uniswapV2FactoryAddress).getPair(USDCAddress, DAIAddress)
        ).balanceOf(user);
        uint256 usdcBalanceBeforeRemove = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceBeforeRemove = IERC20(DAIAddress).balanceOf(user);
        address liquidityAddress = IV2Factory(uniswapV2FactoryAddress).getPair(
            USDCAddress,
            DAIAddress
        );
        IERC20(liquidityAddress).approve(address(swappingApp), liquidity_);
        swappingApp.removeLiquidity(
            liquidity_,
            amountAMin_,
            amountBMin_,
            user,
            deadline_
        );
        uint256 usdcBalanceAfterRemove = IERC20(USDCAddress).balanceOf(user);
        uint256 daiBalanceAfterRemove = IERC20(DAIAddress).balanceOf(user);

        assert(usdcBalanceAfterRemove >= usdcBalanceBeforeRemove + amountAMin_);
        assert(daiBalanceAfterRemove >= daiBalanceBeforeRemove + amountBMin_);

        vm.stopPrank();
    }
}
