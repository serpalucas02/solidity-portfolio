# 09 — Swapping App (Uniswap V2)

> Primer proyecto del portfolio que **integra con un protocolo DeFi real** (Uniswap V2). Un contrato propio que recibe tokens del usuario, los swappea por otro token usando el router de Uniswap, y los devuelve directamente al usuario en la misma tx. Testeado con **fork de Arbitrum** contra los contratos reales de USDC y DAI.

## Descripción

`SwappingApp` es un wrapper minimalista alrededor del **Uniswap V2 Router**. La idea es simple:

1. El usuario quiere swappear un token A por un token B (ej. USDC → DAI).
2. Aprueba a `SwappingApp` para usar sus tokens A.
3. Llama a `swapTokens(amountIn, amountOutMin, path, deadline)`.
4. El contrato chupa los tokens A del usuario, autoriza al router, y le delega el swap.
5. El router devuelve el token B **directo a la wallet del usuario** (no al contrato).
6. `SwappingApp` emite el evento `TokensSwapped` con todos los detalles.

**Insight clave**: el token de salida **nunca toca el `SwappingApp`**. El router lo manda directo del pool a la wallet del usuario. El `SwappingApp` es solo un orquestador — chupa el token de entrada, dispara el swap, y se queda en cero. Esa es la elegancia de la *composability* en DeFi: contratos chiquitos enchufándose con contratos gigantes (Uniswap) en una sola tx atómica.

## Features implementadas

- ✅ **Uniswap - DeFi** — comprensión del modelo AMM (`x * y = k`) y rol del pool.
- ✅ **Integrar protocolos externos (DEX)** — interactuar con Uniswap solo a través de la interfaz `IV2Router02`, sin tener su implementación.
- ✅ **Swapping App** — wrapper propio (`SwappingApp.sol`) con router immutable seteado en el constructor.
- ✅ **Parámetros del Swap** — `amountIn`, `amountOutMin` (slippage), `path` (array de tokens), `deadline` (anti-MEV).
- ✅ **Ejecutar el swap** — patrón `safeTransferFrom` → `approve` → llamar router → DAI va directo al user.
- ✅ **Fork testing** — `forge test --fork-url $ARBITRUM_RPC` corre el test contra el estado real de Arbitrum.
- ✅ **Crear el test** — whale prank desde un user real de Arbitrum con balance de USDC.
- ✅ **Testing del Swap** — verificación de que el balance de USDC baja Y el de DAI sube tras el swap.

**Estado final**: 2/2 tests pasando ✅ (con fork de Arbitrum)

## Estructura del proyecto

```
09-swapping-app/
├── foundry.toml                       ← Solidity 0.8.24, EVM Cancun
├── remappings.txt                     ← @openzeppelin/contracts/, forge-std/
├── src/
│   ├── SwappingApp.sol                ← wrapper del router
│   └── interfaces/
│       └── IV2Router02.sol            ← solo la firma de swapExactTokensForTokens
├── test/
│   └── SwappingApp.t.sol              ← test con fork de Arbitrum (USDC → DAI)
└── lib/
    ├── forge-std/                     ← cheatcodes y asserts
    └── openzeppelin-contracts/        ← IERC20, SafeERC20
```

## Contratos y tests

- [`src/SwappingApp.sol`](src/SwappingApp.sol) — wrapper minimalista alrededor del router de Uniswap V2.
- [`src/interfaces/IV2Router02.sol`](src/interfaces/IV2Router02.sol) — interfaz mínima (solo `swapExactTokensForTokens`) para llamar al router sin importar la implementación.
- [`test/SwappingApp.t.sol`](test/SwappingApp.t.sol) — test con fork de Arbitrum, swappea 5 USDC por DAI usando un user con balance real.

## Conceptos aplicados

### DeFi / Uniswap

- **AMM (Automated Market Maker)**: Uniswap no usa libro de órdenes. Cada par de tokens tiene un *pool* con la fórmula `x * y = k`. Las reservas determinan el precio automáticamente.
- **Pool de liquidez**: una caja con dos compartimentos (token A y token B). Cuando metés A, sale B. La proporción de A y B en el pool define el precio.
- **Router**: el contrato "puerta de entrada" de Uniswap. No interactuás directo con los pools — el router rutea tu swap, calcula montos y maneja paths multi-hop.
- **`path`**: secuencia de tokens que define el camino. `[USDC, DAI]` es directo; `[USDC, WETH, DAI]` pasa por WETH si no hay pool directo.
- **`amountOutMin` (protección de slippage)**: el mínimo aceptable de salida. Si el precio cambia entre que firmás y se ejecuta (otra tx que afecta al pool), te protege de recibir menos de lo esperado.
- **`deadline`**: timestamp después del cual la tx revierte. Evita que una tx vieja se ejecute con precios futuros muy distintos.
- **Composability**: tu contrato puede integrarse con cualquier protocolo deployado en la chain sin necesidad de su código fuente — solo conociendo su interfaz.

### Patrones de Solidity

- **`using SafeERC20 for IERC20`** — métodos `safeTransferFrom`/`safeTransfer` que revierten si el token devuelve `false` (USDT-style).
- **`address immutable`** — set una sola vez en el constructor, no se puede cambiar. Ahorra gas en lecturas vs `address public` mutable.
- **Approve + transferFrom + approve al router**: triple "consentimiento" en cascada (user → contract → router) para que el token se pueda mover sin que nadie sea custodio.
- **`msg.sender` como destino del router**: el truco que hace que el token de salida vaya **directo a la wallet del user**, saltándose al SwappingApp.

### Fork testing (forge-std)

