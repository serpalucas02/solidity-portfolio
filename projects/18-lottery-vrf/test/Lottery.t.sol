// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Lottery} from "../src/Lottery.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/// @dev Contrato ganador malicioso: compra un ticket pero RECHAZA ETH en su
///      receive. Sirve para probar que, con pull payments, un ganador así NO
///      puede trabar la lotería (el callback de VRF nunca falla por su culpa).
contract RejectingWinner {
    Lottery private immutable i_lottery;

    constructor(Lottery lottery_) {
        i_lottery = lottery_;
    }

    function buy(uint256 qty) external payable {
        i_lottery.buyTickets{value: msg.value}(qty);
    }

    function claim(uint256 roundId) external {
        i_lottery.claimPrize(roundId);
    }

    receive() external payable {
        revert("I reject ETH");
    }
}

contract LotteryTest is Test {
    Lottery internal lottery;
    VRFCoordinatorV2_5Mock internal vrfCoordinator;
    uint256 internal subscriptionId;

    // --- VRF mock config ---
    uint96 internal constant MOCK_BASE_FEE = 0.25 ether;
    uint96 internal constant MOCK_GAS_PRICE = 1e9;
    int256 internal constant MOCK_WEI_PER_UNIT_LINK = 4e15;
    uint256 internal constant SUB_FUND = 100 ether;

    // --- Lottery config ---
    bytes32 internal constant KEY_HASH = bytes32(uint256(1));
    uint32 internal constant CALLBACK_GAS_LIMIT = 500_000;
    uint256 internal constant TICKET_PRICE = 0.01 ether;
    uint256 internal constant ROUND_DURATION = 1 hours;
    uint256 internal constant MAX_TICKETS = 10;
    uint256 internal constant MIN_PLAYERS = 3;
    uint16 internal constant PROTOCOL_FEE_BPS = 500; // 5%
    uint256 internal constant BASIS_POINTS = 10_000;

    // --- Actors ---
    address internal owner = makeAddr("owner");
    address internal player1 = makeAddr("player1");
    address internal player2 = makeAddr("player2");
    address internal player3 = makeAddr("player3");

    function setUp() public {
        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE,
            MOCK_WEI_PER_UNIT_LINK
        );
        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, SUB_FUND);

        vm.prank(owner);
        lottery = new Lottery(
            address(vrfCoordinator),
            KEY_HASH,
            subscriptionId,
            CALLBACK_GAS_LIMIT,
            TICKET_PRICE,
            ROUND_DURATION,
            MAX_TICKETS,
            MIN_PLAYERS,
            PROTOCOL_FEE_BPS
        );

        // El consumer debe estar agregado a la subscription para pedir random
        vrfCoordinator.addConsumer(subscriptionId, address(lottery));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _startRound() internal {
        vm.prank(owner);
        lottery.startNewRound();
    }

    function _buy(address player, uint256 qty) internal {
        uint256 cost = TICKET_PRICE * qty;
        vm.deal(player, cost);
        vm.prank(player);
        lottery.buyTickets{value: cost}(qty);
    }

    // Devuelve un random word cuyo PRIMER intento cae en `targetIdx`, replicando
    // el cálculo de _selectUniqueWinners: keccak256(seed, attempt=0) % totalTickets.
    function _seedForIndex(
        uint256 targetIdx,
        uint256 totalTickets
    ) internal pure returns (uint256) {
        for (uint256 s; s < 100_000; ++s) {
            if (
                uint256(keccak256(abi.encode(s, uint256(0)))) % totalTickets ==
                targetIdx
            ) {
                return s;
            }
        }
        revert("seed not found");
    }

    function _fulfill(uint256 roundId, uint256[] memory words) internal {
        uint256 requestId = lottery.getRound(roundId).vrfRequestId;
        vrfCoordinator.fulfillRandomWordsWithOverride(
            requestId,
            address(lottery),
            words
        );
    }

    // Arranca ronda, compra 1 ticket cada player (índices 0,1,2) y cierra el draw
    // con los 3 jugadores ganando en orden. Deja la ronda 1 en CLOSED.
    function _runRoundWithThreeWinners() internal {
        _startRound();
        _buy(player1, 1);
        _buy(player2, 1);
        _buy(player3, 1);

        vm.warp(block.timestamp + ROUND_DURATION);
        lottery.requestDraw(1);

        uint256[] memory words = new uint256[](3);
        words[0] = _seedForIndex(0, 3);
        words[1] = _seedForIndex(1, 3);
        words[2] = _seedForIndex(2, 3);
        _fulfill(1, words);
    }

    // -------------------------------------------------------------------------
    // startNewRound
    // -------------------------------------------------------------------------

    function testStartNewRound() public {
        _startRound();

        Lottery.Round memory r = lottery.getRound(1);
        assertEq(lottery.getCurrentRoundId(), 1);
        assertEq(uint256(r.state), uint256(Lottery.RoundState.OPEN));
        assertEq(r.ticketPrice, TICKET_PRICE);
        assertEq(r.endTime, r.startTime + ROUND_DURATION);
    }

    function testStartNewRoundOnlyOwner() public {
        // onlyOwner viene de ConfirmedOwner (Chainlink), no de OZ Ownable
        vm.prank(player1);
        vm.expectRevert(bytes("Only callable by owner"));
        lottery.startNewRound();
    }

    function testStartNewRoundRevertsIfPreviousNotClosed() public {
        _startRound();
        vm.prank(owner);
        vm.expectRevert(Lottery.Lottery__PreviousRoundNotClosed.selector);
        lottery.startNewRound();
    }

    // -------------------------------------------------------------------------
    // buyTickets
    // -------------------------------------------------------------------------

    function testBuyTickets() public {
        _startRound();
        _buy(player1, 3);

        assertEq(lottery.getPlayerTickets(1, player1), 3);
        assertEq(lottery.getRoundPlayers(1).length, 3); // ponderado por ticket
        assertEq(lottery.getRoundUniquePlayers(1).length, 1);
        assertEq(lottery.getRound(1).prizePool, TICKET_PRICE * 3);
    }

    function testBuyTicketsRefundsExcess() public {
        _startRound();
        uint256 cost = TICKET_PRICE * 2;
        uint256 sent = cost + 0.005 ether; // de más
        vm.deal(player1, sent);

        vm.prank(player1);
        lottery.buyTickets{value: sent}(2);

        assertEq(player1.balance, sent - cost); // le devolvió el excedente
        assertEq(lottery.getRound(1).prizePool, cost);
    }

    function testBuyTicketsRevertsZeroTickets() public {
        _startRound();
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        vm.expectRevert(Lottery.Lottery__ZeroTickets.selector);
        lottery.buyTickets{value: 0}(0);
    }

    function testBuyTicketsRevertsInsufficientPayment() public {
        _startRound();
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__InsufficientPayment.selector,
                TICKET_PRICE,
                TICKET_PRICE * 2
            )
        );
        lottery.buyTickets{value: TICKET_PRICE}(2); // paga 1, pide 2
    }

    function testBuyTicketsRevertsMaxExceeded() public {
        _startRound();
        uint256 qty = MAX_TICKETS + 1;
        uint256 cost = TICKET_PRICE * qty;
        vm.deal(player1, cost);
        vm.prank(player1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__MaxTicketsExceeded.selector,
                qty,
                MAX_TICKETS
            )
        );
        lottery.buyTickets{value: cost}(qty);
    }

    function testBuyTicketsRevertsWhenRoundNotOpen() public {
        // sin startNewRound, la ronda 0 no está OPEN
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        vm.expectRevert(
            abi.encodeWithSelector(Lottery.Lottery__RoundNotOpen.selector, 0)
        );
        lottery.buyTickets{value: TICKET_PRICE}(1);
    }

    // -------------------------------------------------------------------------
    // requestDraw
    // -------------------------------------------------------------------------

    function testRequestDrawRevertsIfStillOpen() public {
        _startRound();
        _buy(player1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(Lottery.Lottery__RoundStillOpen.selector, 1)
        );
        lottery.requestDraw(1);
    }

    function testRequestDrawMovesToCalculating() public {
        _startRound();
        _buy(player1, 1);
        _buy(player2, 1);
        _buy(player3, 1);

        vm.warp(block.timestamp + ROUND_DURATION);
        lottery.requestDraw(1);

        assertEq(
            uint256(lottery.getRound(1).state),
            uint256(Lottery.RoundState.CALCULATING)
        );
        assertGt(lottery.getRound(1).vrfRequestId, 0);
    }

    function testRequestDrawRefundsWhenNotEnoughPlayers() public {
        _startRound();
        _buy(player1, 1);
        _buy(player2, 1); // solo 2 unique, minPlayers = 3

        vm.warp(block.timestamp + ROUND_DURATION);
        lottery.requestDraw(1);

        Lottery.Round memory r = lottery.getRound(1);
        assertEq(uint256(r.state), uint256(Lottery.RoundState.CLOSED));
        assertTrue(r.refunded);
    }

    // -------------------------------------------------------------------------
    // fulfillRandomWords (vía el mock) + claimPrize
    // -------------------------------------------------------------------------

    function testFulfillSelectsWinnersAndAssignsPrizes() public {
        _runRoundWithThreeWinners();

        uint256 pool = TICKET_PRICE * 3;
        uint256 fee = (pool * PROTOCOL_FEE_BPS) / BASIS_POINTS;
        uint256 dist = pool - fee;

        assertEq(
            uint256(lottery.getRound(1).state),
            uint256(Lottery.RoundState.CLOSED)
        );
        assertEq(lottery.getAccumulatedFees(), fee);

        uint256 first = (dist * 5000) / BASIS_POINTS;
        uint256 second = (dist * 3000) / BASIS_POINTS;
        uint256 third = dist - first - second;

        assertEq(lottery.getPrize(1, player1), first);
        assertEq(lottery.getPrize(1, player2), second);
        assertEq(lottery.getPrize(1, player3), third);
        // suma de premios = pozo distribuible (sin dust)
        assertEq(first + second + third, dist);
    }

    function testClaimPrize() public {
        _runRoundWithThreeWinners();

        uint256 prize = lottery.getPrize(1, player1);
        uint256 before = player1.balance;

        vm.prank(player1);
        lottery.claimPrize(1);

        assertEq(player1.balance - before, prize);
        assertEq(lottery.getPrize(1, player1), 0); // no se puede reclamar 2 veces
    }

    function testClaimPrizeRevertsIfNoPrize() public {
        _runRoundWithThreeWinners();
        vm.prank(makeAddr("nobody"));
        vm.expectRevert(Lottery.Lottery__NoPrizeToClaim.selector);
        lottery.claimPrize(1);
    }

    // -------------------------------------------------------------------------
    // EL test de seguridad: un ganador que rechaza ETH NO traba la lotería
    // -------------------------------------------------------------------------

    function testMaliciousWinnerCannotBrickLottery() public {
        _startRound();

        // El atacante (contrato que rechaza ETH) compra el ticket en el índice 0
        RejectingWinner attacker = new RejectingWinner(lottery);
        vm.deal(address(attacker), TICKET_PRICE);
        attacker.buy{value: TICKET_PRICE}(1);

        _buy(player2, 1);
        _buy(player3, 1);

        vm.warp(block.timestamp + ROUND_DURATION);
        lottery.requestDraw(1);

        uint256[] memory words = new uint256[](3);
        words[0] = _seedForIndex(0, 3); // el atacante gana el 1er premio
        words[1] = _seedForIndex(1, 3);
        words[2] = _seedForIndex(2, 3);

        // CLAVE: el callback NO revierte aunque gane el atacante (pull payments).
        // Con el push del profe, esta línea trabaría la ronda en CALCULATING.
        _fulfill(1, words);

        assertEq(
            uint256(lottery.getRound(1).state),
            uint256(Lottery.RoundState.CLOSED)
        );

        // Los ganadores honestos cobran sin problema
        vm.prank(player2);
        lottery.claimPrize(1);
        vm.prank(player3);
        lottery.claimPrize(1);

        // El atacante tiene premio asignado pero su propio receive le impide
        // cobrarlo — es SU problema, no traba a nadie.
        assertGt(lottery.getPrize(1, address(attacker)), 0);
        vm.expectRevert();
        attacker.claim(1);
    }

    // -------------------------------------------------------------------------
    // claimRefund
    // -------------------------------------------------------------------------

    function testClaimRefund() public {
        _startRound();
        _buy(player1, 2); // solo 1 unique player < minPlayers

        vm.warp(block.timestamp + ROUND_DURATION);
        lottery.requestDraw(1); // → refunded

        uint256 before = player1.balance;
        vm.prank(player1);
        lottery.claimRefund(1);

        assertEq(player1.balance - before, TICKET_PRICE * 2);
        assertEq(lottery.getPlayerTickets(1, player1), 0);
    }

    function testClaimRefundRevertsIfNotRefunded() public {
        _startRound();
        _buy(player1, 1);
        vm.prank(player1);
        vm.expectRevert(Lottery.Lottery__NoRefundAvailable.selector);
        lottery.claimRefund(1);
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    function testAdminSetters() public {
        vm.startPrank(owner);
        lottery.setTicketPrice(0.02 ether);
        lottery.setRoundDuration(2 hours);
        lottery.setMaxTicketsPerPlayer(5);
        lottery.setMinPlayers(2);
        lottery.setProtocolFee(800);
        vm.stopPrank();

        Lottery.LotteryConfig memory cfg = lottery.getConfig();
        assertEq(cfg.ticketPrice, 0.02 ether);
        assertEq(cfg.roundDuration, 2 hours);
        assertEq(cfg.maxTicketsPerPlayer, 5);
        assertEq(cfg.minPlayers, 2);
        assertEq(cfg.protocolFeeBps, 800);
    }

    function testSetProtocolFeeRevertsIfTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(Lottery.Lottery__InvalidProtocolFee.selector);
        lottery.setProtocolFee(1001); // > 1000 (10%)
    }

    function testAdminOnlyOwner() public {
        vm.prank(player1);
        vm.expectRevert(bytes("Only callable by owner"));
        lottery.setTicketPrice(0.02 ether);
    }

    // -------------------------------------------------------------------------
    // withdrawFees
    // -------------------------------------------------------------------------

    function testWithdrawFees() public {
        _runRoundWithThreeWinners();

        uint256 fees = lottery.getAccumulatedFees();
        assertGt(fees, 0);

        address treasury = makeAddr("treasury");
        vm.prank(owner);
        lottery.withdrawFees(treasury);

        assertEq(treasury.balance, fees);
        assertEq(lottery.getAccumulatedFees(), 0);
    }

    function testWithdrawFeesRevertsIfNothing() public {
        vm.prank(owner);
        vm.expectRevert(Lottery.Lottery__NothingToWithdraw.selector);
        lottery.withdrawFees(owner);
    }

    // -------------------------------------------------------------------------
    // Caminos de payout con 1 y 2 ganadores (cobertura de branches)
    // -------------------------------------------------------------------------

    function testFulfillWithOneWinner() public {
        vm.prank(owner);
        lottery.setMinPlayers(1);
        _startRound();
        _buy(player1, 1); // único jugador

        vm.warp(block.timestamp + ROUND_DURATION);
        lottery.requestDraw(1);

        uint256[] memory words = new uint256[](3); // totalTickets=1 → siempre idx 0
        _fulfill(1, words);

        uint256 dist = TICKET_PRICE -
            (TICKET_PRICE * PROTOCOL_FEE_BPS) /
            BASIS_POINTS;
        assertEq(lottery.getPrize(1, player1), dist); // se lleva todo
    }

    function testFulfillWithTwoWinners() public {
        vm.prank(owner);
        lottery.setMinPlayers(2);
        _startRound();
        _buy(player1, 1); // idx 0
        _buy(player2, 1); // idx 1

        vm.warp(block.timestamp + ROUND_DURATION);
        lottery.requestDraw(1);

        uint256[] memory words = new uint256[](3);
        words[0] = _seedForIndex(0, 2);
        words[1] = _seedForIndex(1, 2);
        _fulfill(1, words);

        uint256 pool = TICKET_PRICE * 2;
        uint256 dist = pool - (pool * PROTOCOL_FEE_BPS) / BASIS_POINTS;
        uint256 first = (dist * 6000) / BASIS_POINTS; // 60%

        assertEq(lottery.getPrize(1, player1), first);
        assertEq(lottery.getPrize(1, player2), dist - first); // 40% (remainder)
    }

    // -------------------------------------------------------------------------
    // Reverts de validación restantes (cobertura de branches)
    // -------------------------------------------------------------------------

    function testAdminSettersRevertOnZero() public {
        vm.startPrank(owner);

        vm.expectRevert(Lottery.Lottery__InvalidTicketPrice.selector);
        lottery.setTicketPrice(0);

        vm.expectRevert(Lottery.Lottery__InvalidRoundDuration.selector);
        lottery.setRoundDuration(0);

        vm.expectRevert(Lottery.Lottery__InvalidMaxTickets.selector);
        lottery.setMaxTicketsPerPlayer(0);

        vm.expectRevert(Lottery.Lottery__InvalidMinPlayers.selector);
        lottery.setMinPlayers(0);

        vm.stopPrank();
    }

    function testConstructorReverts() public {
        vm.expectRevert(Lottery.Lottery__InvalidTicketPrice.selector);
        new Lottery(address(vrfCoordinator), KEY_HASH, subscriptionId, CALLBACK_GAS_LIMIT, 0, ROUND_DURATION, MAX_TICKETS, MIN_PLAYERS, PROTOCOL_FEE_BPS);

        vm.expectRevert(Lottery.Lottery__InvalidRoundDuration.selector);
        new Lottery(address(vrfCoordinator), KEY_HASH, subscriptionId, CALLBACK_GAS_LIMIT, TICKET_PRICE, 0, MAX_TICKETS, MIN_PLAYERS, PROTOCOL_FEE_BPS);

        vm.expectRevert(Lottery.Lottery__InvalidMaxTickets.selector);
        new Lottery(address(vrfCoordinator), KEY_HASH, subscriptionId, CALLBACK_GAS_LIMIT, TICKET_PRICE, ROUND_DURATION, 0, MIN_PLAYERS, PROTOCOL_FEE_BPS);

        vm.expectRevert(Lottery.Lottery__InvalidMinPlayers.selector);
        new Lottery(address(vrfCoordinator), KEY_HASH, subscriptionId, CALLBACK_GAS_LIMIT, TICKET_PRICE, ROUND_DURATION, MAX_TICKETS, 0, PROTOCOL_FEE_BPS);

        vm.expectRevert(Lottery.Lottery__InvalidProtocolFee.selector);
        new Lottery(address(vrfCoordinator), KEY_HASH, subscriptionId, CALLBACK_GAS_LIMIT, TICKET_PRICE, ROUND_DURATION, MAX_TICKETS, MIN_PLAYERS, 1001);
    }

    // requestDraw sobre una ronda que no está OPEN (ya cerrada)
    function testRequestDrawRevertsIfNotOpen() public {
        _runRoundWithThreeWinners(); // ronda 1 queda CLOSED
        vm.expectRevert(
            abi.encodeWithSelector(Lottery.Lottery__RoundNotOpen.selector, 1)
        );
        lottery.requestDraw(1);
    }

    // Mismo seed en las 3 words → el selector colisiona y re-hashea hasta
    // encontrar ganadores únicos (cubre la rama de colisión + los getters).
    function testSelectWinnersHandlesCollision() public {
        _startRound();
        _buy(player1, 1);
        _buy(player2, 1);
        _buy(player3, 1);

        vm.warp(block.timestamp + ROUND_DURATION);
        lottery.requestDraw(1);

        uint256[] memory words = new uint256[](3);
        words[0] = 12345;
        words[1] = 12345; // colisiona con el primero → re-hash
        words[2] = 12345; // colisiona → re-hash
        _fulfill(1, words);

        // Aun con seeds repetidos, los 3 ganadores son ÚNICOS
        address[3] memory winners = lottery.getRoundWinners(1);
        assertTrue(winners[0] != winners[1]);
        assertTrue(winners[1] != winners[2]);
        assertTrue(winners[0] != winners[2]);

        uint256[3] memory payouts = lottery.getRoundPayouts(1);
        assertGt(payouts[0], payouts[1]); // 50% > 30%
        assertGt(payouts[1], payouts[2]); // 30% > 20%
    }
}
