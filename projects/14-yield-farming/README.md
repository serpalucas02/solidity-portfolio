# 14 — Yield Farming

> Protocolo de **yield farming / staking con rewards**: los usuarios depositan (stake) un token y van acumulando recompensas en otro token, proporcionales a **cuánto** stakearon y por **cuánto tiempo**. Implementa el patrón **`rewardPerToken` + `rewardDebt`** (el mismo que usan MasterChef de Sushi y StakingRewards de Synthetix). Construido con Foundry + OpenZeppelin.

## Descripción

La idea del yield farming es repartir un flujo continuo de recompensas entre todos los que stakean, **en proporción a su participación y al tiempo**. El desafío es hacerlo **sin loopear sobre todos los usuarios** en cada operación (eso sería carísimo e inescalable en gas).

La solución es el patrón del **acumulador global**:

- El contrato mantiene un solo número, `rewardPerTokenStored`, que representa *"cuánta recompensa acumuló cada token stakeado desde que arrancó el pool"*. Solo sube, con el paso del tiempo.
- Cada usuario tiene un `rewardDebt`: la **marca de agua** de hasta dónde ya cobró del acumulador.
- Lo pendiente de un usuario es siempre:

  ```
  pending = (tokensStakeados × rewardPerTokenStored) − rewardDebt
  ```

Cada vez que un usuario stakea, retira o claimea, el contrato actualiza el acumulador (`_updatePool`) y reajusta su `rewardDebt`, de modo que nunca cobra de más ni de menos.

## Conceptos aplicados

- **Acumulador `rewardPerTokenStored`**: en lugar de recalcular la recompensa de cada usuario en un loop, un único número global hace el trabajo. Cuando un usuario interactúa, su parte sale de una resta. O(1) por usuario, sin importar cuántos haya.
- **`rewardDebt` (marca de agua)**: marca el punto del acumulador desde el cual el usuario tiene derecho a cobrar. Es lo que evita el **doble cobro**: tras claimear, `rewardDebt` se iguala al acumulador y el pending vuelve a 0.
- **`_updatePool()` antes de tocar el estado**: antes de cualquier operación que cambie el total stakeado, se actualiza el acumulador con las rewards generadas desde la última vez (`tiempoTranscurrido × rewardRate`). Si no, el reparto saldría mal.
- **Escala `1e18`**: como Solidity no maneja decimales, el acumulador se escala por `1e18` para no perder precisión por redondeo en la división, y se divide al final del cálculo.
- **Dos tokens distintos**: lo que se **stakea** (staking token) y lo que se **cobra** (reward token) son ERC-20 separados. El pool paga rewards desde su propio balance de reward token.
- **`SafeERC20`** (`safeTransfer` / `safeTransferFrom`) para mover los tokens, y **`ReentrancyGuard`** (`nonReentrant`) en `stake`/`withdraw`/`claimReward` por las llamadas externas con value — ambos default del curso.

## Contratos

- [`src/MockToken.sol`](src/MockToken.sol) — ERC-20 de prueba (`Ownable`) con `mint`/`burn` para fondear cuentas y el pool en los tests. Se usa tanto como staking token como reward token.
- [`src/YieldFarmingPool.sol`](src/YieldFarmingPool.sol) — el protocolo: `createPool`, `stake`, `withdraw`, `claimReward`, `updatePoolRewardRate`, `emergencyWithdraw` y getters (`getPoolEncodedData`, `getUserHash`, `getActivePools`). El `getPoolEncodedData` reaprovecha el encoding/hashing del módulo 13 para serializar el estado de la pool.

## Tests

**24 tests, 100% de coverage** (líneas, statements, branches y funciones) en ambos contratos.

Los más relevantes (los que prueban la *lógica* del patrón, no solo que las líneas se ejecuten):

- `testRewardsSplitProportionallyBetweenStakers` — dos stakers (25% / 75%) → las rewards se reparten exactamente en esa proporción. **El test que valida que el farm es justo.**
- `testClaimTwicePaysOnlyOnce` — claimear dos veces sin que pase tiempo revierte. Prueba que `rewardDebt` cierra la puerta al doble cobro.
- `testSecondStakeAutoClaimsPending` — stakear de nuevo liquida primero lo pendiente del tramo anterior.
- `testRewardCappedWhenPoolUnderfunded` — si el pool no tiene rewards suficientes, paga lo que le queda (no revierte).

Patrones de testing usados: **`vm.warp`** para avanzar el tiempo y acumular rewards, **`vm.startPrank`/`vm.prank`** para simular varios usuarios, y **comparación de balances `before`/`after`** (deltas) para verificar que los tokens se mueven de verdad, no solo que la contabilidad interna cambió.

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/14-yield-farming`).

```bash
# Compilar
forge build

# Correr toda la suite (24 tests)
forge test

# Con traces detallados
forge test -vvv

# Un test específico
forge test --match-test testRewardsSplitProportionallyBetweenStakers -vv

# Reporte de cobertura
forge coverage
```

## Aprendizajes

- **El patrón "acumulador − marca de agua"** se entiende mejor con la analogía del medidor de luz: `rewardPerTokenStored` es el número del medidor (siempre sube), y `rewardDebt` es la lectura de tu última factura. Pagás la diferencia.
- **Un test que solo mira variables internas es un test a medias.** Verificar el `amount` del struct no garantiza que el `transfer` haya ocurrido — hay que medir el **delta de `balanceOf`** para probar que la plata se movió.
- **Las expectativas del test tienen que reflejar lo que el contrato hace, no lo que uno imagina** que "debería" hacer. Ej: `claimReward` no hace unstake, y en el primer stake el `rewardDebt` es 0 (no el monto stakeado).
- **`address(123)` no es un ERC-20.** En cuanto el contrato interactúa con el token (`transfer`, `balanceOf`), hace falta un mock real deployado — y `approve` antes de cada `stake`, porque el pool hace `transferFrom`.

## Posibles mejoras

- **No se pueden pausar pools**: `isActive` se setea en `true` al crear y nunca cambia. Para testear el revert "pool is not active" hubo que usar un `poolId` inexistente. Una función `setPoolActive(bool)` para `onlyOwner` cerraría el ciclo de vida.
- **`lastClaimTime` es un campo muerto**: se guarda pero no participa en ningún cálculo (el tiempo se trackea vía `lastUpdateTime` del pool). O se le da uso (ej. lock-up period) o se elimina para ahorrar gas.
- **Rewards no garantizados**: si el pool se queda corto de reward token, `_safeRewardTransfer` paga lo que hay **en silencio**. Un protocolo real registraría la deuda pendiente o revertiría para no romper la contabilidad del usuario.
- **`emergencyWithdraw` no distingue** entre reward token y tokens stakeados por los usuarios → riesgo de centralización (el owner podría retirar el stake ajeno). Convendría restringirlo solo al excedente de rewards.
- **`require` con strings** en lugar de custom errors (más caros en gas y menos idiomáticos en 0.8+).
