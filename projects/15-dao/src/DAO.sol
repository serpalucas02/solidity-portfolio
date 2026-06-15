// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./DAOGovernanceToken.sol";
import "./interfaces/IDAOTreasury.sol";

contract DAO is Ownable {
    DAOGovernanceToken public governanceToken;
    IDAOTreasury public treasury;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        address recipient;
        uint256 amount;
        address token;
        mapping(address => bool) hasVoted;
        mapping(address => bool) hasVotedFor;
    }

    // DAO config
    uint256 public proposalThreshold;
    uint256 public votingPeriod;
    uint256 public quorumVotes;

    // Proposal tracking
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        address recipient,
        uint256 amount,
        address token,
        uint256 startTime,
        uint256 endTime
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votes
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event ConfigurationUpdated(
        uint256 proposalThreshold,
        uint256 votingPeriod,
        uint256 quorumVotes
    );
    event TreasurySet(address indexed treasury);

    constructor(
        address governanceToken_,
        address treasury_,
        uint256 proposalThreshold_,
        uint256 votingPeriod_,
        uint256 quorumVotes_
    ) Ownable(msg.sender) {
        governanceToken = DAOGovernanceToken(governanceToken_);
        treasury = IDAOTreasury(treasury_);
        proposalThreshold = proposalThreshold_;
        votingPeriod = votingPeriod_;
        quorumVotes = quorumVotes_;
    }

    function createProposal(
        string memory description_,
        address recipient_,
        uint256 amount_,
        address token_
    ) external returns (uint256 proposalId) {
        require(
            governanceToken.getVotingPower(msg.sender) >= proposalThreshold,
            "DAO: proposer votes below proposal threshold"
        );
        require(bytes(description_).length > 0, "DAO: description is empty");
        require(amount_ > 0, "DAO: amount must be greater than 0");
        require(recipient_ != address(0), "DAO: recipient is zero");

        proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];

        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description_;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + votingPeriod;
        proposal.executed = false;
        proposal.canceled = false;
        proposal.recipient = recipient_;
        proposal.amount = amount_;
        proposal.token = token_;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            description_,
            recipient_,
            amount_,
            token_,
            proposal.startTime,
            proposal.endTime
        );
    }

    function vote(uint256 proposalId_, bool support_) external {
        Proposal storage proposal = proposals[proposalId_];

        require(proposal.proposer != address(0), "DAO: proposal not found");
        require(
            block.timestamp >= proposal.startTime,
            "DAO: voting not started"
        );
        require(
            block.timestamp <= proposal.endTime,
            "DAO: voting period has ended"
        );
        require(!proposal.hasVoted[msg.sender], "DAO: voter already voted");
        require(!proposal.canceled, "DAO: proposal canceled");
        require(!proposal.executed, "DAO: proposal executed");

        uint256 votes = governanceToken.getVotingPower(msg.sender);
        require(votes > 0, "DAO: voter has no voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.hasVotedFor[msg.sender] = support_;

        if (support_) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit Voted(proposalId_, msg.sender, support_, votes);
    }

    function cancelProposal(uint256 proposalId_) external {
        Proposal storage proposal = proposals[proposalId_];

        require(proposal.proposer != address(0), "DAO: proposal not found");
        require(!proposal.executed, "DAO: proposal executed");
        require(!proposal.canceled, "DAO: proposal already canceled");
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "DAO: only proposer or owner can cancel"
        );

        proposal.canceled = true;

        emit ProposalCanceled(proposalId_);
    }

    function executeProposal(uint256 proposalId_) external {
        Proposal storage proposal = proposals[proposalId_];

        require(proposal.proposer != address(0), "DAO: proposal not found");
        require(block.timestamp >= proposal.endTime, "DAO: voting not ended");
        require(!proposal.executed, "DAO: proposal already executed");
        require(!proposal.canceled, "DAO: proposal canceled");
        require(
            proposal.forVotes + proposal.againstVotes >= quorumVotes,
            "DAO: no quorum"
        );
        require(proposal.forVotes > proposal.againstVotes, "DAO: no majority");

        proposal.executed = true;

        treasury.approveProposal(proposalId_);
        treasury.spendFunds(
            proposalId_,
            proposal.recipient,
            proposal.amount,
            proposal.token
        );

        emit ProposalExecuted(proposalId_);
    }

    function getProposal(
        uint256 proposalId_
    )
        external
        view
        returns (
            address proposer,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 startTime,
            uint256 endTime,
            bool executed,
            bool canceled,
            address recipient,
            uint256 amount,
            address token
        )
    {
        Proposal storage proposal = proposals[proposalId_];

        return (
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.canceled,
            proposal.recipient,
            proposal.amount,
            proposal.token
        );
    }

    function getVoteInfo(
        uint256 proposalId_,
        address voter_
    ) external view returns (bool hasVoted, bool hasVotedFor) {
        Proposal storage proposal = proposals[proposalId_];

        return (proposal.hasVoted[voter_], proposal.hasVotedFor[voter_]);
    }

    function updateConfiguration(
        uint256 proposalThreshold_,
        uint256 votingPeriod_,
        uint256 quorumVotes_
    ) external onlyOwner {
        proposalThreshold = proposalThreshold_;
        votingPeriod = votingPeriod_;
        quorumVotes = quorumVotes_;

        emit ConfigurationUpdated(
            proposalThreshold_,
            votingPeriod_,
            quorumVotes_
        );
    }

    function setTreasury(address treasury_) external onlyOwner {
        require(treasury_ != address(0), "DAO: treasury is zero");
        treasury = IDAOTreasury(treasury_);

        emit TreasurySet(treasury_);
    }

    function proposalPassed(uint256 proposalId_) external view returns (bool) {
        Proposal storage proposal = proposals[proposalId_];

        require(proposal.proposer != address(0), "DAO: proposal not found");
        require(block.timestamp >= proposal.endTime, "DAO: voting not ended");
        require(!proposal.executed, "DAO: proposal already executed");
        require(!proposal.canceled, "DAO: proposal canceled");
        require(
            proposal.forVotes + proposal.againstVotes >= quorumVotes,
            "DAO: no quorum"
        );

        return proposal.forVotes > proposal.againstVotes;
    }
}
