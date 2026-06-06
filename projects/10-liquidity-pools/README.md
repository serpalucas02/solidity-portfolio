# 10 — Liquidity Pools (Uniswap V2)

> Segundo proyecto del portfolio integrando con Uniswap V2. Ahora del lado **proveedor de liquidez**: un contrato propio que **swappea + agrega liquidez en un combo atómico** y permite **retirarla** después. Continuación natural del proyecto 09 (Swapping App).

## Descripción

El contrato `SwappingApp` (heredado del proyecto 09 y extendido) hace tres cosas:

1. **`swapTokens`** — wrapper de `swapExactTokensForTokens` (mismo del proyecto 09).
2. **`addLiquidity`** — combo "swap + add liquidity" en una sola tx: el user manda `X` de USDC, el contrato swappea `X/2` por DAI, y agrega `X/2` USDC + el DAI swappeado al pool USDC/DAI. El user recibe los **LP tokens** en su wallet.
3. **`removeLiquidity`** — el user devuelve sus LP tokens, el contrato los redime contra el pool y le manda al user los dos tokens subyacentes (USDC + DAI).

El **insight clave** del combo "swap + add liquidity": si solo tenés un token y querés ser LP de un par, normalmente harías dos transacciones (swap, después add). Acá lo hacés en una sola, lo que te ahorra gas, evita slippage entre las dos tx y simplifica la UX.

Testeado con **fork de Arbitrum** contra el router real de Uniswap V2 y los pools de USDC/DAI reales.

## Features implementadas

- ✅ **Pools de liquidez** — entendimiento de la fórmula `x * y = k` y rol de los LP tokens como "recibo" de la porción del pool.
- ✅ **Añadir liquidez a la pool** — `addLiquidity(...)` del router, con `amountAMin`/`amountBMin` como protección de slippage.
- ✅ **Swap tokens + añadir liquidez** — combo atómico en `SwappingApp.addLiquidity`.
- ✅ **Testing: añadir liquidez** — `testSwapAndAddLiquidity` con verificación de balances de USDC y DAI tras la operación.
- ✅ **Fix errors** — debugging típico que apareció en el camino: `stack too deep` (resuelto con `via_ir`), `EXPIRED` (deadline hardcodeado), `ds-math-sub-underflow` (LP tokens no pulled antes del approve).
- ✅ **Quitar liquidez de la pool** — `removeLiquidity(...)` con `transferFrom` de LP tokens al contrato + `forceApprove` al router + llamada al router.

**Estado final**: 4/4 tests pasando ✅ (con fork de Arbitrum)

## Estructura del proyecto

```
10-liquidity-pools/
├── foundry.toml                       ← Solidity 0.8.24 + Cancun + via_ir + optimizer
├── remappings.txt                     ← @openzeppelin/contracts/, forge-std/
├── src/
│   ├── SwappingApp.sol                ← contrato extendido con add/remove liquidity
│   └── interfaces/
│       ├── IV2Router02.sol            ← swap, addLiquidity, removeLiquidity
│       └── IV2Factory.sol             ← getPair (para encontrar la address del pool)
├── test/
│   └── SwappingApp.t.sol              ← 4 tests con fork de Arbitrum
└── lib/
    ├── forge-std/                     ← cheatcodes y asserts
    └── openzeppelin-contracts/        ← IERC20, SafeERC20
```

## Contratos y tests

- [`src/SwappingApp.sol`](src/SwappingApp.sol) — wrapper de Uniswap V2 con swap + add + remove liquidity.
- [`src/interfaces/IV2Router02.sol`](src/interfaces/IV2Router02.sol) — interfaz mínima del Router (`swapExactTokensForTokens`, `addLiquidity`, `removeLiquidity`).
- [`src/interfaces/IV2Factory.sol`](src/interfaces/IV2Factory.sol) — interfaz mínima del Factory (`getPair`) para resolver la address del pool de un par dado.
- [`test/SwappingApp.t.sol`](test/SwappingApp.t.sol) — 4 tests con fork de Arbitrum (deploy + swap + add liq + remove liq).

## Conceptos aplicados

### DeFi / Uniswap

