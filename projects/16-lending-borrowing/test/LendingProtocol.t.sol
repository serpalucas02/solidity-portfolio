// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/LendingProtocol.sol";
import "./mocks/MockToken.sol";
import "./mocks/MockAggregator.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @dev Suite con mocks: MockToken (decimales configurables) + MockAggregator
 *      (precio controlable). Permite testear toda la lógica de forma
 *      determinística, incluida la liquidación (bajando el precio del colateral).
 *      El test contra Chainlink REAL vive en LendingProtocol.fork.t.sol.
 */
contract LendingProtocolTest is Test {
    LendingProtocol internal lending;

    MockToken internal weth; // colateral, 18 decimales
    MockToken internal usdc; // se presta, 6 decimales
    MockAggregator internal wethFeed;
    MockAggregator internal usdcFeed;

    address internal lender = makeAddr("lender"); // aporta liquidez en USDC
    address internal borrower = makeAddr("borrower");
    address internal liquidator = makeAddr("liquidator");

    // --- Precios (feeds Chainlink, 8 decimales) ---
    int256 internal constant ETH_PRICE = 2000e8; // $2000
    int256 internal constant USDC_PRICE = 1e8; // $1
    int256 internal constant ETH_PRICE_CRASHED = 1000e8; // $1000 -> liquidable

    // --- Parámetros de los markets (basis points / decimales) ---
    uint256 internal constant CF_WETH = 8000; // 80% collateral factor
    uint256 internal constant CF_USDC = 9000; // 90%
    uint256 internal constant SUPPLY_RATE = 100;
    uint256 internal constant BORROW_RATE = 200;
    uint8 internal constant WETH_DECIMALS = 18;
    uint8 internal constant USDC_DECIMALS = 6;

    // --- Fondeo inicial ---
    uint256 internal constant POOL_LIQUIDITY = 1_000_000e6; // USDC del lender
    uint256 internal constant BORROWER_WETH = 100 ether; // WETH del borrower

    function setUp() public {
        weth = new MockToken("Wrapped Ether", "WETH", WETH_DECIMALS);
        usdc = new MockToken("USD Coin", "USDC", USDC_DECIMALS);
        wethFeed = new MockAggregator(ETH_PRICE);
        usdcFeed = new MockAggregator(USDC_PRICE);

        lending = new LendingProtocol(); // el test es el owner

        lending.addMarket(address(weth), CF_WETH, SUPPLY_RATE, BORROW_RATE);
        lending.addMarket(address(usdc), CF_USDC, SUPPLY_RATE, BORROW_RATE);
        lending.setPriceFeed(address(weth), address(wethFeed));
        lending.setPriceFeed(address(usdc), address(usdcFeed));

        // El lender llena el pool de USDC para que haya de donde prestar
        usdc.mint(lender, POOL_LIQUIDITY);
        vm.startPrank(lender);
        usdc.approve(address(lending), type(uint256).max);
        lending.deposit(address(usdc), POOL_LIQUIDITY);
        vm.stopPrank();

        // El borrower arranca con WETH para usar de colateral
        weth.mint(borrower, BORROWER_WETH);
    }

    // Helper: el `user` deposita `amount` de WETH como colateral.
    function _depositWeth(address user, uint256 amount) internal {
        vm.startPrank(user);
        weth.approve(address(lending), amount);
        lending.deposit(address(weth), amount);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // addMarket
    // ---------------------------------------------------------------------

    function testAddMarket() public {
        uint256 collateralFactor = 5000; // 50%
        MockToken newToken = new MockToken("New", "NEW", 18);

        lending.addMarket(
            address(newToken),
            collateralFactor,
            SUPPLY_RATE,
            BORROW_RATE
        );

        LendingProtocol.Market memory m = lending.getMarket(address(newToken));
        assertEq(address(m.token), address(newToken));
        assertEq(m.collateralFactor, collateralFactor);
        assertTrue(m.isActive);
        assertEq(lending.getSupportedTokens().length, 3); // weth, usdc, new
    }

    function testAddMarketReverts() public {
        uint256 invalidCF = 10001; // > BASIS_POINT
        MockToken t = new MockToken("T", "T", 18);

        vm.expectRevert("LendingProtocol: token is zero");
        lending.addMarket(address(0), 5000, SUPPLY_RATE, BORROW_RATE);

        vm.expectRevert("LendingProtocol: invalid collateral factor");
        lending.addMarket(address(t), invalidCF, SUPPLY_RATE, BORROW_RATE);

        vm.expectRevert("LendingProtocol: market already exists");
        lending.addMarket(address(weth), 5000, SUPPLY_RATE, BORROW_RATE);
    }

    function testAddMarketRevertsOnInvalidParams() public {
        MockToken t = new MockToken("T", "T", 18);

        vm.expectRevert("LendingProtocol: invalid collateral factor");
        lending.addMarket(address(t), 0, SUPPLY_RATE, BORROW_RATE); // CF = 0

        vm.expectRevert("LendingProtocol: invalid supply rate");
        lending.addMarket(address(t), CF_WETH, 0, BORROW_RATE); // supplyRate = 0

        vm.expectRevert("LendingProtocol: invalid borrow rate");
        lending.addMarket(address(t), CF_WETH, SUPPLY_RATE, 0); // borrowRate = 0
    }

    function testAddMarketOnlyOwner() public {
        MockToken t = new MockToken("T", "T", 18);

        vm.prank(borrower);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                borrower
            )
        );
        lending.addMarket(address(t), CF_WETH, SUPPLY_RATE, BORROW_RATE);
    }

    // ---------------------------------------------------------------------
    // updateMarket / setPriceFeed
    // ---------------------------------------------------------------------

    function testUpdateMarket() public {
        uint256 newCF = 7000;
        uint256 newSupplyRate = 150;
        uint256 newBorrowRate = 250;

        lending.updateMarket(
            address(weth),
            newCF,
            newSupplyRate,
            newBorrowRate
        );

        LendingProtocol.Market memory m = lending.getMarket(address(weth));
        assertEq(m.collateralFactor, newCF);
        assertEq(m.supplyRate, newSupplyRate);
        assertEq(m.borrowRate, newBorrowRate);
    }

    function testUpdateMarketReverts() public {
        uint256 invalidCF = 10001;
        address unknownMarket = address(0x1234);

        vm.expectRevert("LendingProtocol: invalid collateral factor");
        lending.updateMarket(address(weth), invalidCF, SUPPLY_RATE, BORROW_RATE);

        vm.expectRevert("LendingProtocol: invalid supply rate");
        lending.updateMarket(address(weth), CF_WETH, 0, BORROW_RATE);

        vm.expectRevert("LendingProtocol: invalid borrow rate");
        lending.updateMarket(address(weth), CF_WETH, SUPPLY_RATE, 0);

        // market inexistente -> lo frena el modifier onlyActiveMarket
        vm.expectRevert("LendingProtocol: market is not active");
        lending.updateMarket(unknownMarket, CF_WETH, SUPPLY_RATE, BORROW_RATE);
    }

    function testSetPriceFeedRevertsOnZero() public {
        vm.expectRevert("LendingProtocol: price feed is zero");
        lending.setPriceFeed(address(weth), address(0));
    }

    function testAdminFunctionsOnlyOwner() public {
        vm.startPrank(borrower);
        bytes memory err = abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            borrower
        );

        vm.expectRevert(err);
        lending.updateMarket(address(weth), CF_WETH, SUPPLY_RATE, BORROW_RATE);

        vm.expectRevert(err);
        lending.setPriceFeed(address(weth), address(wethFeed));

        vm.expectRevert(err);
        lending.pause();
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // deposit
    // ---------------------------------------------------------------------

    function testDeposit() public {
        uint256 depositAmount = 10 ether;

        _depositWeth(borrower, depositAmount);

        assertEq(lending.getUserDeposit(borrower, address(weth)), depositAmount);
        assertEq(weth.balanceOf(address(lending)), depositAmount);
        assertTrue(lending.getUser(borrower).isActive);
        assertEq(lending.getMarket(address(weth)).totalSupply, depositAmount);
    }

    function testDepositReverts() public {
        address unknownMarket = address(0x1234);
        uint256 amount = 1 ether;

        vm.startPrank(borrower);
        weth.approve(address(lending), 10 ether);

        vm.expectRevert("LendingProtocol: amount must be greater than 0");
        lending.deposit(address(weth), 0);

        // token sin market -> onlyActiveMarket revierte
        vm.expectRevert("LendingProtocol: market is not active");
        lending.deposit(unknownMarket, amount);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // withdraw
    // ---------------------------------------------------------------------

    function testWithdrawWithoutDebt() public {
        uint256 depositAmount = 10 ether;
        uint256 withdrawAmount = 4 ether;

        _depositWeth(borrower, depositAmount);

        uint256 balanceBefore = weth.balanceOf(borrower);
        vm.prank(borrower);
        lending.withdraw(address(weth), withdrawAmount);

        assertEq(weth.balanceOf(borrower) - balanceBefore, withdrawAmount);
        assertEq(
            lending.getUserDeposit(borrower, address(weth)),
            depositAmount - withdrawAmount
        );
    }

    function testWithdrawRevertsIfUnsafe() public {
        uint256 depositAmount = 10 ether; // $20k, ponderado $16k
        uint256 borrowAmount = 15_000e6; // deja la posición sana todavía
        uint256 unsafeWithdraw = 5 ether; // sacar esto la dejaría liquidable

        _depositWeth(borrower, depositAmount);
        vm.prank(borrower);
        lending.borrow(address(usdc), borrowAmount);

        vm.prank(borrower);
        vm.expectRevert("LendingProtocol: cannot withdraw");
        lending.withdraw(address(weth), unsafeWithdraw);
    }

    function testWithdrawRevertsIfInsufficientBalance() public {
        uint256 depositAmount = 1 ether;
        uint256 tooMuch = 2 ether;

        _depositWeth(borrower, depositAmount);
        vm.prank(borrower);
        vm.expectRevert("LendingProtocol: insufficient balance");
        lending.withdraw(address(weth), tooMuch);
    }

    // ---------------------------------------------------------------------
    // borrow
    // ---------------------------------------------------------------------

    function testBorrow() public {
        uint256 depositAmount = 10 ether; // $20k de colateral
        uint256 borrowAmount = 5_000e6;

        _depositWeth(borrower, depositAmount);

        uint256 balanceBefore = usdc.balanceOf(borrower);
        vm.prank(borrower);
        lending.borrow(address(usdc), borrowAmount);

        assertEq(usdc.balanceOf(borrower) - balanceBefore, borrowAmount);
        assertEq(lending.getUserBorrow(borrower, address(usdc)), borrowAmount);
    }

    function testBorrowRevertsIfUndercollateralized() public {
        uint256 depositAmount = 1 ether; // $2000, ponderado $1600
        uint256 borrowAmount = 5_000e6; // pide muchísimo más

        _depositWeth(borrower, depositAmount);
        vm.prank(borrower);
        vm.expectRevert("LendingProtocol: cannot borrow");
        lending.borrow(address(usdc), borrowAmount);
    }

    function testBorrowRevertsIfInsufficientSupply() public {
        uint256 collateral = 10 ether;
        uint256 borrowAmount = 1 ether; // no hay liquidez de "scarce"

        // market nuevo sin liquidez
        MockToken scarce = new MockToken("Scarce", "SCR", 18);
        MockAggregator scarceFeed = new MockAggregator(USDC_PRICE);
        lending.addMarket(address(scarce), CF_WETH, SUPPLY_RATE, BORROW_RATE);
        lending.setPriceFeed(address(scarce), address(scarceFeed));

        _depositWeth(borrower, collateral);
        vm.prank(borrower);
        vm.expectRevert("LendingProtocol: insufficient supply");
        lending.borrow(address(scarce), borrowAmount);
    }

    // ---------------------------------------------------------------------
    // repay
    // ---------------------------------------------------------------------

    function testRepay() public {
        uint256 depositAmount = 10 ether;
        uint256 borrowAmount = 5_000e6;
        uint256 repayAmount = 2_000e6;

        _depositWeth(borrower, depositAmount);
        vm.startPrank(borrower);
        lending.borrow(address(usdc), borrowAmount);

        usdc.approve(address(lending), type(uint256).max);
        lending.repay(address(usdc), repayAmount);
        vm.stopPrank();

        assertEq(
            lending.getUserBorrow(borrower, address(usdc)),
            borrowAmount - repayAmount
        );
    }

    function testRepayRevertsIfMoreThanOwed() public {
        uint256 depositAmount = 10 ether;
        uint256 borrowAmount = 5_000e6;
        uint256 overpay = 6_000e6; // más de lo que debe

        _depositWeth(borrower, depositAmount);
        vm.startPrank(borrower);
        lending.borrow(address(usdc), borrowAmount);
        usdc.approve(address(lending), type(uint256).max);

        vm.expectRevert("LendingProtocol: insufficient balance");
        lending.repay(address(usdc), overpay);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // depositWithSignature (firma off-chain)
    // ---------------------------------------------------------------------

    function testDepositWithSignature() public {
        (address signer, uint256 pk) = makeAddrAndKey("sig-signer");
        uint256 amount = 3 ether;
        uint256 deadline = block.timestamp + 1 hours;

        weth.mint(signer, 10 ether);
        uint256 nonce = lending.nonces(signer);

        LendingProtocol.SignatureData memory sig = _buildSig(
            pk,
            address(weth),
            amount,
            nonce,
            deadline
        );

        vm.startPrank(signer);
        weth.approve(address(lending), amount);
        lending.depositWithSignature(address(weth), amount, sig);
        vm.stopPrank();

        assertEq(lending.getUserDeposit(signer, address(weth)), amount);
        assertEq(lending.nonces(signer), nonce + 1); // nonce consumido
    }

    function testDepositWithSignatureRevertsOnBadSigner() public {
        (address signer, ) = makeAddrAndKey("sig-signer");
        (, uint256 wrongPk) = makeAddrAndKey("impostor");
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        weth.mint(signer, 10 ether);

        // firmado con la pk equivocada
        LendingProtocol.SignatureData memory sig = _buildSig(
            wrongPk,
            address(weth),
            amount,
            0,
            deadline
        );

        vm.startPrank(signer);
        weth.approve(address(lending), amount);
        vm.expectRevert("LendingProtocol: invalid signature");
        lending.depositWithSignature(address(weth), amount, sig);
        vm.stopPrank();
    }

    function testDepositWithSignatureRevertsOnExpired() public {
        (address signer, uint256 pk) = makeAddrAndKey("sig-signer");
        uint256 amount = 1 ether;

        weth.mint(signer, 10 ether);
        vm.warp(1000);
        uint256 expiredDeadline = block.timestamp - 1; // ya vencido

        LendingProtocol.SignatureData memory sig = _buildSig(
            pk,
            address(weth),
            amount,
            0,
            expiredDeadline
        );

        vm.startPrank(signer);
        weth.approve(address(lending), amount);
        vm.expectRevert("LendingProtocol: signature expired");
        lending.depositWithSignature(address(weth), amount, sig);
        vm.stopPrank();
    }

    // Construye el SignatureData firmando el mismo hash que arma el contrato.
    function _buildSig(
        uint256 pk,
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) internal pure returns (LendingProtocol.SignatureData memory) {
        bytes32 messageHash = keccak256(
            abi.encodePacked("deposit", token, amount, nonce, deadline)
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return
            LendingProtocol.SignatureData({
                nonce: nonce,
                deadline: deadline,
                signature: abi.encodePacked(r, s, v)
            });
    }

    // ---------------------------------------------------------------------
    // oráculo / health
    // ---------------------------------------------------------------------

    function testGetPriceReverts() public {
        MockToken noFeed = new MockToken("NoFeed", "NF", 18);
        vm.expectRevert("LendingProtocol: no price feed");
        lending.getPrice(address(noFeed));
    }

    function testGetPriceRevertsOnZeroPrice() public {
        wethFeed.setPrice(0); // un feed roto que reporta 0
        vm.expectRevert("LendingProtocol: invalid price");
        lending.getPrice(address(weth));
    }

    function testBecomesLiquidatableWhenPriceDrops() public {
        uint256 depositAmount = 10 ether; // $20k
        uint256 borrowAmount = 15_000e6; // $15k

        _depositWeth(borrower, depositAmount);
        vm.prank(borrower);
        lending.borrow(address(usdc), borrowAmount);

        assertFalse(lending.isLiquidatable(borrower)); // sano

        wethFeed.setPrice(ETH_PRICE_CRASHED); // ETH a la mitad

        assertTrue(lending.isLiquidatable(borrower)); // ahora liquidable
    }

    function testViewHelpersDirectly() public {
        uint256 depositAmount = 10 ether;
        uint256 borrowAmount = 5_000e6;

        _depositWeth(borrower, depositAmount);
        vm.prank(borrower);
        lending.borrow(address(usdc), borrowAmount);

        // llamadas directas (de afuera) a las view helpers
        assertTrue(lending.canWithdraw(borrower, address(weth), 1 ether));
        assertTrue(lending.canBorrow(borrower, address(usdc), 1_000e6));
        assertGt(lending.getCollateralRatio(borrower), 0);
    }

    // ---------------------------------------------------------------------
    // liquidate
    // ---------------------------------------------------------------------

    function testLiquidate() public {
        uint256 depositAmount = 10 ether; // $20k
        uint256 borrowAmount = 15_000e6; // $15k
        uint256 repayAmount = 1_000e6; // el liquidator repaga $1000
        // $1000 de deuda + 5% de penalidad = $1050, a $1000/ETH = 1.05 WETH
        uint256 expectedSeizedWeth = 1.05 ether;

        _depositWeth(borrower, depositAmount);
        vm.prank(borrower);
        lending.borrow(address(usdc), borrowAmount);

        wethFeed.setPrice(ETH_PRICE_CRASHED); // queda liquidable
        assertTrue(lending.isLiquidatable(borrower));

        usdc.mint(liquidator, repayAmount);
        vm.startPrank(liquidator);
        usdc.approve(address(lending), type(uint256).max);

        uint256 wethBefore = weth.balanceOf(liquidator);
        lending.liquidate(borrower, address(usdc), repayAmount);
        vm.stopPrank();

        // Liquidación rentable: recibe más valor del que pagó (la penalidad).
        assertEq(weth.balanceOf(liquidator) - wethBefore, expectedSeizedWeth);
        assertEq(
            lending.getUserBorrow(borrower, address(usdc)),
            borrowAmount - repayAmount
        );
        assertEq(
            lending.getUserDeposit(borrower, address(weth)),
            depositAmount - expectedSeizedWeth
        );
    }

    function testLiquidateRevertsIfHealthy() public {
        uint256 depositAmount = 10 ether;
        uint256 borrowAmount = 5_000e6; // sano, no liquidable
        uint256 repayAmount = 1_000e6;

        _depositWeth(borrower, depositAmount);
        vm.prank(borrower);
        lending.borrow(address(usdc), borrowAmount);

        usdc.mint(liquidator, repayAmount);
        vm.startPrank(liquidator);
        usdc.approve(address(lending), type(uint256).max);
        vm.expectRevert("LendingProtocol: cannot liquidate");
        lending.liquidate(borrower, address(usdc), repayAmount);
        vm.stopPrank();
    }

    function testLiquidateRevertsIfAmountExceedsDebt() public {
        uint256 depositAmount = 10 ether;
        uint256 borrowAmount = 5_000e6;
        uint256 overLiquidate = 6_000e6; // más que la deuda

        _depositWeth(borrower, depositAmount);
        vm.prank(borrower);
        lending.borrow(address(usdc), borrowAmount);

        usdc.mint(liquidator, POOL_LIQUIDITY);
        vm.startPrank(liquidator);
        usdc.approve(address(lending), type(uint256).max);
        vm.expectRevert("LendingProtocol: insufficient balance");
        lending.liquidate(borrower, address(usdc), overLiquidate);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // pause / emergencyRecover
    // ---------------------------------------------------------------------

    function testPauseBlocksDeposit() public {
        uint256 amount = 1 ether;

        lending.pause();

        vm.startPrank(borrower);
        weth.approve(address(lending), amount);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        lending.deposit(address(weth), amount);
        vm.stopPrank();
    }

    function testUnpause() public {
        uint256 amount = 1 ether;

        lending.pause();
        lending.unpause();

        // tras despausar, deposit vuelve a funcionar
        _depositWeth(borrower, amount);
        assertEq(lending.getUserDeposit(borrower, address(weth)), amount);
    }

    function testEmergencyRecover() public {
        uint256 strandedAmount = 5 ether; // tokens mandados por error

        weth.mint(address(lending), strandedAmount);

        uint256 balanceBefore = weth.balanceOf(address(this));
        lending.emergencyRecover(address(weth), address(this), strandedAmount);
        assertEq(
            weth.balanceOf(address(this)) - balanceBefore,
            strandedAmount
        );
    }

    function testEmergencyRecoverOnlyOwner() public {
        vm.prank(borrower);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                borrower
            )
        );
        lending.emergencyRecover(address(weth), borrower, 1 ether);
    }

    function testGetNonce() public view {
        assertEq(lending.getNonce(borrower), 0);
    }

    // ---------------------------------------------------------------------
    // active flag
    // ---------------------------------------------------------------------

    function testWithdrawAllClearsActiveFlag() public {
        uint256 depositAmount = 5 ether;

        _depositWeth(borrower, depositAmount);
        vm.prank(borrower);
        lending.withdraw(address(weth), depositAmount); // retira todo, sin deuda

        assertFalse(lending.getUser(borrower).isActive);
    }

    function testRepayAllClearsActiveFlag() public {
        uint256 depositAmount = 10 ether;
        uint256 borrowAmount = 5_000e6;

        _depositWeth(borrower, depositAmount);
        vm.startPrank(borrower);
        lending.borrow(address(usdc), borrowAmount);
        usdc.approve(address(lending), type(uint256).max);
        lending.repay(address(usdc), borrowAmount); // repaga todo
        vm.stopPrank();

        assertFalse(lending.getUser(borrower).isActive);
    }

    // El `require(amount_ > 0)` de cada operación que mueve fondos.
    function testAmountZeroReverts() public {
        uint256 depositAmount = 10 ether;
        string memory err = "LendingProtocol: amount must be greater than 0";

        _depositWeth(borrower, depositAmount);
        vm.startPrank(borrower);

        vm.expectRevert(bytes(err));
        lending.withdraw(address(weth), 0);

        vm.expectRevert(bytes(err));
        lending.borrow(address(usdc), 0);

        vm.expectRevert(bytes(err));
        lending.repay(address(usdc), 0);

        vm.expectRevert(bytes(err));
        lending.liquidate(borrower, address(usdc), 0);
        vm.stopPrank();
    }
}
