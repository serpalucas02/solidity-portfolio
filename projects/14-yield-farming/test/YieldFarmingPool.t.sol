// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldFarmingPool} from "../src/YieldFarmingPool.sol";
import {MockToken} from "../src/MockToken.sol";

contract YieldFarmingPoolTest is Test {
    YieldFarmingPool public pool;
    MockToken public stakingToken; // el token que los users depositan
    MockToken public rewardToken; // el token con el que se pagan las recompensas

    // poolId que NO existe: sirve para forzar el revert "pool is not active"
    bytes32 internal constant FAKE_POOL_ID = keccak256("does-not-exist");

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        // address(this) (el contrato de test) es owner y deployer de los tres.
        stakingToken = new MockToken("Staking Token", "STK", 1000);
        rewardToken = new MockToken("Reward Token", "RWD", 1000);
        pool = new YieldFarmingPool(address(rewardToken));

        // El pool paga rewards desde SU PROPIO balance de rewardToken,
        // asi que hay que fondearlo o no va a poder pagar nada.
        rewardToken.mint(address(pool), 1_000_000 * 1e18);
    }

    // Helper: le da tokens a `user`, lo hace aprobar y stakear `amount`.
    // Todo lo que va dentro de start/stopPrank corre como si fuera `user`.
    function _stakeAs(address user, bytes32 poolId, uint256 amount) internal {
        stakingToken.mint(user, amount); // como owner del token (sin prank)
        vm.startPrank(user);
        stakingToken.approve(address(pool), amount);
        pool.stake(poolId, amount);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // createPool
    // ---------------------------------------------------------------------

    function testCreatePool() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);

        (
            address token,
            uint256 totalStaked,
            uint256 rewardRate,
            ,
            ,
            bool isActive
        ) = pool.pools(poolId);

        assertEq(token, address(stakingToken));
        assertEq(rewardRate, 100);
        assertEq(totalStaked, 0);
        assertTrue(isActive);
    }

    function testCreatePoolFail() public {
        vm.expectRevert("YieldFarmingPool: token is zero address");
        pool.createPool(address(0), 100);

        vm.expectRevert("YieldFarmingPool: rewardRate must be greater than 0");
        pool.createPool(address(stakingToken), 0);
    }

    // El constructor rechaza un rewardToken en address(0).
    function testConstructorRejectsZeroRewardToken() public {
        vm.expectRevert("YieldFarmingPool: rewardToken is zero address");
        new YieldFarmingPool(address(0));
    }

    // Mismo token + rate + bloque -> mismo poolId -> no se puede duplicar.
    function testCreatePoolRejectsDuplicate() public {
        pool.createPool(address(stakingToken), 100);

        vm.expectRevert("YieldFarmingPool: pool exists");
        pool.createPool(address(stakingToken), 100);
    }

    // ---------------------------------------------------------------------
    // stake
    // ---------------------------------------------------------------------

    function testStake() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);

        // sin approve, el safeTransferFrom de adentro del stake revierte.
        stakingToken.approve(address(pool), 100);

        uint256 balanceBefore = stakingToken.balanceOf(address(this));
        pool.stake(poolId, 100);

        // los 100 tokens salieron de mi balance hacia el pool
        assertEq(stakingToken.balanceOf(address(this)), balanceBefore - 100);
        assertEq(stakingToken.balanceOf(address(pool)), 100);

        (uint256 amount, uint256 rewardDebt, uint256 lastClaimTime) = pool
            .users(poolId, address(this));

        assertEq(amount, 100);
        // En el PRIMER stake rewardPerTokenStored todavia es 0, asi que
        // rewardDebt = amount * 0 / 1e18 = 0 (NO 100).
        assertEq(rewardDebt, 0);
        assertEq(lastClaimTime, block.timestamp);
    }

    function testStakeFail() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);

        // amount == 0 revierte antes de tocar el token (no necesita approve)
        vm.expectRevert("YieldFarmingPool: amount must be greater than 0");
        pool.stake(poolId, 0);

        // un poolId inexistente tiene isActive == false
        vm.expectRevert("YieldFarmingPool: pool is not active");
        pool.stake(FAKE_POOL_ID, 100);
    }

    // ---------------------------------------------------------------------
    // withdraw
    // ---------------------------------------------------------------------

    function testWithdraw() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);
        stakingToken.approve(address(pool), 100);
        pool.stake(poolId, 100);

        uint256 balanceBefore = stakingToken.balanceOf(address(this));
        pool.withdraw(poolId, 50);

        // recupere 50 tokens de vuelta
        assertEq(stakingToken.balanceOf(address(this)), balanceBefore + 50);

        (uint256 amount, uint256 rewardDebt, uint256 lastClaimTime) = pool
            .users(poolId, address(this));

        assertEq(amount, 50);
        // mismo bloque que el stake -> no paso tiempo -> rewardPerTokenStored
        // sigue 0 -> rewardDebt = 50 * 0 / 1e18 = 0.
        assertEq(rewardDebt, 0);
        assertEq(lastClaimTime, block.timestamp);
    }

    function testWithdrawFail() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);
        stakingToken.approve(address(pool), 100);
        pool.stake(poolId, 100);

        vm.expectRevert("YieldFarmingPool: amount must be greater than 0");
        pool.withdraw(poolId, 0);

        vm.expectRevert("YieldFarmingPool: amount exceeds balance");
        pool.withdraw(poolId, 150);

        vm.expectRevert("YieldFarmingPool: pool is not active");
        pool.withdraw(FAKE_POOL_ID, 100);
    }

    // ---------------------------------------------------------------------
    // claimReward
    // ---------------------------------------------------------------------

    function testClaimReward() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);
        stakingToken.approve(address(pool), 100);
        pool.stake(poolId, 100);

        // avanzo 100 segundos para que se acumulen recompensas
        vm.warp(block.timestamp + 100);

        uint256 rewardBefore = rewardToken.balanceOf(address(this));
        pool.claimReward(poolId);
        uint256 rewardAfter = rewardToken.balanceOf(address(this));

        // recompensa = timeElapsed * rewardRate = 100 * 100 = 10000
        assertEq(rewardAfter - rewardBefore, 10000);

        (uint256 amount, uint256 rewardDebt, uint256 lastClaimTime) = pool
            .users(poolId, address(this));

        // claimReward NO hace unstake: el amount stakeado sigue intacto.
        assertEq(amount, 100);
        // rewardDebt se actualiza al acumulado: amount * rewardPerTokenStored / 1e18.
        assertEq(rewardDebt, 10000);
        assertEq(lastClaimTime, block.timestamp);
    }

    function testClaimRewardFail() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);

        // sin stake previo, user.amount == 0
        vm.expectRevert("YieldFarmingPool: user has no staked tokens");
        pool.claimReward(poolId);

        // pool inexistente -> inactiva
        vm.expectRevert("YieldFarmingPool: pool is not active");
        pool.claimReward(FAKE_POOL_ID);
    }

    // ---------------------------------------------------------------------
    // updatePoolRewardRate
    // ---------------------------------------------------------------------

    function testUpdatePoolRewardRate() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);

        pool.updatePoolRewardRate(poolId, 200);

        (, , uint256 rewardRate, , , ) = pool.pools(poolId);
        assertEq(rewardRate, 200);
    }

    function testUpdatePoolRewardRateFail() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);

        vm.expectRevert(
            "YieldFarmingPool: new reward rate must be greater than 0"
        );
        pool.updatePoolRewardRate(poolId, 0);

        vm.expectRevert("YieldFarmingPool: pool is not active");
        pool.updatePoolRewardRate(FAKE_POOL_ID, 100);
    }

    // ---------------------------------------------------------------------
    // getters / helpers
    // ---------------------------------------------------------------------

    function testGetPoolEncodedData() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);
        stakingToken.approve(address(pool), 100);
        pool.stake(poolId, 100);

        bytes memory encodedData = pool.getPoolEncodedData(poolId);

        // Reconstruyo el blob esperado con los mismos campos del struct y
        // comparo bytes contra bytes (assertEq(bytes, bytes) si existe).
        (
            address token,
            uint256 totalStaked,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored,
            bool isActive
        ) = pool.pools(poolId);

        bytes memory expected = abi.encodePacked(
            token,
            totalStaked,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored,
            isActive
        );

        assertEq(encodedData, expected);
    }

    function testGetUserHash() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);
        bytes32 userHash = pool.getUserHash(poolId, address(this));

        assertEq(
            userHash,
            keccak256(
                abi.encodePacked(poolId, address(this), "YIELD_FARMING_USER")
            )
        );
    }

    function testGetActivePoolsCount() public {
        pool.createPool(address(stakingToken), 100);
        assertEq(pool.getActivePoolsCount(), 1);
    }

    function testGetActivePools() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);

        bytes32[] memory activePools = pool.getActivePools();
        assertEq(activePools[0], poolId);
    }

    // ---------------------------------------------------------------------
    // Escenarios "de verdad": el patron rewardPerToken / rewardDebt
    // ---------------------------------------------------------------------

    // Dos stakers en la misma pool: las recompensas se reparten
    // PROPORCIONALMENTE a cuanto stakeo cada uno.
    function testRewardsSplitProportionallyBetweenStakers() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);

        // Mismo bloque (t0): alice mete 100, bob mete 300 -> total 400.
        // alice = 25% del pool, bob = 75%.
        _stakeAs(alice, poolId, 100);
        _stakeAs(bob, poolId, 300);

        // Pasan 100 segundos. Recompensa total emitida = 100s * 100 rate = 10000.
        vm.warp(block.timestamp + 100);

        // alice claimea -> le toca 25% de 10000 = 2500
        uint256 aliceBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        pool.claimReward(poolId);
        assertEq(rewardToken.balanceOf(alice) - aliceBefore, 2500);

        // bob claimea -> le toca 75% de 10000 = 7500
        uint256 bobBefore = rewardToken.balanceOf(bob);
        vm.prank(bob);
        pool.claimReward(poolId);
        assertEq(rewardToken.balanceOf(bob) - bobBefore, 7500);
    }

    // Claimear dos veces seguidas sin que pase tiempo NO paga de nuevo:
    // el rewardDebt ya "consumio" lo que se habia acumulado.
    function testClaimTwicePaysOnlyOnce() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);
        _stakeAs(alice, poolId, 100);

        vm.warp(block.timestamp + 100);

        // Primer claim: cobra los 10000 acumulados (alice es la unica staker).
        uint256 before = rewardToken.balanceOf(alice);
        vm.prank(alice);
        pool.claimReward(poolId);
        assertEq(rewardToken.balanceOf(alice) - before, 10000);

        // Segundo claim inmediato: pending = 0 -> revierte. No hay doble cobro.
        vm.prank(alice);
        vm.expectRevert("YieldFarmingPool: no pending rewards");
        pool.claimReward(poolId);
    }

    // Stakear una segunda vez liquida automaticamente los rewards pendientes
    // del primer tramo antes de sumar el nuevo deposito.
    function testSecondStakeAutoClaimsPending() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);

        // Primer stake de alice (100) en t0.
        _stakeAs(alice, poolId, 100);

        // Pasan 100s -> alice acumulo 10000 pendientes (es la unica staker).
        vm.warp(block.timestamp + 100);

        // Segundo stake: el contrato paga lo pendiente ANTES de sumar.
        uint256 before = rewardToken.balanceOf(alice);
        _stakeAs(alice, poolId, 100);
        assertEq(rewardToken.balanceOf(alice) - before, 10000);

        // Y ahora tiene 200 stakeados en total.
        (uint256 amount, , ) = pool.users(poolId, alice);
        assertEq(amount, 200);
    }

    // ---------------------------------------------------------------------
    // Casos borde restantes (coverage)
    // ---------------------------------------------------------------------

    // withdraw con rewards pendientes: ademas de devolver el stake, paga lo
    // acumulado en el mismo movimiento.
    function testWithdrawAlsoPaysPendingRewards() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);
        _stakeAs(alice, poolId, 100);

        // pasa tiempo -> alice acumula 10000 (unica staker)
        vm.warp(block.timestamp + 100);

        uint256 rewardBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        pool.withdraw(poolId, 50);

        // el withdraw liquido los rewards pendientes ademas de devolver el stake
        assertEq(rewardToken.balanceOf(alice) - rewardBefore, 10000);
        assertEq(stakingToken.balanceOf(alice), 50); // recupero 50 de los 100
    }

    // emergencyWithdraw: el owner puede rescatar tokens del pool.
    function testEmergencyWithdraw() public {
        uint256 ownerBefore = rewardToken.balanceOf(address(this));

        // el setUp dejo 1_000_000e18 de rewardToken en el pool
        pool.emergencyWithdraw(address(rewardToken), 1_000 * 1e18);

        assertEq(rewardToken.balanceOf(address(this)), ownerBefore + 1_000 * 1e18);
    }

    // si el pool no tiene rewardToken suficiente, paga lo que le queda en vez
    // de revertir (rama "amount > balance" de _safeRewardTransfer).
    function testRewardCappedWhenPoolUnderfunded() public {
        bytes32 poolId = pool.createPool(address(stakingToken), 100);
        _stakeAs(alice, poolId, 100);

        // vacio el pool y lo dejo con solo 3000 de rewardToken
        pool.emergencyWithdraw(
            address(rewardToken),
            rewardToken.balanceOf(address(pool))
        );
        rewardToken.mint(address(pool), 3000);

        // alice acumula 10000 pendientes, pero el pool solo tiene 3000
        vm.warp(block.timestamp + 100);

        uint256 rewardBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        pool.claimReward(poolId);

        // cobra 3000 (todo lo que habia), no 10000
        assertEq(rewardToken.balanceOf(alice) - rewardBefore, 3000);
    }
}
