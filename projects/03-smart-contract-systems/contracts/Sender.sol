// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.24;

contract Sender {
    address public owner; // Default: address(0)

    constructor() {
        owner = msg.sender;
    }
}
