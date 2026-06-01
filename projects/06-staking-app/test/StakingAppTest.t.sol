// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "../src/StakingApp.sol";
import "../src/StakingToken.sol";

contract StakingAppTest is Test {
    StakingApp stakingApp;
    StakingToken stakingToken;

    // StakingToken parameters
    string name_ = "Staking Token";
    string symbol_ = "STK";

    // StakingApp parameters
    uint256 stakingPeriod_ = 1 days;
    uint256 fixedStakingAmount_ = 10;
    uint256 rewardPerPeriod_ = 10 ether;
    address owner_ = vm.addr(1);

    address randomUser_ = vm.addr(2);

    function setUp() public {
        stakingToken = new StakingToken(name_, symbol_);
        stakingApp = new StakingApp(
            address(stakingToken),
            stakingPeriod_,
            fixedStakingAmount_,
            rewardPerPeriod_,
            owner_
        );
    }

    function testStakingAppDeployment() external view {
        assert(
            address(stakingApp) != address(0) &&
                address(stakingToken) != address(0)
        );
    }

    function testShouldNotChangeStakingPeriod() external {
        uint256 newStakingPeriod_ = 2 days;
        vm.expectRevert();
        stakingApp.changeStakingPeriod(newStakingPeriod_);
    }

    function testShouldChangeStakingPeriod() external {
        vm.startPrank(owner_);

        uint256 newStakingPeriod_ = 2 days;

        uint256 StakingPeriodBefore_ = stakingApp.stakingPeriod();
        stakingApp.changeStakingPeriod(newStakingPeriod_);
        uint256 StakingPeriodAfter_ = stakingApp.stakingPeriod();

        assert(StakingPeriodBefore_ != StakingPeriodAfter_);
        assert(StakingPeriodAfter_ == newStakingPeriod_);

        vm.stopPrank();
    }

    function testContractShouldReceiveEther() external {
        vm.startPrank(owner_);
        vm.deal(owner_, 1 ether);

        uint256 amount_ = 1 ether;
        uint256 balanceBefore_ = address(stakingApp).balance;
        (bool success, ) = address(stakingApp).call{value: amount_}("");
        require(success, "Ether transfer failed");
        uint256 balanceAfter_ = address(stakingApp).balance;
        assert(balanceAfter_ - balanceBefore_ == amount_);

        vm.stopPrank();
    }

    function testIncorrectDeposit() external {
        vm.startPrank(randomUser_);

        uint256 incorrectAmount_ = 5;

        vm.expectRevert("Invalid staking amount");
        stakingApp.deposit(incorrectAmount_);

        vm.stopPrank();
    }

    function testCorrectDeposit() external {
        vm.startPrank(randomUser_);

        uint256 correctAmount_ = stakingApp.fixedStakingAmount();

        // Approve tokens for staking
        stakingToken.mint(correctAmount_);
        IERC20(stakingToken).approve(address(stakingApp), correctAmount_);

        // Deposit tokens
        uint256 balanceBefore_ = stakingApp.userBalance(randomUser_);
        uint256 elapsePeriodBefore_ = stakingApp.elapsePeriod(randomUser_);
        stakingApp.deposit(correctAmount_);
        uint256 balanceAfter_ = stakingApp.userBalance(randomUser_);
        uint256 elapsePeriodAfter_ = stakingApp.elapsePeriod(randomUser_);

        assert(balanceAfter_ - balanceBefore_ == correctAmount_);
        assert(elapsePeriodBefore_ == 0);
        assert(elapsePeriodAfter_ == block.timestamp);

        vm.stopPrank();
    }

    function testCanNotDepositMoreThanOnce() external {
        vm.startPrank(randomUser_);

        uint256 correctAmount_ = stakingApp.fixedStakingAmount();

        // Approve tokens for staking
        stakingToken.mint(correctAmount_);
        IERC20(stakingToken).approve(address(stakingApp), correctAmount_);

        // Deposit tokens
        uint256 balanceBefore_ = stakingApp.userBalance(randomUser_);
        uint256 elapsePeriodBefore_ = stakingApp.elapsePeriod(randomUser_);
        stakingApp.deposit(correctAmount_);
        uint256 balanceAfter_ = stakingApp.userBalance(randomUser_);
        uint256 elapsePeriodAfter_ = stakingApp.elapsePeriod(randomUser_);

        assert(balanceAfter_ - balanceBefore_ == correctAmount_);
        assert(elapsePeriodBefore_ == 0);
        assert(elapsePeriodAfter_ == block.timestamp);

        stakingToken.mint(correctAmount_);
        IERC20(stakingToken).approve(address(stakingApp), correctAmount_);
        vm.expectRevert("Already staked");
        stakingApp.deposit(correctAmount_);

        vm.stopPrank();
    }

    function testCanOnlyWithdraw0WithoutDeposit() external {
        vm.startPrank(randomUser_);

        vm.expectRevert("No staked balance to withdraw");
        stakingApp.withdraw();

        vm.stopPrank();
    }

    function testCanWithdrawAfterDeposit() external {
        vm.startPrank(randomUser_);

        uint256 correctAmount_ = stakingApp.fixedStakingAmount();

        // Approve tokens for staking
        stakingToken.mint(correctAmount_);
        IERC20(stakingToken).approve(address(stakingApp), correctAmount_);

        // Deposit tokens
        stakingApp.deposit(correctAmount_);

        // Withdraw tokens
        uint256 balanceBefore_ = stakingApp.userBalance(randomUser_);
        stakingApp.withdraw();
        uint256 balanceAfter_ = stakingApp.userBalance(randomUser_);

        assert(balanceBefore_ == correctAmount_);
        assert(balanceAfter_ == 0);

        vm.stopPrank();
    }

    function testCanNotClaimRewardsWithoutDeposit() external {
        vm.startPrank(randomUser_);

        vm.expectRevert("No staked balance to claim rewards");
        stakingApp.claimRewards();

        vm.stopPrank();
    }

    function testCanNotClaimIfNotElapsedTime() external {
        vm.startPrank(randomUser_);

        uint256 correctAmount_ = stakingApp.fixedStakingAmount();

        // Approve tokens for staking
        stakingToken.mint(correctAmount_);
        IERC20(stakingToken).approve(address(stakingApp), correctAmount_);

        // Deposit tokens
        stakingApp.deposit(correctAmount_);

        vm.expectRevert("Staking period not yet completed");
        stakingApp.claimRewards();

        vm.stopPrank();
    }

    function testCanNotClaimRewardsAfterElapsedTime() external {
        vm.startPrank(randomUser_);

        uint256 correctAmount_ = stakingApp.fixedStakingAmount();

        // Approve tokens for staking
        stakingToken.mint(correctAmount_);
        IERC20(stakingToken).approve(address(stakingApp), correctAmount_);

        // Deposit tokens
        stakingApp.deposit(correctAmount_);

        // Fast forward time
        vm.warp(block.timestamp + stakingApp.stakingPeriod());

        // Claim rewards
        vm.expectRevert("Reward transfer failed");
        stakingApp.claimRewards();

        vm.stopPrank();
    }

    function testCanClaimRewardsAfterElapsedTime() external {
        vm.startPrank(owner_);

        // Fund the contract with Ether for rewards
        vm.deal(owner_, 10 ether);
        (bool success, ) = address(stakingApp).call{value: 10 ether}("");
        require(success, "Ether transfer failed");

        vm.stopPrank();

        vm.startPrank(randomUser_);

        uint256 correctAmount_ = stakingApp.fixedStakingAmount();

        // Approve tokens for staking
        stakingToken.mint(correctAmount_);
        IERC20(stakingToken).approve(address(stakingApp), correctAmount_);

        // Deposit tokens
        stakingApp.deposit(correctAmount_);

        // Fast forward time
        vm.warp(block.timestamp + stakingApp.stakingPeriod());

        // Claim rewards
        uint256 balanceBefore_ = randomUser_.balance;
        stakingApp.claimRewards();
        uint256 balanceAfter_ = randomUser_.balance;

        assert(balanceAfter_ - balanceBefore_ == stakingApp.rewardPerPeriod());

        vm.stopPrank();
    }
}
