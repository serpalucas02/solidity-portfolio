// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.24;

import "./interfaces/IResultado.sol";

contract Sumador {
    // Objeto: Interfaz + Address del contrato
    address public resultado;
    address public admin;
    uint256 public fee;

    constructor(address resultado_, address admin_) {
        resultado = resultado_;
        admin = admin_;
        fee = 5;
    }

    function addition(uint256 num1_, uint256 num2_) external {
        uint256 resultado_ = num1_ + num2_;
        IResultado(resultado).setResultado(resultado_);
    }

    function setFee(uint256 newFee_) external {
        if (msg.sender != admin) revert();
        fee = newFee_;
    }
}
