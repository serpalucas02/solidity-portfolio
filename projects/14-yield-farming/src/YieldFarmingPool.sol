// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract YieldFarmingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Pool {
        address token;
        uint256 totalStaked;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        bool isActive;
    }
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastClaimTime;
    }
    IERC20 public rewardToken;
    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => UserInfo)) public users;
    bytes32[] public activePools;

    event PoolCreated(
        bytes32 indexed poolId,
        address indexed rewardToken,
        uint256 rewardRate
    );
    event Staked(bytes32 indexed poolId, address indexed user, uint256 amount);
    event Withdrawn(
        bytes32 indexed poolId,
        address indexed user,
        uint256 amount
    );
    event RewardClaimed(
        bytes32 indexed poolId,
        address indexed user,
        uint256 reward
    );
    event PoolUpdated(bytes32 indexed poolId, uint256 newRewardRate);

    constructor(address rewardToken_) Ownable(msg.sender) {
        require(
            rewardToken_ != address(0),
            "YieldFarmingPool: rewardToken is zero address"
        );
        rewardToken = IERC20(rewardToken_);
    }

    function createPool(
        address token_,
        uint256 rewardRate_
    ) external onlyOwner returns (bytes32 poolId) {
        require(
            token_ != address(0),
            "YieldFarmingPool: token is zero address"
        );
        require(
            rewardRate_ > 0,
            "YieldFarmingPool: rewardRate must be greater than 0"
        );

        poolId = keccak256(
            abi.encodePacked(
                token_,
                rewardRate_,
                block.timestamp,
                block.chainid
            )
        );

        require(
            pools[poolId].token == address(0),
            "YieldFarmingPool: pool exists"
        );

        pools[poolId] = Pool({
            token: token_,
            totalStaked: 0,
            rewardRate: rewardRate_,
            lastUpdateTime: block.timestamp,
            rewardPerTokenStored: 0,
            isActive: true
        });

        activePools.push(poolId);

        emit PoolCreated(poolId, token_, rewardRate_);
    }

    function stake(bytes32 poolId_, uint256 amount_) external nonReentrant {
        Pool storage pool = pools[poolId_];
        require(pool.isActive, "YieldFarmingPool: pool is not active");
        require(amount_ > 0, "YieldFarmingPool: amount must be greater than 0");

        _updatePool(poolId_);

        UserInfo storage user = users[poolId_][msg.sender];

        if (user.amount > 0) {
            uint256 pending = _calculatePendingReward(poolId_, msg.sender);
            if (pending > 0) {
                _safeRewardTransfer(msg.sender, pending);
                emit RewardClaimed(poolId_, msg.sender, pending);
            }
        }

        IERC20(pool.token).safeTransferFrom(msg.sender, address(this), amount_);

        user.amount += amount_;
        user.rewardDebt = (user.amount * pool.rewardPerTokenStored) / 1e18;
        user.lastClaimTime = block.timestamp;

        pool.totalStaked += amount_;

        emit Staked(poolId_, msg.sender, amount_);
    }

    function withdraw(bytes32 poolId_, uint256 amount_) external nonReentrant {
        Pool storage pool = pools[poolId_];
        UserInfo storage user = users[poolId_][msg.sender];
        require(pool.isActive, "YieldFarmingPool: pool is not active");
        require(amount_ > 0, "YieldFarmingPool: amount must be greater than 0");

        _updatePool(poolId_);

        require(
            user.amount >= amount_,
            "YieldFarmingPool: amount exceeds balance"
        );

        uint256 pending = _calculatePendingReward(poolId_, msg.sender);
        if (pending > 0) {
            _safeRewardTransfer(msg.sender, pending);
            emit RewardClaimed(poolId_, msg.sender, pending);
        }

        user.amount -= amount_;
        user.rewardDebt = (user.amount * pool.rewardPerTokenStored) / 1e18;
        user.lastClaimTime = block.timestamp;

        pool.totalStaked -= amount_;

        IERC20(pool.token).safeTransfer(msg.sender, amount_);

        emit Withdrawn(poolId_, msg.sender, amount_);
    }

    function claimReward(bytes32 poolId_) external nonReentrant {
        Pool storage pool = pools[poolId_];
        UserInfo storage user = users[poolId_][msg.sender];
        require(pool.isActive, "YieldFarmingPool: pool is not active");
        require(user.amount > 0, "YieldFarmingPool: user has no staked tokens");

        _updatePool(poolId_);

        uint256 pending = _calculatePendingReward(poolId_, msg.sender);
        require(pending > 0, "YieldFarmingPool: no pending rewards");

        user.rewardDebt = (user.amount * pool.rewardPerTokenStored) / 1e18;
        user.lastClaimTime = block.timestamp;

        _safeRewardTransfer(msg.sender, pending);

        emit RewardClaimed(poolId_, msg.sender, pending);
    }

    function updatePoolRewardRate(
        bytes32 poolId_,
        uint256 newRewardRate_
    ) external onlyOwner {
        Pool storage pool = pools[poolId_];
        require(
            newRewardRate_ > 0,
            "YieldFarmingPool: new reward rate must be greater than 0"
        );
        require(
            pools[poolId_].isActive,
            "YieldFarmingPool: pool is not active"
        );

        _updatePool(poolId_);
        pool.rewardRate = newRewardRate_;

        emit PoolUpdated(poolId_, newRewardRate_);
    }

    function getPoolEncodedData(
        bytes32 poolId_
    ) external view returns (bytes memory encodedData) {
        Pool storage pool = pools[poolId_];

        encodedData = abi.encodePacked(
            pool.token,
            pool.totalStaked,
            pool.rewardRate,
            pool.lastUpdateTime,
            pool.rewardPerTokenStored,
            pool.isActive
        );
    }

    function getUserHash(
        bytes32 poolId_,
        address user_
    ) external pure returns (bytes32 userHash) {
        userHash = keccak256(
            abi.encodePacked(poolId_, user_, "YIELD_FARMING_USER")
        );
    }

    function getActivePoolsCount() external view returns (uint256 count) {
        count = activePools.length;
    }

    function getActivePools() external view returns (bytes32[] memory) {
        return activePools;
    }

    function emergencyWithdraw(
        address token_,
        uint256 amount_
    ) external onlyOwner {
        IERC20(token_).safeTransfer(owner(), amount_);
    }

    function _updatePool(bytes32 poolId_) internal {
        Pool storage pool = pools[poolId_];

        if (pool.totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
            uint256 reward = timeElapsed * pool.rewardRate;
            pool.rewardPerTokenStored += (reward * 1e18) / pool.totalStaked;
        }

        pool.lastUpdateTime = block.timestamp;
    }

    function _safeRewardTransfer(address to_, uint256 amount_) internal {
        uint256 balance = rewardToken.balanceOf(address(this));
        if (amount_ > balance) {
            rewardToken.safeTransfer(to_, balance);
        } else {
            rewardToken.safeTransfer(to_, amount_);
        }
    }

    function _calculatePendingReward(
        bytes32 poolId_,
        address user_
    ) internal view returns (uint256 pending) {
        Pool storage pool = pools[poolId_];
        UserInfo storage user = users[poolId_][user_];

        uint256 rewardPerTokenStored = pool.rewardPerTokenStored;

        if (pool.totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
            uint256 reward = timeElapsed * pool.rewardRate;
            rewardPerTokenStored += (reward * 1e18) / pool.totalStaked;
        }

        pending = (user.amount * rewardPerTokenStored) / 1e18 - user.rewardDebt;
    }
}
