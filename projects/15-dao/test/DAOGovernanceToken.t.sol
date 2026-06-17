// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {DAOGovernanceToken} from "../src/DAOGovernanceToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DAOGovernanceTokenTest is Test {
    DAOGovernanceToken public token;

    address public owner = address(this); // el test deploya el token -> es el owner
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public nonOwner = makeAddr("nonOwner");

    uint256 public constant INITIAL_SUPPLY = 0;

    function setUp() public {
        token = new DAOGovernanceToken(
            "DAO Governance Token",
            "DGT",
            INITIAL_SUPPLY
        );
    }

    // --- supply / mint / burn ---

    function testInitialSupply() public view {
        assertEq(
            token.totalSupply(),
            INITIAL_SUPPLY,
            "Initial supply should be zero"
        );
    }

    function testMinting() public {
        uint256 amount = 1000e18;

        token.mint(alice, amount);

        assertEq(
            token.balanceOf(alice),
            amount,
            "Recipient should have the minted amount"
        );
        assertEq(
            token.totalSupply(),
            amount,
            "Total supply should grow by the minted amount"
        );
    }

    function testBurn() public {
        uint256 amount = 1000e18;

        // burn() quema de msg.sender (el owner), así que minteamos al owner (este test) y no a un tercero.
        token.mint(owner, amount);
        token.burn(amount);

        assertEq(
            token.balanceOf(owner),
            0,
            "Owner balance should be zero after burning all"
        );
        assertEq(
            token.totalSupply(),
            0,
            "Total supply should be zero after burning all"
        );
    }

    function testGetVotingPowerEqualsBalance() public {
        uint256 amount = 500e18;
        token.mint(alice, amount);

        // El núcleo de este DAO: el poder de voto es, literalmente, el balance actual (sin snapshot).
        assertEq(
            token.getVotingPower(alice),
            token.balanceOf(alice),
            "Voting power must equal balance"
        );
        assertEq(
            token.getVotingPower(alice),
            amount,
            "Voting power should equal the minted amount"
        );
    }

    // --- access control (onlyOwner) ---

    function testMintRevertsIfNotOwner() public {
        // OZ v5 usa custom errors: OwnableUnauthorizedAccount(address).
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        vm.prank(nonOwner);
        token.mint(nonOwner, 1e18);
    }

    function testBurnRevertsIfNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        vm.prank(nonOwner);
        token.burn(1e18);
    }

    // --- delegación (ojo: en este token "delegar" TRANSFIERE los tokens al delegado) ---

    function testDelegateVotingPower() public {
        token.mint(alice, 100e18);

        vm.prank(alice);
        token.delegateVotingPower(bob, 40e18);

        // Los tokens se movieron de alice a bob...
        assertEq(
            token.balanceOf(alice),
            60e18,
            "Delegator balance should decrease"
        );
        assertEq(
            token.balanceOf(bob),
            40e18,
            "Delegatee balance should increase"
        );
        // ...y se registró la delegación.
        assertEq(
            token.delegatedVotes(bob),
            40e18,
            "delegatedVotes should track the amount"
        );
        assertEq(
            token.delegates(alice),
            bob,
            "delegates mapping should point to bob"
        );
        assertTrue(token.hasDelegated(alice), "hasDelegated should be true");
    }

    function testDelegateRevertsZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert("DAOGovernanceToken: delegate is zero");
        token.delegateVotingPower(address(0), 1e18);
    }

    function testDelegateRevertsToSelf() public {
        vm.prank(alice);
        vm.expectRevert("DAOGovernanceToken: cannot delegate to self");
        token.delegateVotingPower(alice, 1e18);
    }

    function testDelegateRevertsAmountZero() public {
        vm.prank(alice);
        vm.expectRevert("DAOGovernanceToken: amount must be greater than 0");
        token.delegateVotingPower(bob, 0);
    }

    function testDelegateRevertsExceedsBalance() public {
        token.mint(alice, 100e18);

        vm.prank(alice);
        vm.expectRevert("DAOGovernanceToken: amount exceeds balance");
        token.delegateVotingPower(bob, 101e18);
    }

    function testUndelegateVotingPower() public {
        token.mint(alice, 100e18);

        vm.prank(alice);
        token.delegateVotingPower(bob, 40e18);

        vm.prank(alice);
        token.undelegateVotingPower(40e18);

        // Los tokens volvieron y la delegación quedó limpia.
        assertEq(
            token.balanceOf(alice),
            100e18,
            "Tokens should return to the delegator"
        );
        assertEq(token.balanceOf(bob), 0, "Delegatee should have nothing back");
        assertEq(token.delegatedVotes(bob), 0, "delegatedVotes should be zero");
        assertFalse(token.hasDelegated(alice), "hasDelegated should be reset");
        assertEq(
            token.delegates(alice),
            address(0),
            "delegate should be cleared"
        );
    }

    function testUndelegateRevertsNoDelegation() public {
        vm.prank(alice);
        vm.expectRevert("DAOGovernanceToken: delegation not found");
        token.undelegateVotingPower(1e18);
    }

    function testUndelegatePartial() public {
        token.mint(alice, 100e18);

        vm.prank(alice);
        token.delegateVotingPower(bob, 40e18);

        vm.prank(alice);
        token.undelegateVotingPower(20e18); // devuelve solo la mitad

        // Cubre el camino "queda delegación remanente" (delegatedVotes != 0 -> no se limpia el estado).
        assertEq(
            token.balanceOf(alice),
            80e18,
            "Half should return to the delegator"
        );
        assertEq(token.balanceOf(bob), 20e18, "Delegatee keeps the remainder");
        assertEq(
            token.delegatedVotes(bob),
            20e18,
            "delegatedVotes should be the remainder"
        );
        assertTrue(
            token.hasDelegated(alice),
            "Still delegated (partial undelegation)"
        );
        assertEq(token.delegates(alice), bob, "delegate should still be set");
    }

    function testUndelegateRevertsAmountZero() public {
        token.mint(alice, 100e18);
        vm.prank(alice);
        token.delegateVotingPower(bob, 40e18);

        vm.prank(alice);
        vm.expectRevert("DAOGovernanceToken: amount must be greater than 0");
        token.undelegateVotingPower(0);
    }

    function testUndelegateRevertsExceedsDelegation() public {
        token.mint(alice, 100e18);
        vm.prank(alice);
        token.delegateVotingPower(bob, 40e18);

        vm.prank(alice);
        vm.expectRevert("DAOGovernanceToken: amount exceeds delegation");
        token.undelegateVotingPower(50e18);
    }
}