- **`--fork-url $RPC`**: levanta una copia local del estado de una red (Arbitrum, mainnet, etc.) en un timestamp dado.
- **Whale prank**: identificar una EOA con balance del token que necesitás (ver "Holders" en Arbiscan) y usar `vm.startPrank` para impersonarla.
- **Direcciones reales en los tests**: USDC, DAI y el router son contratos reales deployados en Arbitrum. El fork los carga tal cual.

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/09-swapping-app`).

### Build local

```bash
forge build
```

### Fork test (necesita RPC de Arbitrum)

Crear un archivo `.env` en este directorio:

```bash
ARBITRUM_RPC=https://arb-mainnet.g.alchemy.com/v2/<TU_API_KEY>
# o un public RPC sin auth:
# ARBITRUM_RPC=https://arb1.arbitrum.io/rpc
```

Después:

```bash
source .env
forge test --fork-url $ARBITRUM_RPC -vvv
```

### Flujo del test `testSwapTokens`

```
SETUP:
1. forge --fork-url levanta una copia del estado actual de Arbitrum.
2. Se deploya SwappingApp con la address del router de Uniswap V2.
3. Se identifica un user real con balance de USDC.

TEST:
4. vm.startPrank(user) → ahora todas las llamadas las hace el user.
5. user.approve(SwappingApp, 5 USDC) — autorización para que SwappingApp tome los USDC.
6. Se mide el balance de USDC y DAI del user ANTES.
7. SwappingApp.swapTokens(5 USDC, 4 DAI min, [USDC, DAI], deadline)
   → SwappingApp chupa 5 USDC del user
   → SwappingApp autoriza al router
   → Router swappea en el pool real de Arbitrum
   → DAI sale del pool y va DIRECTO al user
8. Se mide balance ANTES y DESPUÉS — verificamos que:
   - usdcBalanceAfter == usdcBalanceBefore - 5 USDC (gastó esos 5)
   - daiBalanceAfter >= daiBalanceBefore + 4 DAI (recibió al menos 4)
```

## Aprendizajes

- **DEX vs CEX**: a diferencia de Binance/Coinbase (con libro de órdenes y matching engine), Uniswap usa un pool con fórmula matemática. No hay contraparte humana — la liquidez la ponen los LPs y el precio sale del pool.
- **Composability es el superpoder de DeFi**: integrar con Uniswap es solo importar una interfaz y llamar una función. Tu contrato chiquito + Uniswap gigante = un sistema funcional en una sola tx atómica.
- **El token de salida no toca tu contrato**: pasando `msg.sender` como `to` del router, el output va directo del pool al user. Tu contrato queda "limpio" después del swap — no hay residuos para retirar.
- **`safeTransferFrom` para mover tokens del user**: la única forma de que tokens ERC-20 se muevan de la wallet del user al contrato es el patrón `approve` + `transferFrom` (no existe `msg.value` para tokens). El "safe" cubre tokens que devuelven `false` en lugar de revertir.
- **Doble allowance en cascada**: el user le aprueba al SwappingApp, y el SwappingApp le aprueba al router. Son dos pasos distintos — sin el segundo, el router no puede tomar los tokens del SwappingApp.
- **Slippage es real y matemático**: si el pool tiene 1M USDC y 1M DAI, swappear 5 USDC te da ~4.99 DAI. Swappear 100,000 USDC NO te da 100,000 DAI — te da bastante menos porque la curva se inclina al sacar mucha de una.
- **Fork testing es game-changer**: poder testear contra el estado real de mainnet/L2 sin gastar gas. Si tu test pasa contra el USDC y el router reales de Arbitrum, sabés que tu lógica funciona en producción.

## Posibles mejoras

### 🔒 Hardening

- **`deadline` dinámico en lugar de timestamp hardcodeado**: hoy el test usa `1780616130 + 1 hours` como deadline. Si la fork se hace desde un bloque cuyo timestamp es posterior, el test va a fallar. Más robusto: `block.timestamp + 1 hours`.
- ~~**`forceApprove` o `safeIncreaseAllowance` en vez de `approve`**~~ ✅ Aplicado en [`SwappingApp.sol:31`](src/SwappingApp.sol#L31): se usa `forceApprove` para cubrir tokens que como USDT exigen `approve(0)` antes de `approve(X)` si ya hay allowance.
- **`approve(router, 0)` al final del swap**: defensa contra allowance residual (no debería quedar nada con Uniswap, pero por hábito).
- **Validar `path_.length >= 2`**: el router ya lo valida, pero un revert temprano y con mensaje claro mejora UX.
- **Custom errors** en vez de relyar en los revert strings del router.

### 🧪 Testing

- **`vm.expectEmit`** para verificar que `TokensSwapped` se emite con los argumentos correctos.
- **Test con path multi-hop** (`USDC → WETH → DAI`) para validar que la lógica funciona con paths intermedios.
- **Test de revert por `amountOutMin` muy alto** (forzando "INSUFFICIENT_OUTPUT_AMOUNT" del router).
- **Test de revert por `deadline` pasado** (`vm.warp(deadline + 1)` y comprobar revert).
- **Pin del bloque con `--fork-block-number`** para que los tests sean reproducibles 100% (hoy dependen del estado "current" del fork).

### 🛠️ Features

- **Soporte para ETH directo**: si `path[0] == WETH`, aceptar `msg.value` y usar `swapExactETHForTokens` del router. Le ahorra al user un paso (no tiene que wrappear a WETH manualmente).
- **Función para swappear tokens → ETH**: usando `swapExactTokensForETH` (el inverso).
- **Soporte para Uniswap V3**: V3 tiene pools con fees concentradas, distinta interfaz pero mucho más eficiente en gas.
- **Script de deploy** (`script/DeploySwappingApp.s.sol`) para deployar el contrato a una testnet de Arbitrum.
