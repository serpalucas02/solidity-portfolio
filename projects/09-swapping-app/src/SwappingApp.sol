// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./interfaces/IV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwappingApp {
    using SafeERC20 for IERC20;

    address public immutable V2Router02Address;

    event TokensSwapped(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address V2Router02Address_) {
        V2Router02Address = V2Router02Address_;
    }

    function swapTokens(
        uint256 amountIn_,
        uint256 amountOutMin_,
        address[] memory path_,
        uint256 deadline_
    ) external {
        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).forceApprove(V2Router02Address, amountIn_);
        uint[] memory amountsOut = IV2Router02(V2Router02Address)
            .swapExactTokensForTokens(
                amountIn_,
                amountOutMin_,
                path_,
                msg.sender,
                deadline_
            );

        emit TokensSwapped(
            path_[0],
            path_[path_.length - 1],
            amountIn_,
            amountsOut[amountsOut.length - 1]
        );
    }
}