- **LP tokens (Liquidity Provider tokens)**: cuando agregás liquidez, el pool te emite un token ERC-20 que representa **tu porcentaje del pool**. Es tu "recibo" que después intercambiás por los tokens subyacentes en el remove. **El pool de USDC/DAI tiene su propio contrato ERC-20** que actúa como LP token.
- **`addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline)`**: el router toma `amountADesired` y `amountBDesired` del caller, calcula la proporción correcta según las reservas actuales del pool, y agrega lo que pueda en esa proporción. Si tenés que poner más de un token y menos del otro para matchear la proporción, te devuelve el sobrante (de ahí los `Min`).
- **`removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline)`**: le pasás cuántos LP tokens querés redimir, y los `min` aceptables de cada token. El router quema tus LP tokens y te transfiere la porción correspondiente del pool.
- **Factory + Router (separación de responsabilidades)**: el Factory crea pools y mantiene el registro `tokenA + tokenB → pool address`. El Router orquesta las operaciones complejas (swap, add, remove) usando el Factory para resolver direcciones. Para obtener la address del LP token de un par, llamás `factory.getPair(tokenA, tokenB)`.
- **Impermanent loss**: si el precio relativo de los dos tokens cambia mientras estás en el pool, el valor de tus LP tokens puede ser menor que si hubieras hold-eado los dos por separado. Lo compensan parcialmente las fees del swap (~0.30% por trade que pasa por el pool).
- **Combo swap + add liquidity**: si solo tenés USDC y querés ser LP del par USDC/DAI, **necesitás tener ambos**. La forma "manual" es: swap USDC→DAI, después add liquidity con USDC + DAI. La forma "atómica" es lo que hace este contrato: ambas operaciones en una sola tx.

### Patrones de Solidity / wrapper de protocolos

- **El triple patrón `transferFrom → forceApprove → router.X`**: cada vez que tu contrato actúa como intermediario entre el user y un protocolo externo, tiene que:
  1. Chupar los tokens del user al contrato (`safeTransferFrom`).
  2. Autorizar al protocolo a usar esos tokens (`forceApprove`).
  3. Llamar al protocolo.
  Se aplica idéntico en `swapTokens`, `addLiquidity` y `removeLiquidity` — solo cambia el token y la función final.
- **`forceApprove`** consistente para cubrir tokens estilo USDT que reverten `approve(X)` si ya hay allowance.
- **Reusar funciones públicas internamente**: `addLiquidity` llama a `swapTokens` con `to_ = address(this)` para que el output quede en el contrato. Cuando se llama así, `msg.sender` sigue siendo el caller original (el user), por lo que el `safeTransferFrom` interno también funciona.
- **`via_ir = true` + `optimizer`**: pipeline de compilación Yul-IR + optimizer para evitar `stack too deep` (común en funciones con muchas variables locales y parámetros, típico en tests de DeFi).

### Foundry / forge-std

