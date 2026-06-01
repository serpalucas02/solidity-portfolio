// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.24;

contract Resultado {
    uint256 public resultado;

    function setResultado(uint256 num_) external {
        resultado = num_;
    }
}
