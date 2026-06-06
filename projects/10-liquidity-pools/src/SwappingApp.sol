// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./interfaces/IV2Router02.sol";
import "./interfaces/IV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwappingApp {
    using SafeERC20 for IERC20;

    address public immutable V2Router02Address;
    address public immutable V2FactoryAddress;
    address public USDC;
    address public DAI;

    event TokensSwapped(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event LiquidityAdded(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    constructor(
        address V2Router02Address_,
        address V2FactoryAddress_,
        address USDC_,
        address DAI_
    ) {
        V2Router02Address = V2Router02Address_;
        V2FactoryAddress = V2FactoryAddress_;
        USDC = USDC_;
        DAI = DAI_;
    }

    function swapTokens(
        uint256 amountIn_,
        uint256 amountOutMin_,
        address[] memory path_,
        address to_,
        uint256 deadline_
    ) public returns (uint256) {
        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).forceApprove(V2Router02Address, amountIn_);
        uint[] memory amountsOut = IV2Router02(V2Router02Address)
            .swapExactTokensForTokens(
                amountIn_,
                amountOutMin_,
                path_,
                to_,
                deadline_
            );

        emit TokensSwapped(
            path_[0],
            path_[path_.length - 1],
            amountIn_,
            amountsOut[amountsOut.length - 1]
        );

        return amountsOut[amountsOut.length - 1];
    }

    function addLiquidity(
        uint256 amountIn_,
        uint256 amountOutMin_,
        address[] memory path_,
        uint256 amountAMin_,
        uint256 amountBMin_,
        uint256 deadline_
    ) external {
        // 1. Swap Tokens
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amountIn_ / 2);
        uint256 swappedAmount = swapTokens(
            amountIn_ / 2,
            amountOutMin_,
            path_,
            address(this),
            deadline_
        );

        // 2. Add Liquidity
        IERC20(USDC).forceApprove(V2Router02Address, amountIn_ / 2);
        IERC20(DAI).forceApprove(V2Router02Address, swappedAmount);
        (, , uint256 liquidity) = IV2Router02(V2Router02Address).addLiquidity(
            USDC,
            DAI,
            amountIn_ / 2,
            swappedAmount,
            amountAMin_,
            amountBMin_,
            msg.sender,
            deadline_
        );

        emit LiquidityAdded(USDC, DAI, amountIn_ / 2, swappedAmount, liquidity);
    }

    function removeLiquidity(
        uint256 liquidity_,
        uint256 amountAMin_,
        uint256 amountBMin_,
        address to_,
        uint256 deadline_
    ) external {
        address lpTokenAddress = IV2Factory(V2FactoryAddress).getPair(
            USDC,
            DAI
        );
        IERC20(lpTokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            liquidity_
        );
        IERC20(lpTokenAddress).forceApprove(V2Router02Address, liquidity_);

        IV2Router02(V2Router02Address).removeLiquidity(
            USDC,
            DAI,
            liquidity_,
            amountAMin_,
            amountBMin_,
            to_,
            deadline_
        );
    }
}
