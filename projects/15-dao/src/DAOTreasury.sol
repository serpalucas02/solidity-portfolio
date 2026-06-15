// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DAO.sol";

contract DAOTreasury is Ownable {
    using SafeERC20 for IERC20;
    DAO public dao;

    mapping(uint256 => bool) public approvedProposals;
    mapping(uint256 => bool) public executedProposals;

    event ProposalApproved(uint256 indexed proposalId);
    event FundsSpent(
        uint256 indexed proposalId,
        address indexed recipient,
        uint256 amount,
        address token
    );
    event TreasuryFunded(address indexed sender, uint256 amount);
    event DAOSet(address indexed dao);

    constructor(address dao_) Ownable(msg.sender) {
        dao = DAO(dao_);
    }

    function setDAO(address dao_) external onlyOwner {
        require(dao_ != address(0), "DAOTreasury: dao is zero");
        dao = DAO(dao_);
        emit DAOSet(dao_);
    }

    function approveProposal(uint256 proposalId_) external {
        require(msg.sender == address(dao), "DAOTreasury: not dao");
        require(
            !approvedProposals[proposalId_],
            "DAOTreasury: proposal already approved"
        );
        approvedProposals[proposalId_] = true;
        emit ProposalApproved(proposalId_);
    }

    function spendFunds(
        uint256 proposalId_,
        address recipient_,
        uint256 amount_,
        address token_
    ) external {
        require(msg.sender == address(dao), "DAOTreasury: not dao");
        require(
            approvedProposals[proposalId_],
            "DAOTreasury: proposal not approved"
        );
        require(
            !executedProposals[proposalId_],
            "DAOTreasury: proposal already executed"
        );
        require(amount_ > 0, "DAOTreasury: amount must be greater than 0");
        require(recipient_ != address(0), "DAOTreasury: recipient is zero");

        executedProposals[proposalId_] = true;

        if (token_ == address(0)) {
            require(
                address(this).balance >= amount_,
                "DAOTreasury: insufficient balance"
            );
            (bool success, ) = recipient_.call{value: amount_}("");
            require(success, "DAOTreasury: failed to send ETH");
        } else {
            require(
                IERC20(token_).balanceOf(address(this)) >= amount_,
                "DAOTreasury: insufficient balance"
            );
            IERC20(token_).safeTransfer(recipient_, amount_);
        }

        emit FundsSpent(proposalId_, recipient_, amount_, token_);
    }

    function fundTreasury() external payable {
        require(msg.value > 0, "DAOTreasury: amount must be greater than 0");
        emit TreasuryFunded(msg.sender, msg.value);
    }

    function fundTreasuryWithToken(address token_, uint256 amount_) external {
        require(token_ != address(0), "DAOTreasury: token is zero");
        require(amount_ > 0, "DAOTreasury: amount must be greater than 0");
        IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);
        emit TreasuryFunded(msg.sender, amount_);
    }

    receive() external payable {
        emit TreasuryFunded(msg.sender, msg.value);
    }

    function emergencyWithdraw(
        address token_,
        uint256 amount_,
        address recipient_
    ) external onlyOwner {
        require(amount_ > 0, "DAOTreasury: amount must be greater than 0");
        require(recipient_ != address(0), "DAOTreasury: recipient is zero");

        if (token_ == address(0)) {
            require(
                address(this).balance >= amount_,
                "DAOTreasury: insufficient balance"
            );
            (bool success, ) = recipient_.call{value: amount_}("");
            require(success, "DAOTreasury: failed to send ETH");
        } else {
            require(
                IERC20(token_).balanceOf(address(this)) >= amount_,
                "DAOTreasury: insufficient balance"
            );
            IERC20(token_).safeTransfer(recipient_, amount_);
        }
    }
}
