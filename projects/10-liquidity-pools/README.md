# 10 — Liquidity Pools (Uniswap V2)

> Segundo proyecto integrando con Uniswap V2: ahora del lado **proveedor de liquidez**. Un contrato propio que **agrega y retira liquidez** de un pool, y opcionalmente combina swap + add liquidity en una sola transacción. Continuación natural del proyecto 09.

## Descripción

_Por completar a medida que avance el proyecto._

## Features del módulo

- [ ] **Pools de liquidez** — qué es un pool, qué son los LP tokens, cómo funciona la fórmula `x * y = k`.
- [ ] **Añadir liquidez a la pool** — `addLiquidity(tokenA, tokenB, amountA, amountB, ...)` del router.
- [ ] **Swap tokens + añadir liquidez** — combo en una sola tx: swappear parte para igualar las cantidades necesarias y agregar liquidez.
- [ ] **Testing: añadir liquidez** — fork test que verifica que el balance de LP tokens aumenta.
- [ ] **Fix errors** — debugging típico del flujo.
- [ ] **Quitar liquidez de la pool** — `removeLiquidity(...)` para retirar los dos tokens del pool a cambio de los LP tokens.

## Conceptos clave (preview)

- **Pool de liquidez**: una caja con dos tokens (`token0`, `token1`) y una "constante" `k = reserva0 * reserva1`. Los swaps cambian las reservas pero respetan la fórmula (menos la fee).
- **LP tokens (Liquidity Provider tokens)**: cuando agregás liquidez, el pool te emite tokens que representan **tu porcentaje del pool**. Si después retirás, intercambiás esos LP tokens por la porción correspondiente de los dos tokens (que pueden ser más o menos que lo que aportaste, según pasaron swaps y fees).
- **`addLiquidity`**: pasás cantidades **deseadas** y **mínimas** de los dos tokens. El router te toma la cantidad que matchee la proporción actual del pool — si pusiste de más en uno, te devuelve el sobrante.
- **`removeLiquidity`**: aprobás los LP tokens al router, le pasás cuántos retirar + mínimos esperados, y te devuelve los dos tokens.
- **Impermanent loss**: si el precio relativo de los dos tokens cambia mientras estás en el pool, el valor de tus LP tokens puede ser menor que si hubieras hold-eado. Lo compensan parcialmente las fees del swap. Es **el principal "costo" de ser LP**.
- **Earning fees**: cada swap que pasa por el pool paga una fee (~0.30% en V2). Esa fee se reparte proporcionalmente entre los LPs, acumulándose como aumento del valor de cada LP token.

## Estructura del proyecto

```
10-liquidity-pools/
├── foundry.toml         ← Solidity 0.8.24, EVM Cancun
├── remappings.txt       ← @openzeppelin/contracts/, forge-std/
├── src/                 ← contratos (LiquidityApp + interfaces)
├── test/                ← tests con fork (Arbitrum)
├── script/              ← scripts de deploy
└── lib/
    ├── forge-std/                ← cheatcodes y asserts
    └── openzeppelin-contracts/   ← IERC20, SafeERC20
```

## Contratos

_Se irán listando a medida que se creen._

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

## Aprendizajes

- _Qué aprendí, qué me costó, qué haría distinto._

## Posibles mejoras

- _Ideas para extender el proyecto._
