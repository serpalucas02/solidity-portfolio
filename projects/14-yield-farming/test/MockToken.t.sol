// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../src/MockToken.sol";

contract MockTokenTest is Test {
    MockToken token;

    uint256 initialBalance = 1000;

    function setUp() public {
        token = new MockToken("Mock Token", "MOCK", initialBalance);
    }

    function testMint() public {
        uint256 amount = 100 * 1e18;
        uint256 balanceBefore = token.balanceOf(address(this));
        token.mint(address(this), amount);
        assertEq(token.balanceOf(address(this)), balanceBefore + amount);
    }

    function testBurn() public {
        uint256 mintAmount = 100 * 1e18;
        uint256 burnAmount = 50 * 1e18;
        token.mint(address(this), mintAmount);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.burn(address(this), burnAmount);
        assertEq(token.balanceOf(address(this)), balanceBefore - burnAmount);
    }
}
