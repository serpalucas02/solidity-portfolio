// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.24;

/**
 * @title CryptoBank
 * @notice Banco descentralizado: depósito, retiro y máximo de balance por cuenta.
 */
contract CryptoBank {
    // Variables
    uint256 public maxBalance;
    address public admin;
    mapping(address => uint256) public userBalance;

    // Events
    event EtherDeposit(address user_, uint256 etherAmount_);
    event EtherWithdraw(address user_, uint256 etherAmount_);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not allowed");
        _;
    }

    constructor(uint256 maxBalance_, address admin_) {
        maxBalance = maxBalance_;
        admin = admin_;
    }

    // External Functions

    // 1. Deposit
    function depositEther() external payable {
        require(
            userBalance[msg.sender] + msg.value <= maxBalance,
            "Max balance reached"
        );
        userBalance[msg.sender] += msg.value;
        emit EtherDeposit(msg.sender, msg.value);
    }

    // 2. Withdraw
    function withdrawEther(uint256 amount_) external {
        // CEI pattern: 1. Checks / 2. Effects / 3. Interaction
        // Para evitar Reentrancy attacks

        // Checks
        require(amount_ <= userBalance[msg.sender], "Not enough ether");

        // Effects
        userBalance[msg.sender] -= amount_;

        // Transfer Ether
        (bool success, ) = msg.sender.call{value: amount_}("");
        require(success, "Ether transfer failed");

        emit EtherWithdraw(msg.sender, amount_);
    }

    // 3. Modify maxBalance
    function modifyMaxBalance(uint256 newMaxBalance_) external onlyAdmin {
        maxBalance = newMaxBalance_;
    }
}
