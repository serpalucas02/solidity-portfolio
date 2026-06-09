// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title SimpleBank — banco VULNERABLE a reentrancy (a propósito)
/// @notice Demuestra el clásico bug de CEI roto: hace la llamada externa
///         (envío de ETH) ANTES de actualizar el estado (userBalance = 0).
///         NO usar en producción. Existe solo para que el Attacker lo drene.
contract SimpleBank {
    mapping(address => uint256) public userBalance;

    function deposit() public payable {
        require(msg.value >= 1 ether, "Minimum deposit is 1 ETH");
        userBalance[msg.sender] += msg.value;
    }

    function withdraw() public {
        require(userBalance[msg.sender] >= 1 ether, "User has not enough balance");
        require(address(this).balance > 0, "Bank is rekt");

        // ⚠️ INTERACTION antes de EFFECT: en este punto userBalance todavía
        // no se puso en 0, así que un receive() malicioso puede re-entrar a
        // withdraw() y volver a pasar el require de arriba.
        (bool success, ) = msg.sender.call{value: userBalance[msg.sender]}("");
        require(success, "fail");

        // El effect llega tarde: para cuando se ejecuta, el banco ya fue drenado.
        userBalance[msg.sender] = 0;
    }

    function totalBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
