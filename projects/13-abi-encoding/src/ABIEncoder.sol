// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract ABIEncoder {
    event EncodedData(bytes32 indexed hash, bytes encodedData);
    event PoolIdentifierCreated(
        bytes32 indexed poolId,
        address indexed token,
        uint256 rate
    );
    event UserPositionEncoded(
        bytes32 indexed positionId,
        address indexed user,
        uint256 amount
    );
    event LimitOrderEncoded(bytes32 indexed orderId, bytes encodedData);
    event YieldFarmingPositionEncoded(
        bytes32 indexed positionId,
        address indexed user,
        uint256 amount
    );
    event FlashLoanEncoded(
        bytes32 indexed positionId,
        address indexed user,
        uint256 amount
    );
    event StakingPoolConfigurationEncoded(
        bytes32 indexed configId,
        bytes encodedData
    );
    event MultiPoolHashCreated(
        bytes32 indexed multiPoolHash,
        bytes combinedData
    );
    event YieldStrategyEncoded(bytes32 indexed strategyHash, bytes encodedData);
    event CrossChainBridgeDataEncoded(
        bytes32 indexed dataHash,
        bytes encodedData
    );
    event DefiTransactionIdCreated(bytes32 indexed txId, bytes encodedData);
    event StopLossOrderEncoded(bytes32 indexed orderId, bytes encodedData);
    event TakeProfitOrderEncoded(bytes32 indexed orderId, bytes encodedData);
    event TrailingStopOrderEncoded(bytes32 indexed orderId, bytes encodedData);

    function createPoolIdentifier(
        address tokenA_,
        address tokenB_,
        uint256 fee_
    ) external returns (bytes32 poolId_) {
        (address token0, address token1) = tokenA_ < tokenB_
            ? (tokenA_, tokenB_)
            : (tokenB_, tokenA_);
        poolId_ = keccak256(abi.encodePacked(token0, token1, fee_));
        emit PoolIdentifierCreated(poolId_, token0, fee_);
    }

    function encodeTradingPosition(
        address user_,
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        uint256 amountOutMin_,
        uint256 deadline_
    ) external returns (bytes memory encodedData_) {
        encodedData_ = abi.encodePacked(
            user_,
            tokenIn_,
            tokenOut_,
            amountIn_,
            amountOutMin_,
            deadline_
        );
        bytes32 positionId_ = keccak256(encodedData_);
        emit UserPositionEncoded(positionId_, user_, amountIn_);
    }

    function encodeSwapData(
        address[] calldata path_,
        uint256[] calldata amounts_,
        uint256 deadline_
    ) external returns (bytes memory encodedData_) {
        require(
            path_.length == amounts_.length,
            "Path and amounts length mismatch"
        );

        // Encode the path
        bytes memory pathData_;
        for (uint256 i = 0; i < path_.length; i++) {
            pathData_ = abi.encodePacked(pathData_, path_[i]);
        }

        // Encode the amounts
        bytes memory amountsData_;
        for (uint256 i = 0; i < amounts_.length; i++) {
            amountsData_ = abi.encodePacked(amountsData_, amounts_[i]);
        }

        // Combine all encoded data
        encodedData_ = abi.encodePacked(pathData_, amountsData_, deadline_);
        bytes32 hash_ = keccak256(encodedData_);
        emit EncodedData(hash_, encodedData_);
    }

    function encodeLimitOrder(
        address maker_,
        address taker_,
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        uint256 amountOut_,
        uint256 nonce_
    ) external returns (bytes32 orderId_, bytes memory encodedData_) {
        encodedData_ = abi.encodePacked(
            maker_,
            taker_,
            tokenIn_,
            tokenOut_,
            amountIn_,
            amountOut_,
            nonce_,
            "LIMIT_ORDER"
        );
        orderId_ = keccak256(encodedData_);
        emit LimitOrderEncoded(orderId_, encodedData_);
    }

    function encodeYieldFarmingPosition(
        address user_,
        bytes32 poolId_,
        uint256 amount_,
        uint256 startTime_
    ) external returns (bytes32 positionId_, bytes memory encodedData_) {
        encodedData_ = abi.encodePacked(
            user_,
            poolId_,
            amount_,
            startTime_,
            "YIELD_FARMING"
        );
        positionId_ = keccak256(encodedData_);
        emit YieldFarmingPositionEncoded(positionId_, user_, amount_);
    }

    function encodeFlashLoan(
        address token_,
        uint256 amount_,
        bytes calldata callbackData_
    ) external returns (bytes32 positionId_, bytes memory encodedData_) {
        encodedData_ = abi.encodePacked(
            token_,
            amount_,
            callbackData_,
            "FLASH_LOAN"
        );
        positionId_ = keccak256(encodedData_);
        emit FlashLoanEncoded(positionId_, msg.sender, amount_);
    }

    function encodeStakingPoolConfiguration(
        address token_,
        uint256 rewardRate_,
        uint256 lockPeriod_,
        uint256 maxStakers_
    ) external returns (bytes memory encodedData_) {
        encodedData_ = abi.encodePacked(
            token_,
            rewardRate_,
            lockPeriod_,
            maxStakers_,
            block.timestamp,
            "STAKING_POOL"
        );
        bytes32 hash_ = keccak256(encodedData_);
        emit StakingPoolConfigurationEncoded(hash_, encodedData_);
    }

    function createUserMultiPoolHash(
        address user_,
        bytes32[] calldata poolIds_,
        uint256[] calldata amounts_
    ) external returns (bytes32 multiPoolHash_) {
        require(
            poolIds_.length == amounts_.length,
            "Pool IDs and amounts length mismatch"
        );

        bytes memory combinedData_;
        for (uint256 i = 0; i < poolIds_.length; i++) {
            combinedData_ = abi.encodePacked(
                combinedData_,
                user_,
                poolIds_[i],
                amounts_[i]
            );
        }
        multiPoolHash_ = keccak256(combinedData_);
        emit MultiPoolHashCreated(multiPoolHash_, combinedData_);
    }

    function encodeYieldStrategy(
        string calldata strategyName_,
        address[] calldata pools_,
        uint256[] calldata weights_
    ) external returns (bytes memory encodedData_) {
        require(
            pools_.length == weights_.length,
            "Pools and weights length mismatch"
        );

        bytes memory poolsData_;
        for (uint256 i = 0; i < pools_.length; i++) {
            poolsData_ = abi.encodePacked(poolsData_, pools_[i], weights_[i]);
        }

        encodedData_ = abi.encodePacked(
            strategyName_,
            poolsData_,
            block.timestamp,
            "YIELD_STRATEGY"
        );
        bytes32 hash_ = keccak256(encodedData_);
        emit YieldStrategyEncoded(hash_, encodedData_);
    }

    function encodeCrossChainBridgeData(
        uint256 sourceChainId_,
        uint256 destinationChainId_,
        address token_,
        uint256 amount_,
        address recipient_
    ) external returns (bytes memory encodedData_) {
        encodedData_ = abi.encodePacked(
            sourceChainId_,
            destinationChainId_,
            token_,
            amount_,
            recipient_,
            "CROSS_CHAIN_BRIDGE"
        );
        bytes32 hash_ = keccak256(encodedData_);
        emit CrossChainBridgeDataEncoded(hash_, encodedData_);
    }

    function createDefiTransactionId(
        string calldata txType_,
        address user_,
        uint256 amount_,
        uint256 timestamp_,
        uint256 nonce_
    ) external returns (bytes32 txId_) {
        txId_ = keccak256(
            abi.encodePacked(
                txType_,
                user_,
                amount_,
                timestamp_,
                nonce_,
                "DEFI_TX"
            )
        );
        emit DefiTransactionIdCreated(
            txId_,
            abi.encodePacked(txType_, user_, amount_, timestamp_, nonce_)
        );
    }

    function encodeStopLossOrder(
        address user_,
        address token_,
        uint256 amount_,
        uint256 stopPrice_
    ) external returns (bytes32 orderId_, bytes memory encodedData_) {
        encodedData_ = abi.encodePacked(
            user_,
            token_,
            amount_,
            stopPrice_,
            "STOP_LOSS_ORDER"
        );
        orderId_ = keccak256(encodedData_);
        emit StopLossOrderEncoded(orderId_, encodedData_);
    }

    function encodeTakeProfitOrder(
        address user_,
        address token_,
        uint256 amount_,
        uint256 takeProfitPrice_
    ) external returns (bytes32 orderId_, bytes memory encodedData_) {
        encodedData_ = abi.encodePacked(
            user_,
            token_,
            amount_,
            takeProfitPrice_,
            "TAKE_PROFIT_ORDER"
        );
        orderId_ = keccak256(encodedData_);
        emit TakeProfitOrderEncoded(orderId_, encodedData_);
    }

    function encodeTrailingStopOrder(
        address user_,
        address token_,
        uint256 amount_,
        uint256 trailingPercent_,
        uint256 activationPrice_
    ) external returns (bytes32 orderId_, bytes memory encodedData_) {
        encodedData_ = abi.encodePacked(
            user_,
            token_,
            amount_,
            trailingPercent_,
            activationPrice_,
            "TRAILING_STOP_ORDER"
        );
        orderId_ = keccak256(encodedData_);
        emit TrailingStopOrderEncoded(orderId_, encodedData_);
    }
}
