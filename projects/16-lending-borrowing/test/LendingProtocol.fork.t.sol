// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/LendingProtocol.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Fork test contra Arbitrum One. Usa tokens y price feeds REALES de
 *      Chainlink, asi nos ahorramos mockear precios y decimales.
 *      Se auto-forkea en el setUp (no hace falta pasar --fork-url): usa la env
 *      var ARBITRUM_RPC si está, si no cae a un RPC público de Arbitrum.
 */
contract LendingProtocolForkTest is Test {
    LendingProtocol internal lending;

    // --- Direcciones de Arbitrum One ---
    address internal constant WETH =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // 18 decimales (colateral)
    address internal constant USDC =
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // 6 decimales (se presta)
    address internal constant WETH_USD_FEED =
        0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address internal constant USDC_USD_FEED =
        0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    // --- Parámetros de los markets ---
    uint256 internal constant CF_WETH = 8000; // 80%
    uint256 internal constant CF_USDC = 9000; // 90%
    uint256 internal constant SUPPLY_RATE = 100;
    uint256 internal constant BORROW_RATE = 200;

    // --- Fondeo ---
    uint256 internal constant POOL_LIQUIDITY = 100_000e6; // USDC del lender
    uint256 internal constant BORROWER_WETH = 10 ether;

    address internal lender = makeAddr("lender"); // aporta liquidez en USDC
    address internal borrower = makeAddr("borrower"); // deposita WETH, pide USDC

    function setUp() public {
        // Auto-fork de Arbitrum One: así `forge test` corre sin --fork-url.
        vm.createSelectFork(
            vm.envOr("ARBITRUM_RPC", string("https://arb1.arbitrum.io/rpc"))
        );

        lending = new LendingProtocol(); // el test es el owner

        lending.addMarket(WETH, CF_WETH, SUPPLY_RATE, BORROW_RATE);
        lending.addMarket(USDC, CF_USDC, SUPPLY_RATE, BORROW_RATE);
        lending.setPriceFeed(WETH, WETH_USD_FEED);
        lending.setPriceFeed(USDC, USDC_USD_FEED);

        deal(WETH, borrower, BORROWER_WETH);
        deal(USDC, lender, POOL_LIQUIDITY);

        // El lender deposita USDC para que haya de donde prestar
        vm.startPrank(lender);
        IERC20(USDC).approve(address(lending), type(uint256).max);
        lending.deposit(USDC, POOL_LIQUIDITY);
        vm.stopPrank();
    }

    /// @notice Los precios reales son coherentes: ETH vale muchísimo más que 1 USDC.
    function testRealPricesAreSane() public view {
        uint256 minEthPrice = 100e8; // ETH > $100, con holgura
        uint256 ethPrice = lending.getPrice(WETH); // 8 decimales
        uint256 usdcPrice = lending.getPrice(USDC);

        assertGt(ethPrice, 0);
        assertGt(usdcPrice, 0);
        assertGt(ethPrice, minEthPrice);
        assertGt(ethPrice, usdcPrice * 100);
    }

    /// @notice Deposito WETH como colateral y pido USDC dentro del límite sano.
    function testDepositCollateralAndBorrow() public {
        uint256 collateral = 5 ether; // ~miles de USD en colateral
        uint256 borrowAmount = 1_000e6; // holgadamente dentro del límite

        vm.startPrank(borrower);
        IERC20(WETH).approve(address(lending), type(uint256).max);
        lending.deposit(WETH, collateral);

        uint256 usdcBefore = IERC20(USDC).balanceOf(borrower);
        lending.borrow(USDC, borrowAmount);
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(borrower) - usdcBefore, borrowAmount);
        assertEq(lending.borrows(borrower, USDC), borrowAmount);
        assertFalse(lending.isLiquidatable(borrower)); // sigue sano
    }

    /// @notice Pedir mucho más de lo que el colateral banca revierte.
    function testBorrowRevertsWhenUndercollateralized() public {
        uint256 collateral = 1 ether; // ~unos miles de USD
        uint256 tooMuch = 50_000e6; // muchísimo más que el límite

        vm.startPrank(borrower);
        IERC20(WETH).approve(address(lending), type(uint256).max);
        lending.deposit(WETH, collateral);

        vm.expectRevert("LendingProtocol: cannot borrow");
        lending.borrow(USDC, tooMuch);
        vm.stopPrank();
    }
}
