// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract Calculadora {
    // Variables
    uint256 public resultado;
    address public admin;

    // Events
    event Addition(uint256 a_, uint256 b_, uint256 resultado_);
    event Subtraction(uint256 a_, uint256 b_, uint256 resultado_);
    event Multiplication(uint256 a_, uint256 b_, uint256 resultado_);
    event Division(uint256 a_, uint256 b_, uint256 resultado_);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    constructor(uint256 resultado_, address admin_) {
        resultado = resultado_;
        admin = admin_;
    }

    // Functions

    // 1. Addition
    function addition(
        uint256 a_,
        uint256 b_
    ) external returns (uint256 resultado_) {
        resultado_ = a_ + b_;
        resultado = resultado_;

        emit Addition(a_, b_, resultado_);
    }

    // 2. Subtraction
    function subtraction(
        uint256 a_,
        uint256 b_
    ) external returns (uint256 resultado_) {
        resultado_ = a_ - b_;
        resultado = resultado_;

        emit Subtraction(a_, b_, resultado_);
    }

    // 3. Multiplication
    function multiplication(
        uint256 a_,
        uint256 b_
    ) external returns (uint256 resultado_) {
        resultado_ = a_ * b_;
        resultado = resultado_;

        emit Multiplication(a_, b_, resultado_);
    }

    // 4. Division
    function division(
        uint256 a_,
        uint256 b_
    ) external onlyAdmin returns (uint256 resultado_) {
        require(b_ != 0, "Cannot divide by zero");

        resultado_ = a_ / b_;
        resultado = resultado_;

        emit Division(a_, b_, resultado_);
    }
}
