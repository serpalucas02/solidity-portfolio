// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {DAO} from "../src/DAO.sol";
import {DAOGovernanceToken} from "../src/DAOGovernanceToken.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DAOTest is Test {
    DAOGovernanceToken public token;
    DAOTreasury public treasury;
    DAO public dao;

    // Roles — este test deploya todo, así que es el owner del DAO/treasury/token.
    address public alice = makeAddr("alice"); // 100e18 tokens
    address public bob = makeAddr("bob"); // 200e18 tokens
    address public carol = makeAddr("carol"); // 0 tokens (para reverts de "sin poder de voto")
    address public recipient = makeAddr("recipient");

    uint256 public constant THRESHOLD = 10e18; // mínimo para proponer
    uint256 public constant VOTING_PERIOD = 3 days; // duración de la votación
    uint256 public constant QUORUM = 100e18; // votos mínimos (for + against)
    uint256 public constant PAYOUT = 1 ether; // lo que paga la propuesta de ejemplo (en ETH)

    // Re-declaramos el evento para poder usarlo con vm.expectEmit.
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votes
    );

    function setUp() public {
        token = new DAOGovernanceToken("DAO Governance Token", "DGT", 0);

        // Dependencia circular treasury <-> dao: creo el treasury con dao=0 y lo seteo después.
        treasury = new DAOTreasury(address(0));
        dao = new DAO(
            address(token),
            address(treasury),
            THRESHOLD,
            VOTING_PERIOD,
            QUORUM
        );
        treasury.setDAO(address(dao));

        // Poder de voto = balanceOf, así que repartir tokens = repartir votos.
        token.mint(alice, 100e18);
        token.mint(bob, 200e18);

        // Fondeo el treasury para que executeProposal pueda pagar.
        vm.deal(address(treasury), 100 ether);
    }

    // Helper: una propuesta estándar creada por alice (que pasa el threshold).
    function _createProposalByAlice() internal returns (uint256 id) {
        vm.prank(alice);
        id = dao.createProposal(
            "Fund the recipient",
            recipient,
            PAYOUT,
            address(0)
        );
    }

    // ---------------------------------------------------------------
    // createProposal
    // ---------------------------------------------------------------

    function testCreateProposal() public {
        uint256 id = _createProposalByAlice();

        assertEq(id, 0, "First proposal id should be 0");
        assertEq(dao.proposalCount(), 1, "proposalCount should be 1");

        (
            address proposer,
            ,
            ,
            ,
            ,
            ,
            ,
            bool canceled,
            address rcpt,
            uint256 amount,

        ) = dao.getProposal(id);
        assertEq(proposer, alice, "Proposer should be alice");
        assertEq(rcpt, recipient, "Recipient should match");
        assertEq(amount, PAYOUT, "Amount should match");
        assertFalse(canceled, "Should not be canceled");
    }

    function testCreateProposalRevertsBelowThreshold() public {
        vm.prank(carol); // carol tiene 0 tokens
        vm.expectRevert("DAO: proposer votes below proposal threshold");
        dao.createProposal("x", recipient, PAYOUT, address(0));
    }

    function testCreateProposalRevertsEmptyDescription() public {
        vm.prank(alice);
        vm.expectRevert("DAO: description is empty");
        dao.createProposal("", recipient, PAYOUT, address(0));
    }

    function testCreateProposalRevertsAmountZero() public {
        vm.prank(alice);
        vm.expectRevert("DAO: amount must be greater than 0");
        dao.createProposal("x", recipient, 0, address(0));
    }

    function testCreateProposalRevertsRecipientZero() public {
        vm.prank(alice);
        vm.expectRevert("DAO: recipient is zero");
        dao.createProposal("x", address(0), PAYOUT, address(0));
    }

    // ---------------------------------------------------------------
    // vote
    // ---------------------------------------------------------------

    function testVoteFor() public {
        uint256 id = _createProposalByAlice();

        // Demostración de vm.expectEmit: chequeamos que se emita el evento Voted correcto.
        // Args: (checkTopic1, checkTopic2, checkTopic3, checkData, emitter)
        vm.expectEmit(true, true, false, true, address(dao));
        emit Voted(id, bob, true, 200e18);

        vm.prank(bob);
        dao.vote(id, true);

        (, , uint256 forVotes, uint256 againstVotes, , , , , , , ) = dao
            .getProposal(id);
        assertEq(forVotes, 200e18, "forVotes should equal bob's balance");
        assertEq(againstVotes, 0, "againstVotes should be zero");

        (bool hasVoted, bool support) = dao.getVoteInfo(id, bob);
        assertTrue(hasVoted, "bob should be marked as voted");
        assertTrue(support, "bob's vote should be 'for'");
    }

    function testVoteAgainst() public {
        uint256 id = _createProposalByAlice();

        vm.prank(alice);
        dao.vote(id, false);

        (, , uint256 forVotes, uint256 againstVotes, , , , , , , ) = dao
            .getProposal(id);
        assertEq(forVotes, 0, "forVotes should be zero");
        assertEq(
            againstVotes,
            100e18,
            "againstVotes should equal alice's balance"
        );
    }

    function testVoteRevertsProposalNotFound() public {
        vm.prank(bob);
        vm.expectRevert("DAO: proposal not found");
        dao.vote(999, true);
    }

    function testVoteRevertsAfterVotingEnded() public {
        uint256 id = _createProposalByAlice();

        vm.warp(block.timestamp + VOTING_PERIOD + 1); // el reloj salta más allá del endTime

        vm.prank(bob);
        vm.expectRevert("DAO: voting period has ended");
        dao.vote(id, true);
    }

    function testVoteRevertsDoubleVote() public {
        uint256 id = _createProposalByAlice();

        vm.prank(bob);
        dao.vote(id, true);

        vm.prank(bob);
        vm.expectRevert("DAO: voter already voted");
        dao.vote(id, true);
    }

    function testVoteRevertsNoVotingPower() public {
        uint256 id = _createProposalByAlice();

        vm.prank(carol); // 0 tokens
        vm.expectRevert("DAO: voter has no voting power");
        dao.vote(id, true);
    }

    // ---------------------------------------------------------------
    // cancelProposal
    // ---------------------------------------------------------------

    function testCancelByProposer() public {
        uint256 id = _createProposalByAlice();

        vm.prank(alice);
        dao.cancelProposal(id);

        (, , , , , , , bool canceled, , , ) = dao.getProposal(id);
        assertTrue(canceled, "Proposal should be canceled by its proposer");
    }

    function testCancelByOwner() public {
        uint256 id = _createProposalByAlice();

        // El owner del DAO (este test) puede cancelar una propuesta ajena.
        dao.cancelProposal(id);

        (, , , , , , , bool canceled, , , ) = dao.getProposal(id);
        assertTrue(canceled, "Proposal should be canceled by the owner");
    }

    function testCancelRevertsUnauthorized() public {
        uint256 id = _createProposalByAlice();

        vm.prank(bob); // ni proposer ni owner
        vm.expectRevert("DAO: only proposer or owner can cancel");
        dao.cancelProposal(id);
    }

    // ---------------------------------------------------------------
    // executeProposal (integración: DAO -> Treasury -> recipient)
    // ---------------------------------------------------------------

    function testExecuteProposalPaysRecipient() public {
        uint256 id = _createProposalByAlice();

        vm.prank(bob);
        dao.vote(id, true); // 200e18 a favor: supera quórum (100e18) y mayoría

        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        uint256 balanceBefore = recipient.balance;
        dao.executeProposal(id);

        // Lo que importa: la plata SALIÓ del treasury y LLEGÓ al recipient.
        assertEq(
            recipient.balance,
            balanceBefore + PAYOUT,
            "Recipient should receive the payout"
        );

        (, , , , , , bool executed, , , , ) = dao.getProposal(id);
        assertTrue(executed, "Proposal should be marked executed");
    }

    function testExecuteRevertsVotingNotEnded() public {
        uint256 id = _createProposalByAlice();

        vm.prank(bob);
        dao.vote(id, true);

        // Sin warp: la votación sigue abierta.
        vm.expectRevert("DAO: voting not ended");
        dao.executeProposal(id);
    }

    function testExecuteRevertsNoQuorum() public {
        uint256 id = _createProposalByAlice();

        // Nadie vota -> forVotes + againstVotes = 0 < QUORUM.
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.expectRevert("DAO: no quorum");
        dao.executeProposal(id);
    }

    function testExecuteRevertsNoMajority() public {
        uint256 id = _createProposalByAlice();

        vm.prank(alice);
        dao.vote(id, true); // 100e18 a favor
        vm.prank(bob);
        dao.vote(id, false); // 200e18 en contra -> hay quórum (300e18) pero NO mayoría

        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.expectRevert("DAO: no majority");
        dao.executeProposal(id);
    }

    function testExecuteRevertsAlreadyExecuted() public {
        uint256 id = _createProposalByAlice();

        vm.prank(bob);
        dao.vote(id, true);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        dao.executeProposal(id);

        vm.expectRevert("DAO: proposal already executed");
        dao.executeProposal(id);
    }

    // ---------------------------------------------------------------
    // ⚠️ Caveat de seguridad: doble voto reusando los mismos tokens
    // ---------------------------------------------------------------

    function testDoubleVoteByTransferringTokens() public {
        uint256 id = _createProposalByAlice();

        // 1) alice vota con sus 100e18.
        vm.prank(alice);
        dao.vote(id, true);

        // 2) alice transfiere ESOS MISMOS tokens a carol.
        vm.prank(alice);
        token.transfer(carol, 100e18);

        // 3) carol vota con los mismos tokens (el hasVoted es por-address, no por-token).
        vm.prank(carol);
        dao.vote(id, true);

        (, , uint256 forVotes, , , , , , , , ) = dao.getProposal(id);
        // 100e18 de tokens contaron 200e18 de votos: ESTE es el motivo por el que la
        // governance real usa snapshots (ERC20Votes con checkpoints al bloque de la propuesta).
        assertEq(
            forVotes,
            200e18,
            "Same tokens were counted twice (no snapshot)"
        );
    }

    // ---------------------------------------------------------------
    // Branches restantes: vote/cancel/execute sobre propuestas canceladas/inexistentes
    // ---------------------------------------------------------------

    function testVoteRevertsCanceled() public {
        uint256 id = _createProposalByAlice();
        vm.prank(alice);
        dao.cancelProposal(id);

        vm.prank(bob);
        vm.expectRevert("DAO: proposal canceled");
        dao.vote(id, true);
    }

    function testCancelRevertsNotFound() public {
        vm.expectRevert("DAO: proposal not found");
        dao.cancelProposal(999);
    }

    function testCancelRevertsAlreadyCanceled() public {
        uint256 id = _createProposalByAlice();
        vm.prank(alice);
        dao.cancelProposal(id);

        vm.prank(alice);
        vm.expectRevert("DAO: proposal already canceled");
        dao.cancelProposal(id);
    }

    function testCancelRevertsExecuted() public {
        uint256 id = _createProposalByAlice();
        vm.prank(bob);
        dao.vote(id, true);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        dao.executeProposal(id);

        vm.expectRevert("DAO: proposal executed");
        dao.cancelProposal(id);
    }

    function testExecuteRevertsProposalNotFound() public {
        vm.expectRevert("DAO: proposal not found");
        dao.executeProposal(999);
    }

    function testExecuteRevertsCanceled() public {
        uint256 id = _createProposalByAlice();
        vm.prank(alice);
        dao.cancelProposal(id);
        vm.warp(block.timestamp + VOTING_PERIOD + 1); // pasa el endTime para llegar al check de canceled

        vm.expectRevert("DAO: proposal canceled");
        dao.executeProposal(id);
    }

    // ---------------------------------------------------------------
    // proposalPassed (view)
    // ---------------------------------------------------------------

    function testProposalPassedReturnsTrue() public {
        uint256 id = _createProposalByAlice();
        vm.prank(bob);
        dao.vote(id, true); // 200e18 a favor -> quórum + mayoría
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        assertTrue(
            dao.proposalPassed(id),
            "Should pass with quorum + majority"
        );
    }

    function testProposalPassedReturnsFalse() public {
        uint256 id = _createProposalByAlice();
        vm.prank(alice);
        dao.vote(id, true); // 100e18 a favor
        vm.prank(bob);
        dao.vote(id, false); // 200e18 en contra -> hay quórum pero gana el "against"
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        assertFalse(
            dao.proposalPassed(id),
            "Should not pass when 'against' wins"
        );
    }

    // ---------------------------------------------------------------
    // updateConfiguration / setTreasury (onlyOwner)
    // ---------------------------------------------------------------

    function testUpdateConfiguration() public {
        dao.updateConfiguration(20e18, 7 days, 200e18);

        assertEq(dao.proposalThreshold(), 20e18, "threshold updated");
        assertEq(dao.votingPeriod(), 7 days, "votingPeriod updated");
        assertEq(dao.quorumVotes(), 200e18, "quorum updated");
    }

    function testUpdateConfigurationRevertsNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        dao.updateConfiguration(1, 1, 1);
    }

    function testSetTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        dao.setTreasury(newTreasury);
        assertEq(
            address(dao.treasury()),
            newTreasury,
            "treasury should be updated"
        );
    }

    function testSetTreasuryRevertsZero() public {
        vm.expectRevert("DAO: treasury is zero");
        dao.setTreasury(address(0));
    }

    function testSetTreasuryRevertsNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        dao.setTreasury(makeAddr("x"));
    }

    // --- proposalPassed: ramas de revert (mismas guardas que executeProposal) ---

    function testProposalPassedRevertsNotFound() public {
        vm.expectRevert("DAO: proposal not found");
        dao.proposalPassed(999);
    }

    function testProposalPassedRevertsVotingNotEnded() public {
        uint256 id = _createProposalByAlice();
        vm.prank(bob);
        dao.vote(id, true);

        vm.expectRevert("DAO: voting not ended");
        dao.proposalPassed(id);
    }

    function testProposalPassedRevertsAlreadyExecuted() public {
        uint256 id = _createProposalByAlice();
        vm.prank(bob);
        dao.vote(id, true);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        dao.executeProposal(id);

        vm.expectRevert("DAO: proposal already executed");
        dao.proposalPassed(id);
    }

    function testProposalPassedRevertsCanceled() public {
        uint256 id = _createProposalByAlice();
        vm.prank(alice);
        dao.cancelProposal(id);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.expectRevert("DAO: proposal canceled");
        dao.proposalPassed(id);
    }

    function testProposalPassedRevertsNoQuorum() public {
        uint256 id = _createProposalByAlice();
        vm.warp(block.timestamp + VOTING_PERIOD + 1); // nadie votó

        vm.expectRevert("DAO: no quorum");
        dao.proposalPassed(id);
    }
}