- **Fork testing** contra Arbitrum mainnet (router de Uniswap V2 real, USDC real, DAI real).
- **Whale prank**: identificar un user real con balance de USDC en Arbitrum y usar `vm.startPrank` para impersonarlo.
- **`assertEq` y `assert`** con direcciones correctas (`>=` para "después debe haber al menos esto", `==` para "exacto", etc.).
- **`block.timestamp + 1 hours`** como deadline dinámico → los tests siguen verdes sin importar cuándo se corran.

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/10-liquidity-pools`).

### Build local

```bash
forge build
```

### Fork test (necesita RPC de Arbitrum)

`.env` con:

```bash
ARBITRUM_RPC=https://arb-mainnet.g.alchemy.com/v2/<TU_API_KEY>
# o un public RPC:
# ARBITRUM_RPC=https://arb1.arbitrum.io/rpc
```

```bash
source .env
forge test --fork-url $ARBITRUM_RPC -vvv
```

### Tests incluidos

| Test | Qué prueba |
|---|---|
| `testDeployCorrectly` | Verifica que la address del router quedó seteada |
| `testSwapTokens` | Swap USDC → DAI con balances antes/después |
| `testSwapAndAddLiquidity` | Combo swap + add liquidity con balances post |
| `testRemoveLiquidity` | Add → remove en el mismo test, verifica recupero >= mins |

## Aprendizajes

- **El combo "swap + add" en una sola tx es un patrón real**: muchos frontends (1inch, Zapper, etc.) lo usan internamente. Aprender a componerlo te abre la puerta a entender protocolos más sofisticados.
- **Tres bugs típicos que aparecieron en el camino** (y las lecciones):
  - **`stack too deep`** → activar `via_ir = true` en `foundry.toml`. Es **el reflejo correcto** en proyectos Foundry modernos, no "deformar" el código para acomodar la limitación.
  - **`UniswapV2Router: EXPIRED`** → nunca hardcodear timestamps. Siempre `block.timestamp + N`.
  - **`ds-math-sub-underflow` en removeLiquidity** → recordar que **los LP tokens viven en la wallet del user**, no en el contrato. Si tu wrapper quiere usar el router, primero `safeTransferFrom` los LP tokens al contrato y *después* `approve` al router.
- **El triple patrón es universal**: una vez que ves `safeTransferFrom → forceApprove → router.X` en 3-4 contratos distintos, lo internalizás como "el patrón estándar de wrapper de protocolo".
- **Los LP tokens son ERC-20 normales**: tienen `balanceOf`, `transfer`, `approve`. Eso te deja moverlos como cualquier otro token (incluso comerciar con ellos en un marketplace, usarlos como colateral, etc.).
- **El Factory de Uniswap es el "directorio telefónico" de los pools**: si no sabés la address del LP token de un par, llamás `factory.getPair(tokenA, tokenB)` y te la devuelve.
- **Para resolver direcciones de pools y de LP tokens, ya no estás en Solidity puro — estás "tirando llamadas RPC desde Solidity"**: tu contrato hace `staticcall` al factory de Uniswap. Esa composability solo es posible porque ambos contratos viven en la misma chain.
- **Fork testing > deploy a testnet** para validar integraciones con protocolos reales: tu fork tiene **el USDC real, el DAI real, los pools reales con liquidez real**. En testnet esos contratos no existen o están vacíos.

## Posibles mejoras

### 🔒 Generalidad y robustez

- **Quitar `USDC`/`DAI` hardcodeados**: hoy el contrato solo funciona para ese par. Pasar los tokens como parámetros de `addLiquidity` y `removeLiquidity` lo haría agnóstico para cualquier par.
- **`USDC` y `DAI` como `immutable`**: ya que se setean en el constructor y no cambian, declararlas `immutable` ahorra un SLOAD por lectura (mismo patrón que `V2Router02Address`).
- **Unificar las dos `safeTransferFrom` en `addLiquidity`**: actualmente se hace `safeTransferFrom(user, swappingApp, amountIn_/2)` directo + otra interna vía `swapTokens`. Se podría refactorizar a una sola pull al inicio para ahorrar gas (un SSTORE menos en el token).
- **Custom errors** en vez de los revert strings que vengan del router.
- **`receive()`** en caso de querer soportar ETH → WETH directo (para usuarios que no tienen ya WETH).

### 🧪 Testing

- **`vm.expectEmit`** para verificar que `LiquidityAdded` se emite con los argumentos correctos.
- **Test de `removeLiquidity` independiente** (no encadenado al add): hoy `testRemoveLiquidity` hace add → remove en el mismo test. Un test que setee un balance de LP tokens vía `deal()` y solo testee el remove sería más unitario.
- **Test con paths multi-hop** (USDC → WETH → DAI) para validar que el combo swap + add funciona si el pool directo no existe.
- **Pin del bloque con `--fork-block-number`** para hacer los tests 100% reproducibles.

### 🛠️ Features

- **Soporte para pares con ETH** usando `addLiquidityETH` y `removeLiquidityETH` del router.
- **Script de deploy** (`script/DeploySwappingApp.s.sol`) para deployar a testnet de Arbitrum.
- **Función "rebalance"** que cierra una posición LP y abre otra en un par distinto, en una sola tx.
- **Compatibilidad con Uniswap V3**: V3 tiene posiciones concentradas en rangos de precio, requiere otra interfaz (NonfungiblePositionManager) y los "LP tokens" son NFTs en lugar de ERC-20.
