// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.24;

contract PayableContract {
    // 1 ether = 1*10^18 wei

    function sendEther() public payable {}

    // send() y transfer() gas máximo 2300
    // así que si las functions receive() de otro contrato tienen mucha lógica y exceden los 2300 de gas
    // se hace el revert(), por eso se recomienda usar call()

    // send() devuelve un booleano si salió bien o mal la transferencia, y transfer() no

    // usando call() no hace falta hacer una interfaz para llamar a las functions de otro contrato
}
