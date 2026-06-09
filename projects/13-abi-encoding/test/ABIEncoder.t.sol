// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/ABIEncoder.sol";

contract ABIEncoderTest is Test {
    ABIEncoder private abiEncoder;

    function setUp() public {
        abiEncoder = new ABIEncoder();
    }

    function testCreatePoolIdentifier() public {
        address tokenA = address(0x123);
        address tokenB = address(0x456);
        uint256 fee = 3000;

        bytes32 poolIdAB = abiEncoder.createPoolIdentifier(tokenA, tokenB, fee);
        bytes32 poolIdBA = abiEncoder.createPoolIdentifier(tokenB, tokenA, fee);

        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        bytes32 expectedPoolId = keccak256(
            abi.encodePacked(token0, token1, fee)
        );

        assertEq(
            poolIdAB,
            expectedPoolId,
            "Pool ID AB does not match expected"
        );
        assertEq(
            poolIdBA,
            expectedPoolId,
            "Pool ID BA does not match expected"
        );
    }

    function testCreatePoolIdentifierWithDifferentFee() public {
        address tokenA = address(0x123);
        address tokenB = address(0x456);
        uint256 fee1 = 3000;
        uint256 fee2 = 500;

        bytes32 poolId1 = abiEncoder.createPoolIdentifier(tokenA, tokenB, fee1);
        bytes32 poolId2 = abiEncoder.createPoolIdentifier(tokenA, tokenB, fee2);

        assertTrue(
            poolId1 != poolId2,
            "Pool IDs with different fees should not match"
        );
    }

    function testEncodeTradingPosition() public {
        address user = address(0x789);
        address tokenIn = address(0x123);
        address tokenOut = address(0x456);
        uint256 amountIn = 1 ether;
        uint256 amountOutMin = 2 ether;
        // Freeze block timestamp to a known value for consistent testing
        uint256 fixedTs = 1_700_000_000;
        vm.warp(fixedTs);

        bytes memory encodedData = abiEncoder.encodeTradingPosition(
            user,
            tokenIn,
            tokenOut,
            amountIn,
            amountOutMin,
            fixedTs
        );
        bytes32 positionId = keccak256(encodedData);

        bytes memory expectedData = abi.encodePacked(
            user,
            tokenIn,
            tokenOut,
            amountIn,
            amountOutMin,
            fixedTs
        );
        bytes32 expectedHash = keccak256(expectedData);

        assertEq(
            positionId,
            expectedHash,
            "Encoded trading position hash does not match expected"
        );
        assertEq(
            encodedData,
            expectedData,
            "Encoded trading position data does not match expected"
        );
    }

    function testEncodeSwapData() public {
        address[] memory path = new address[](3);
        path[0] = address(0x123);
        path[1] = address(0x456);
        path[2] = address(0x789);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        uint256 deadline = block.timestamp + 1 hours;

        bytes memory encodedData = abiEncoder.encodeSwapData(
            path,
            amounts,
            deadline
        );

        bytes memory expectedPathData;
        for (uint256 i = 0; i < path.length; i++) {
            expectedPathData = abi.encodePacked(expectedPathData, path[i]);
        }
        bytes memory expectedAmountsData;
        for (uint256 i = 0; i < amounts.length; i++) {
            expectedAmountsData = abi.encodePacked(
                expectedAmountsData,
                amounts[i]
            );
        }
        bytes memory expectedEncodedData = abi.encodePacked(
            expectedPathData,
            expectedAmountsData,
            deadline
        );
        bytes32 expectedHash = keccak256(expectedEncodedData);

        assertEq(
            encodedData,
            expectedEncodedData,
            "Encoded swap data does not match expected"
        );
        assertEq(
            keccak256(encodedData),
            expectedHash,
            "Encoded swap data hash does not match expected"
        );
    }

    function testEncodeSwapDataWithMismatchedLengths() public {
        address[] memory path = new address[](2);
        path[0] = address(0x123);
        path[1] = address(0x456);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)",
                "Path and amounts length mismatch"
            )
        );
        abiEncoder.encodeSwapData(path, amounts, deadline);
    }

    function testEncodeLimitOrder() public {
        address maker = address(0x123);
        address taker = address(0x456);
        address tokenIn = address(0x789);
        address tokenOut = address(0xabc);
        uint256 amountIn = 1 ether;
        uint256 amountOut = 2 ether;
        uint256 nonce = 42;

        (bytes32 orderId, bytes memory encodedData) = abiEncoder
            .encodeLimitOrder(
                maker,
                taker,
                tokenIn,
                tokenOut,
                amountIn,
                amountOut,
                nonce
            );

        bytes memory expectedData = abi.encodePacked(
            maker,
            taker,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            nonce,
            "LIMIT_ORDER"
        );
        bytes32 expectedOrderId = keccak256(expectedData);

        assertEq(
            orderId,
            expectedOrderId,
            "Encoded limit order ID does not match expected"
        );
        assertEq(
            encodedData,
            expectedData,
            "Encoded limit order data does not match expected"
        );
    }

    function testEncodeYieldFarmingPosition() public {
        address user = address(0x123);
        uint256 fee = 3000;
        bytes32 poolId = keccak256(
            abi.encodePacked(address(0x456), address(0x789), fee)
        );
        uint256 amount = 1 ether;
        uint256 startTime = block.timestamp;

        (bytes32 positionId, bytes memory encodedData) = abiEncoder
            .encodeYieldFarmingPosition(user, poolId, amount, startTime);

        bytes memory expectedData = abi.encodePacked(
            user,
            poolId,
            amount,
            startTime,
            "YIELD_FARMING"
        );
        bytes32 expectedPositionId = keccak256(expectedData);

        assertEq(
            positionId,
            expectedPositionId,
            "Encoded yield farming position ID does not match expected"
        );
        assertEq(
            encodedData,
            expectedData,
            "Encoded yield farming position data does not match expected"
        );
    }

    function testEncodeFlashLoan() public {
        address token = address(0x123);
        uint256 amount = 1 ether;
        bytes memory callbackData = abi.encodePacked("callback");

        (bytes32 positionId, bytes memory encodedData) = abiEncoder
            .encodeFlashLoan(token, amount, callbackData);

        bytes memory expectedData = abi.encodePacked(
            token,
            amount,
            callbackData,
            "FLASH_LOAN"
        );
        bytes32 expectedPositionId = keccak256(expectedData);

        assertEq(
            positionId,
            expectedPositionId,
            "Encoded flash loan position ID does not match expected"
        );
        assertEq(
            encodedData,
            expectedData,
            "Encoded flash loan data does not match expected"
        );
    }

    function testEncodeStakingPoolConfiguration() public {
        address token = address(0x123);
        uint256 rewardRate = 100;
        uint256 lockPeriod = 30 days;
        uint256 maxStakers = 1000;

        bytes memory encodedData = abiEncoder.encodeStakingPoolConfiguration(
            token,
            rewardRate,
            lockPeriod,
            maxStakers
        );

        bytes memory expectedData = abi.encodePacked(
            token,
            rewardRate,
            lockPeriod,
            maxStakers,
            block.timestamp,
            "STAKING_POOL"
        );
        bytes32 expectedHash = keccak256(expectedData);

        assertEq(
            encodedData,
            expectedData,
            "Encoded staking pool configuration data does not match expected"
        );
        assertEq(
            keccak256(encodedData),
            expectedHash,
            "Encoded staking pool configuration hash does not match expected"
        );
    }

    function testCreateUserMultiPoolHash() public {
        address user = address(0x123);
        bytes32[] memory poolIds = new bytes32[](2);
        uint256 fee1 = 3000;
        uint256 fee2 = 500;
        poolIds[0] = keccak256(
            abi.encodePacked(address(0x456), address(0x789), fee1)
        );
        poolIds[1] = keccak256(
            abi.encodePacked(address(0xabc), address(0xdef), fee2)
        );

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        bytes32 multiPoolHash = abiEncoder.createUserMultiPoolHash(
            user,
            poolIds,
            amounts
        );

        bytes memory expectedData;
        for (uint256 i = 0; i < poolIds.length; i++) {
            expectedData = abi.encodePacked(
                expectedData,
                user,
                poolIds[i],
                amounts[i]
            );
        }
        bytes32 expectedHash = keccak256(expectedData);

        assertEq(
            multiPoolHash,
            expectedHash,
            "User multi-pool hash does not match expected"
        );
    }

    function testCreateUserMultiPoolHashWithMismatchedLengths() public {
        address user = address(0x123);
        bytes32[] memory poolIds = new bytes32[](2);
        uint256 fee1 = 3000;
        uint256 fee2 = 500;
        poolIds[0] = keccak256(
            abi.encodePacked(address(0x456), address(0x789), fee1)
        );
        poolIds[1] = keccak256(
            abi.encodePacked(address(0xabc), address(0xdef), fee2)
        );

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)",
                "Pool IDs and amounts length mismatch"
            )
        );
        abiEncoder.createUserMultiPoolHash(user, poolIds, amounts);
    }

    function testEncodeYieldStrategy() public {
        string memory strategyName = "MyYieldStrategy";
        address[] memory pools = new address[](2);
        pools[0] = address(0x456);
        pools[1] = address(0x789);

        uint256[] memory weights = new uint256[](2);
        weights[0] = 70;
        weights[1] = 30;

        bytes memory encodedData = abiEncoder.encodeYieldStrategy(
            strategyName,
            pools,
            weights
        );

        bytes memory expectedPoolsData;
        for (uint256 i = 0; i < pools.length; i++) {
            expectedPoolsData = abi.encodePacked(
                expectedPoolsData,
                pools[i],
                weights[i]
            );
        }
        bytes memory expectedEncodedData = abi.encodePacked(
            strategyName,
            expectedPoolsData,
            block.timestamp,
            "YIELD_STRATEGY"
        );

        assertEq(
            encodedData,
            expectedEncodedData,
            "Encoded yield strategy data does not match expected"
        );
    }

    function testEncodeYieldStrategyWithMismatchedLengths() public {
        string memory strategyName = "MyYieldStrategy";
        address[] memory pools = new address[](2);
        pools[0] = address(0x456);
        pools[1] = address(0x789);

        uint256[] memory weights = new uint256[](1);
        weights[0] = 100;

        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)",
                "Pools and weights length mismatch"
            )
        );
        abiEncoder.encodeYieldStrategy(strategyName, pools, weights);
    }

    function testEncodeCrossChainBridgeData() public {
        uint256 sourceChainId_ = 1;
        uint256 destinationChainId = 137;
        address token = address(0x456);
        uint256 amount = 1 ether;
        address recipient = address(0x789);

        bytes memory encodedData = abiEncoder.encodeCrossChainBridgeData(
            sourceChainId_,
            destinationChainId,
            token,
            amount,
            recipient
        );

        bytes memory expectedData = abi.encodePacked(
            sourceChainId_,
            destinationChainId,
            token,
            amount,
            recipient,
            "CROSS_CHAIN_BRIDGE"
        );
        bytes32 expectedHash = keccak256(expectedData);

        assertEq(
            encodedData,
            expectedData,
            "Encoded cross-chain bridge data does not match expected"
        );
        assertEq(
            keccak256(encodedData),
            expectedHash,
            "Encoded cross-chain bridge data hash does not match expected"
        );
    }

    function testCreateDefiTransactionId() public {
        string memory txType = "DEFI_TRANSACTION";
        address user = address(0x123);
        uint256 amount = 1 ether;
        uint256 timestamp = block.timestamp;
        uint256 nonce = 42;

        bytes32 txId = abiEncoder.createDefiTransactionId(
            txType,
            user,
            amount,
            timestamp,
            nonce
        );

        bytes memory expectedData = abi.encodePacked(
            txType,
            user,
            amount,
            timestamp,
            nonce,
            "DEFI_TX"
        );
        bytes32 expectedTxId = keccak256(expectedData);

        assertEq(
            txId,
            expectedTxId,
            "Defi transaction ID does not match expected"
        );
    }

    function testEncodeStopLossOrder() public {
        address user = address(0x123);
        address token = address(0x456);
        uint256 amount = 1 ether;
        uint256 stopPrice = 2000;

        (bytes32 orderId, bytes memory encodedData) = abiEncoder
            .encodeStopLossOrder(user, token, amount, stopPrice);

        bytes memory expectedData = abi.encodePacked(
            user,
            token,
            amount,
            stopPrice,
            "STOP_LOSS_ORDER"
        );
        bytes32 expectedOrderId = keccak256(expectedData);

        assertEq(
            orderId,
            expectedOrderId,
            "Stop loss order ID does not match expected"
        );
        assertEq(
            encodedData,
            expectedData,
            "Encoded stop loss order data does not match expected"
        );
    }

    function testEncodeTakeProfitOrder() public {
        address user = address(0x123);
        address token = address(0x456);
        uint256 amount = 1 ether;
        uint256 takeProfitPrice = 3000;

        (bytes32 orderId, bytes memory encodedData) = abiEncoder
            .encodeTakeProfitOrder(user, token, amount, takeProfitPrice);

        bytes memory expectedData = abi.encodePacked(
            user,
            token,
            amount,
            takeProfitPrice,
            "TAKE_PROFIT_ORDER"
        );
        bytes32 expectedOrderId = keccak256(expectedData);

        assertEq(
            orderId,
            expectedOrderId,
            "Take profit order ID does not match expected"
        );
        assertEq(
            encodedData,
            expectedData,
            "Encoded take profit order data does not match expected"
        );
    }

    function testEncodeTrailingStopOrder() public {
        address user = address(0x123);
        address token = address(0x456);
        uint256 amount = 1 ether;
        uint256 trailingPercent = 5;
        uint256 activationPrice = 2000;

        (bytes32 orderId, bytes memory encodedData) = abiEncoder
            .encodeTrailingStopOrder(
                user,
                token,
                amount,
                trailingPercent,
                activationPrice
            );

        bytes memory expectedData = abi.encodePacked(
            user,
            token,
            amount,
            trailingPercent,
            activationPrice,
            "TRAILING_STOP_ORDER"
        );
        bytes32 expectedOrderId = keccak256(expectedData);

        assertEq(
            orderId,
            expectedOrderId,
            "Trailing stop order ID does not match expected"
        );
        assertEq(
            encodedData,
            expectedData,
            "Encoded trailing stop order data does not match expected"
        );
    }
}
