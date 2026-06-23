// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/// @title UniswapV3Swap — Swap Examples using Uniswap V3 Router
/// @author Lucas Serpa
/// @notice Demonstrates single-hop and multi-hop swaps on Uniswap V3.
///
/// ══════════════════════════════════════════════════════════════════════════════
/// HOW UNISWAP V3 SWAPS WORK
/// ══════════════════════════════════════════════════════════════════════════════
///
/// Uniswap V3 offers two main swap modes:
///
///   1. Exact Input  — "I want to sell EXACTLY 1 WETH. How much USDC will I get?"
///   2. Exact Output — "I want to buy EXACTLY 2000 USDC. How much WETH will it cost?"
///
/// Both modes can be single-hop (one pool) or multi-hop (multiple pools in sequence).
///
/// FEE TIERS:
///   - 500   (0.05%) — Stable pairs (USDC/DAI)
///   - 3000  (0.30%) — Standard pairs (WETH/USDC)
///   - 10000 (1.00%) — Exotic pairs
///
/// KEY PARAMETER: sqrtPriceLimitX96
///   - Controls how far the price can move during a swap
///   - Set to 0 to accept ANY price (most common for simple swaps)
///   - In production, set a limit to protect against sandwich attacks
///
contract UniswapV3Swap {
    ISwapRouter public immutable ROUTER;

    error ZeroAmount();

    event SwapExecuted(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    constructor(address _router) {
        ROUTER = ISwapRouter(_router);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // EXACT INPUT SINGLE — Sell exact amount, get maximum output
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Swap an exact amount of tokenIn for the maximum amount of tokenOut
    /// @dev Flow: caller → approve this contract → this contract approves router → router executes swap
    ///
    /// Example: "I want to swap exactly 1 WETH for as much USDC as possible"
    ///
    /// @param tokenIn The token to sell
    /// @param tokenOut The token to buy
    /// @param fee The pool fee tier (500, 3000, or 10000)
    /// @param amountIn The exact amount of tokenIn to swap
    /// @param amountOutMinimum Minimum tokenOut to accept (slippage protection)
    /// @return amountOut The amount of tokenOut received
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();

        // Transfer tokenIn from caller to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Approve the router to spend our tokenIn
        IERC20(tokenIn).approve(address(ROUTER), amountIn);

        // Build the swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: msg.sender, // Send output tokens directly to caller
            deadline: block.timestamp, // Must execute in this block
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0 // No price limit (accept any price)
        });

        // Execute the swap
        amountOut = ROUTER.exactInputSingle(params);

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // EXACT OUTPUT SINGLE — Buy exact amount, spend minimum input
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Swap the minimum amount of tokenIn for an exact amount of tokenOut
    /// @dev Refunds any unspent tokenIn back to the caller.
    ///
    /// Example: "I want exactly 2000 USDC. Spend at most 1 WETH to get it."
    ///
    /// @param tokenIn The token to sell
    /// @param tokenOut The token to buy
    /// @param fee The pool fee tier
    /// @param amountOut The exact amount of tokenOut desired
    /// @param amountInMaximum Maximum tokenIn willing to spend (slippage protection)
    /// @return amountIn The actual amount of tokenIn spent
    function swapExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum
    ) external returns (uint256 amountIn) {
        if (amountOut == 0) revert ZeroAmount();

        // Transfer maximum tokenIn from caller (we'll refund the excess)
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountInMaximum);
        IERC20(tokenIn).approve(address(ROUTER), amountInMaximum);

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountOut: amountOut,
            amountInMaximum: amountInMaximum,
            sqrtPriceLimitX96: 0
        });

        amountIn = ROUTER.exactOutputSingle(params);

        // Refund unspent tokenIn back to the caller
        if (amountIn < amountInMaximum) {
            // Reset approval for safety
            IERC20(tokenIn).approve(address(ROUTER), 0);
            IERC20(tokenIn).transfer(msg.sender, amountInMaximum - amountIn);
        }

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // EXACT INPUT MULTI-HOP — Chain multiple pools together
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Multi-hop swap: chain multiple pools for better routing
    /// @dev The path is ABI-encoded as: abi.encodePacked(tokenA, fee1, tokenB, fee2, tokenC)
    ///
    /// Example: DAI → (0.05% pool) → USDC → (0.3% pool) → WETH
    ///   path = abi.encodePacked(DAI, uint24(500), USDC, uint24(3000), WETH)
    ///
    /// WHY MULTI-HOP?
    ///   - Sometimes there's no direct pool between two tokens
    ///   - Sometimes routing through an intermediate token gives a better price
    ///   - Example: DAI → WETH might be cheaper as DAI → USDC → WETH
    ///
    /// @param path The encoded swap path
    /// @param amountIn The exact amount of the first token to swap
    /// @param amountOutMinimum Minimum of the last token to receive
    /// @return amountOut The amount of the final token received
    function swapExactInputMultihop(bytes calldata path, uint256 amountIn, uint256 amountOutMinimum)
        external
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();

        // Extract the first token from the path (first 20 bytes)
        address tokenIn;
        assembly {
            tokenIn := shr(96, calldataload(path.offset))
        }

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(ROUTER), amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });

        amountOut = ROUTER.exactInput(params);
    }
}
