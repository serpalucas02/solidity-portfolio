// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IDAOTreasury {
    function approveProposal(uint256 proposalId_) external;

    function spendFunds(
        uint256 proposalId_,
        address recipient_,
        uint256 amount_,
        address token_
    ) external;
}
