// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";
import {DAOGovernanceToken} from "../src/DAOGovernanceToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DAOTreasuryTest is Test {
    DAOTreasury public treasury;
    DAOGovernanceToken public token; // usamos el token de governance como ERC-20 de prueba

    // El treasury solo acepta approveProposal/spendFunds desde "el DAO".
    // Truco: hacemos que ESTE test sea el DAO (dao = address(this)), así llamamos
    // esas funciones directo y prankeamos a otra address para los reverts "not dao".
    address public notDao = makeAddr("notDao");
    address public recipient = makeAddr("recipient");

    uint256 public constant TREASURY_ETH = 100 ether;
    uint256 public constant TREASURY_TOKENS = 1_000e18;

    function setUp() public {
        token = new DAOGovernanceToken("Test Token", "TT", 0);

        treasury = new DAOTreasury(address(this)); // dao = este test
        token.mint(address(treasury), TREASURY_TOKENS);
        vm.deal(address(treasury), TREASURY_ETH);
    }

    // ---------------------------------------------------------------
    // fondeo
    // ---------------------------------------------------------------

    function testFundTreasuryETH() public {
        vm.deal(address(this), 1 ether);
        treasury.fundTreasury{value: 1 ether}();
        assertEq(
            address(treasury).balance,
            TREASURY_ETH + 1 ether,
            "ETH balance should grow"
        );
    }

    function testFundTreasuryWithToken() public {
        token.mint(address(this), 50e18);
        token.approve(address(treasury), 50e18); // el treasury hace transferFrom
        treasury.fundTreasuryWithToken(address(token), 50e18);
        assertEq(
            token.balanceOf(address(treasury)),
            TREASURY_TOKENS + 50e18,
            "Token balance should grow"
        );
    }

    function testReceiveETH() public {
        vm.deal(address(this), 1 ether);
        (bool ok, ) = address(treasury).call{value: 1 ether}(""); // call vacío -> dispara receive()
        assertTrue(ok, "Plain ETH transfer should succeed via receive()");
        assertEq(
            address(treasury).balance,
            TREASURY_ETH + 1 ether,
            "ETH balance should grow"
        );
    }

    // ---------------------------------------------------------------
    // approveProposal / spendFunds (solo el DAO)
    // ---------------------------------------------------------------

    function testApproveProposalRevertsNotDAO() public {
        vm.prank(notDao);
        vm.expectRevert("DAOTreasury: not dao");
        treasury.approveProposal(1);
    }

    function testSpendFundsERC20() public {
        treasury.approveProposal(1); // como dao (este test)

        uint256 before = token.balanceOf(recipient);
        treasury.spendFunds(1, recipient, 100e18, address(token));

        assertEq(
            token.balanceOf(recipient),
            before + 100e18,
            "Recipient should receive the tokens"
        );
        assertTrue(
            treasury.executedProposals(1),
            "Proposal should be marked executed"
        );
    }

    function testSpendFundsETH() public {
        treasury.approveProposal(2);

        uint256 before = recipient.balance;
        treasury.spendFunds(2, recipient, 1 ether, address(0)); // token == address(0) -> ETH

        assertEq(
            recipient.balance,
            before + 1 ether,
            "Recipient should receive the ETH"
        );
    }

    function testSpendFundsRevertsNotApproved() public {
        vm.expectRevert("DAOTreasury: proposal not approved");
        treasury.spendFunds(99, recipient, 1e18, address(token)); // nunca se aprobó
    }

    function testSpendFundsRevertsNotDAO() public {
        vm.prank(notDao);
        vm.expectRevert("DAOTreasury: not dao");
        treasury.spendFunds(1, recipient, 1e18, address(token));
    }

    function testSpendFundsRevertsAlreadyExecuted() public {
        treasury.approveProposal(3);
        treasury.spendFunds(3, recipient, 1e18, address(token));

        vm.expectRevert("DAOTreasury: proposal already executed");
        treasury.spendFunds(3, recipient, 1e18, address(token));
    }

    // ---------------------------------------------------------------
    // emergencyWithdraw (onlyOwner)
    // ---------------------------------------------------------------

    function testEmergencyWithdrawETH() public {
        uint256 before = recipient.balance;
        treasury.emergencyWithdraw(address(0), 1 ether, recipient);

        assertEq(
            recipient.balance,
            before + 1 ether,
            "Recipient should receive the ETH"
        );
        assertEq(
            address(treasury).balance,
            TREASURY_ETH - 1 ether,
            "Treasury ETH should decrease"
        );
    }

    function testEmergencyWithdrawERC20() public {
        uint256 before = token.balanceOf(recipient);
        treasury.emergencyWithdraw(address(token), 100e18, recipient);

        assertEq(
            token.balanceOf(recipient),
            before + 100e18,
            "Recipient should receive the tokens"
        );
    }

    function testEmergencyWithdrawRevertsNotOwner() public {
        vm.prank(notDao);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                notDao
            )
        );
        treasury.emergencyWithdraw(address(0), 1 ether, recipient);
    }

    // ---------------------------------------------------------------
    // Branches restantes: validaciones de fondeo / approve / spend / withdraw
    // ---------------------------------------------------------------

    function testFundTreasuryRevertsZeroValue() public {
        vm.expectRevert("DAOTreasury: amount must be greater than 0");
        treasury.fundTreasury{value: 0}();
    }

    function testFundTreasuryWithTokenRevertsZeroToken() public {
        vm.expectRevert("DAOTreasury: token is zero");
        treasury.fundTreasuryWithToken(address(0), 1e18);
    }

    function testFundTreasuryWithTokenRevertsZeroAmount() public {
        vm.expectRevert("DAOTreasury: amount must be greater than 0");
        treasury.fundTreasuryWithToken(address(token), 0);
    }

    function testApproveProposalRevertsAlreadyApproved() public {
        treasury.approveProposal(1);
        vm.expectRevert("DAOTreasury: proposal already approved");
        treasury.approveProposal(1);
    }

    function testSpendFundsRevertsAmountZero() public {
        treasury.approveProposal(1);
        vm.expectRevert("DAOTreasury: amount must be greater than 0");
        treasury.spendFunds(1, recipient, 0, address(token));
    }

    function testSpendFundsRevertsRecipientZero() public {
        treasury.approveProposal(1);
        vm.expectRevert("DAOTreasury: recipient is zero");
        treasury.spendFunds(1, address(0), 1e18, address(token));
    }

    function testSpendFundsRevertsInsufficientBalance() public {
        treasury.approveProposal(1);
        vm.expectRevert("DAOTreasury: insufficient balance");
        treasury.spendFunds(1, recipient, TREASURY_TOKENS + 1, address(token));
    }

    function testSpendFundsRevertsFailedETHSend() public {
        // Recipient que rechaza ETH -> fuerza el require(success) en falso.
        RejectETH rejecter = new RejectETH();
        treasury.approveProposal(1);
        vm.expectRevert("DAOTreasury: failed to send ETH");
        treasury.spendFunds(1, address(rejecter), 1 ether, address(0));
    }

    function testEmergencyWithdrawRevertsAmountZero() public {
        vm.expectRevert("DAOTreasury: amount must be greater than 0");
        treasury.emergencyWithdraw(address(0), 0, recipient);
    }

    function testEmergencyWithdrawRevertsRecipientZero() public {
        vm.expectRevert("DAOTreasury: recipient is zero");
        treasury.emergencyWithdraw(address(0), 1 ether, address(0));
    }

    function testEmergencyWithdrawRevertsInsufficientBalance() public {
        vm.expectRevert("DAOTreasury: insufficient balance");
        treasury.emergencyWithdraw(
            address(token),
            TREASURY_TOKENS + 1,
            recipient
        );
    }

    // --- setDAO (onlyOwner) ---

    function testSetDAO() public {
        address newDao = makeAddr("newDao");
        treasury.setDAO(newDao);
        assertEq(address(treasury.dao()), newDao, "dao should be updated");
    }

    function testSetDAORevertsZero() public {
        vm.expectRevert("DAOTreasury: dao is zero");
        treasury.setDAO(address(0));
    }

    function testSetDAORevertsNotOwner() public {
        vm.prank(notDao);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                notDao
            )
        );
        treasury.setDAO(makeAddr("x"));
    }

    // --- ramas ETH restantes (camino token == address(0)) ---

    function testSpendFundsRevertsInsufficientETH() public {
        treasury.approveProposal(1);
        vm.expectRevert("DAOTreasury: insufficient balance");
        treasury.spendFunds(1, recipient, TREASURY_ETH + 1, address(0));
    }

    function testEmergencyWithdrawRevertsInsufficientETH() public {
        vm.expectRevert("DAOTreasury: insufficient balance");
        treasury.emergencyWithdraw(address(0), TREASURY_ETH + 1, recipient);
    }

    function testEmergencyWithdrawRevertsFailedETHSend() public {
        RejectETH rejecter = new RejectETH();
        vm.expectRevert("DAOTreasury: failed to send ETH");
        treasury.emergencyWithdraw(address(0), 1 ether, address(rejecter));
    }
}

// Contrato sin receive/fallback payable: rechaza ETH -> hace fallar el envío en el treasury.
contract RejectETH {}
