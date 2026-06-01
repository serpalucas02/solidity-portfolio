// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingApp is Ownable {
    using SafeERC20 for IERC20;

    // Variables
    address public stakingToken;
    uint256 public stakingPeriod;
    uint256 public fixedStakingAmount;
    uint256 public rewardPerPeriod;
    mapping(address => uint256) public userBalance;
    mapping(address => uint256) public elapsePeriod;

    // Events
    event StakingPeriodChanged(uint256 newStakingPeriod_);
    event Deposited(address user_, uint256 amount_);
    event Withdrawn(address user_, uint256 amount_);
    event RewardsClaimed(address user_, uint256 rewardAmount_);
    event EtherSent(uint256 amount_);

    // Modifiers
    modifier checkStakingAmountDeposit(uint256 amount_) {
        require(amount_ == fixedStakingAmount, "Invalid staking amount");
        require(userBalance[msg.sender] == 0, "Already staked");
        _;
    }

    constructor(
        address stakingToken_,
        uint256 stakingPeriod_,
        uint256 fixedStakingAmount_,
        uint256 rewardPerPeriod_,
        address owner_
    ) Ownable(owner_) {
        stakingToken = stakingToken_;
        stakingPeriod = stakingPeriod_;
        fixedStakingAmount = fixedStakingAmount_;
        rewardPerPeriod = rewardPerPeriod_;
    }

    // Functions
    function changeStakingPeriod(uint256 newStakingPeriod_) external onlyOwner {
        stakingPeriod = newStakingPeriod_;
        emit StakingPeriodChanged(newStakingPeriod_);
    }

    // 1. Deposit
    function deposit(
        uint256 amount_
    ) external checkStakingAmountDeposit(amount_) {
        // 1.1 Update user's staking balance
        userBalance[msg.sender] += amount_;
        // 1.2 Update user's elapsed period
        elapsePeriod[msg.sender] = block.timestamp;
        // 1.3 Transfer tokens from user to contract
        IERC20(stakingToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount_
        );

        emit Deposited(msg.sender, amount_);
    }

    // 2. Withdraw
    function withdraw() external {
        require(userBalance[msg.sender] > 0, "No staked balance to withdraw");

        uint256 userBalance_ = userBalance[msg.sender];
        userBalance[msg.sender] = 0;
        IERC20(stakingToken).safeTransfer(msg.sender, userBalance_);

        emit Withdrawn(msg.sender, userBalance_);
    }

    // 3. Claim Rewards
    function claimRewards() external {
        // 1. Check balance
        require(
            userBalance[msg.sender] > 0,
            "No staked balance to claim rewards"
        );

        // 2. Check elapsed period
        uint256 elapsePeriod_ = block.timestamp - elapsePeriod[msg.sender];
        require(
            elapsePeriod_ >= stakingPeriod,
            "Staking period not yet completed"
        );

        // 3. Update state
        elapsePeriod[msg.sender] = block.timestamp;

        // 4. Transfer rewards to user
        (bool success, ) = msg.sender.call{value: rewardPerPeriod}("");
        require(success, "Reward transfer failed");

        emit RewardsClaimed(msg.sender, rewardPerPeriod);
    }

    receive() external payable onlyOwner {
        emit EtherSent(msg.value);
    }
}
