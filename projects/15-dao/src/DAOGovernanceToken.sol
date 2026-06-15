// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAOGovernanceToken is ERC20, Ownable {
    mapping(address => uint256) public delegatedVotes;
    mapping(address => address) public delegates;
    mapping(address => bool) public hasDelegated;

    event VotingPowerDelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount
    );
    event VotingPowerUndelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount
    );

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply_);
    }

    function delegateVotingPower(address delegate_, uint256 amount_) external {
        require(
            delegate_ != address(0),
            "DAOGovernanceToken: delegate is zero"
        );
        require(
            delegate_ != msg.sender,
            "DAOGovernanceToken: cannot delegate to self"
        );
        require(
            amount_ > 0,
            "DAOGovernanceToken: amount must be greater than 0"
        );
        require(
            balanceOf(msg.sender) >= amount_,
            "DAOGovernanceToken: amount exceeds balance"
        );

        _transfer(msg.sender, delegate_, amount_);

        delegates[msg.sender] = delegate_;
        delegatedVotes[delegate_] += amount_;
        hasDelegated[msg.sender] = true;

        emit VotingPowerDelegated(msg.sender, delegate_, amount_);
    }

    function undelegateVotingPower(uint256 amount_) external {
        require(
            hasDelegated[msg.sender],
            "DAOGovernanceToken: delegation not found"
        );
        require(
            amount_ > 0,
            "DAOGovernanceToken: amount must be greater than 0"
        );
        require(
            delegatedVotes[delegates[msg.sender]] >= amount_,
            "DAOGovernanceToken: amount exceeds delegation"
        );

        address delegate_ = delegates[msg.sender];
        require(delegate_ != address(0), "DAOGovernanceToken: no delegate");

        _transfer(delegate_, msg.sender, amount_);

        delegatedVotes[delegate_] -= amount_;

        if (delegatedVotes[delegate_] == 0) {
            hasDelegated[msg.sender] = false;
            delete delegates[msg.sender];
        }

        emit VotingPowerUndelegated(msg.sender, delegate_, amount_);
    }

    function getVotingPower(address account_) external view returns (uint256) {
        return balanceOf(account_);
    }

    function mint(address to_, uint256 amount_) external onlyOwner {
        _mint(to_, amount_);
    }

    function burn(uint256 amount_) external onlyOwner {
        _burn(msg.sender, amount_);
    }
}
