// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleBank} from "../src/SimpleBank.sol";
import {Attacker} from "../src/Attacker.sol";

contract ReentrancyTest is Test {
    SimpleBank internal bank;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal eve = makeAddr("eve"); // la atacante

    function setUp() public {
        bank = new SimpleBank();

        // Dos usuarios honestos depositan 5 ETH cada uno → el banco tiene 10 ETH.
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);

        vm.prank(alice);
        bank.deposit{value: 5 ether}();

        vm.prank(bob);
        bank.deposit{value: 5 ether}();
    }

    /// @notice Flujo honesto: un usuario solo puede retirar lo que depositó.
    function testHonestWithdrawReturnsOwnDeposit() public {
        assertEq(bank.totalBalance(), 10 ether);

        uint256 before = alice.balance;
        vm.prank(alice);
        bank.withdraw();

        assertEq(alice.balance, before + 5 ether);
        assertEq(bank.userBalance(alice), 0);
        assertEq(bank.totalBalance(), 5 ether); // queda lo de bob
    }

    /// @notice El ataque: Eve deposita 1 ETH y dren­a TODO el banco vía reentrancy.
    function testReentrancyDrainsTheBank() public {
        assertEq(
            bank.totalBalance(),
            10 ether,
            "banco arranca con 10 ETH ajenos"
        );

        // Eve despliega el Attacker y lo financia con 1 ETH.
        vm.deal(eve, 1 ether);
        vm.startPrank(eve);
        Attacker attacker = new Attacker(address(bank));
        attacker.attack{value: 1 ether}();
        vm.stopPrank();

        // El banco queda seco...
        assertEq(bank.totalBalance(), 0, "el banco fue drenado por completo");

        // ...y los 11 ETH (10 de las victimas + 1 propio) terminan en el Attacker.
        assertEq(address(attacker).balance, 11 ether, "Eve se llevo todo");
    }
}
