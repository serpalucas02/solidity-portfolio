// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/Calculadora.sol";

contract CalculadoraTest is Test {
    Calculadora calculadora;
    uint256 public resultado = 100;
    address public admin = vm.addr(1);
    address public randomUser = vm.addr(2);

    function setUp() public {
        calculadora = new Calculadora(resultado, admin);
    }

    // Unit Tests
    function testCheckResultado() public view {
        uint256 resultado_ = calculadora.resultado();
        assert(resultado_ == resultado);
    }

    function testAddition() public {
        uint256 a_ = 5;
        uint256 b_ = 10;

        uint256 resultado_ = calculadora.addition(a_, b_);

        assert(resultado_ == a_ + b_);
    }

    function testSubtraction() public {
        uint256 a_ = 15;
        uint256 b_ = 5;

        uint256 resultado_ = calculadora.subtraction(a_, b_);

        assert(resultado_ == a_ - b_);
    }

    function testMultiplication() public {
        uint256 a_ = 4;
        uint256 b_ = 6;

        uint256 resultado_ = calculadora.multiplication(a_, b_);

        assert(resultado_ == a_ * b_);
    }

    function testCanNotMultiply2LargeNumbers() public {
        uint256 a_ = type(uint256).max;
        uint256 b_ = 2;

        vm.expectRevert();
        calculadora.multiplication(a_, b_);
    }

    function testIfNotAdminCallsDivision() public {
        vm.startPrank(randomUser);

        uint256 a_ = 10;
        uint256 b_ = 2;
        vm.expectRevert();
        calculadora.division(a_, b_);

        vm.stopPrank();
    }

    function testAdminCanCallDivisonCorrectly() public {
        vm.startPrank(admin);

        uint256 a_ = 10;
        uint256 b_ = 2;
        calculadora.division(a_, b_);

        vm.stopPrank();
    }

    function testDefaultCanNotCallDivisionCorrectly() public {
        uint256 a_ = 10;
        uint256 b_ = 2;
        vm.expectRevert();
        calculadora.division(a_, b_);
    }

    function testDefaultExecutesCorrectly() public {
        vm.startPrank(admin);

        uint256 a_ = 10;
        uint256 b_ = 2;
        uint256 resultado_ = calculadora.division(a_, b_);
        assert(resultado_ == a_ / b_);

        vm.stopPrank();
    }

    function testCanNotDivideByZero() public {
        vm.startPrank(admin);

        uint256 a_ = 10;
        uint256 b_ = 0;
        vm.expectRevert();
        calculadora.division(a_, b_);

        vm.stopPrank();
    }

    // Fuzzing Tests
    function testFuzzingDivision(uint256 a_, uint256 b_) public {
        vm.assume(b_ != 0);

        vm.startPrank(admin);

        uint256 resultado_ = calculadora.division(a_, b_);
        assertEq(resultado_, a_ / b_);

        vm.stopPrank();
    }
}
