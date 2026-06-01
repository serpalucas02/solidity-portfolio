// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.24;

contract Calculadora {
    // Variables
    uint256 public resultado = 10;

    // Modifiers
    modifier checkNumber(uint256 num1_) {
        if (num1_ != 10) revert();
        _;
    }

    // Events
    event Addition(uint256 number1, uint256 number2, uint256 resultado_);
    event Subtraction(uint256 number1, uint256 number2, uint256 resultado_);

    // External Functions
    function addition(
        uint256 num1_,
        uint256 num2_
    ) external returns (uint256 resultado_) {
        resultado_ = num1_ + num2_;

        emit Addition(num1_, num2_, resultado_);
    }

    function subtraction(
        uint256 num1_,
        uint256 num2_
    ) external returns (uint256 resultado_) {
        resultado_ = subtractionLogic(num1_, num2_);

        emit Subtraction(num1_, num2_, resultado_);
    }

    function subtraction2(
        int256 num1_,
        int256 num2_
    ) external pure returns (int256 resultado_) {
        resultado_ = subtractionLogic2(num1_, num2_);
    }

    function multiplier(uint256 num1_) external {
        resultado = resultado * num1_;
    }

    function multiplier2(uint256 num1_) external checkNumber(num1_) {
        resultado = resultado * num1_;
    }

    // Internal Functions
    function subtractionLogic(
        uint256 num1_,
        uint256 num2_
    ) internal pure returns (uint256 resultado_) {
        resultado_ = num1_ - num2_;
    }

    function subtractionLogic2(
        int256 num1_,
        int256 num2_
    ) internal pure returns (int256 resultado_) {
        resultado_ = num1_ - num2_;
    }
}
