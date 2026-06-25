# 21 — Uniswap V3 Interactions

> Integración con **Uniswap V3** (el AMM de **liquidez concentrada**): **swaps** (single y multi-hop), **gestión de posiciones de liquidez** (mint / increase / decrease / collect, como NFTs) y **flash loans**. Todo testeado con **fork de Ethereum mainnet** contra los contratos reales de Uniswap. Es la evolución de los proyectos [09](../09-swapping-app) y [10](../10-liquidity-pools) (que usaban Uniswap V2).

## Descripción

Uniswap V3 cambió el juego con la **liquidez concentrada**: en V2 la liquidez se reparte en **todo** el rango de precios (0 a ∞, mucho capital sin usar); en V3 cada LP elige un **rango específico** (`tickLower`/`tickUpper`) y su liquidez **solo gana fees cuando el precio está dentro del rango**. Más eficiente, pero con más gestión.

El proyecto abarca los tres tipos de interacción, un contrato wrapper por cada uno:
- **`UniswapV3Swap`** — swaps vía el `SwapRouter` (exact input / exact output, single y multi-hop).
- **`UniswapV3Liquidity`** — posiciones de liquidez vía el `NonfungiblePositionManager` (cada posición es un **NFT**).
- **`UniswapV3Flash`** — flash loans desde un pool (pedir → usar → repagar + fee, todo en una tx).

## Conceptos aplicados

- **Liquidez concentrada y ticks**: el precio se discretiza en **ticks** (`price = 1.0001^tick`); los rangos deben ser múltiplos del `tickSpacing` del pool (depende del fee tier: 0.05%→10, 0.3%→60, 1%→200).
- **`sqrtPriceX96`**: Uniswap V3 guarda el precio como **raíz cuadrada** en formato Q64.96 (fixed point), por eficiencia de cómputo on-chain.
- **Exact input vs exact output**: "vendo exactamente X" vs "compro exactamente Y" (con refund del sobrante). Slippage protection vía `amountOutMinimum` / `amountInMaximum`.
- **Multi-hop**: encadenar pools con un `path` empaquetado (`abi.encodePacked(tokenA, fee, tokenB, fee, tokenC)`) cuando no hay pool directo o conviene rutear.
- **Posiciones como NFTs**: cada posición se mintea como ERC-721 (pool + rango + liquidez); transferible y usable como colateral.
- **Flash loans**: `pool.flash(...)` → el pool te manda los tokens y llama tu `uniswapV3FlashCallback` → ahí hacés tu lógica (arbitraje, liquidación) → repagás `borrowed + fee` o **todo revierte**.

## Análisis de seguridad

Los tres contratos son **wrappers didácticos** bien hechos. Lo más importante a destacar:

- ✅ **`UniswapV3Flash` valida el callback correctamente** (lo crítico de un flash loan): recomputa la dirección del pool desde el `factory` (`getPool(token0, token1, fee)`) y exige `msg.sender == expectedPool`. Sin esto, **cualquiera** podría llamar tu callback y drenarte — acá está implementado correctamente.
- 🟡 **`UniswapV3Liquidity` usa `amount0Min = amount1Min = 0`** (sin slippage protection al proveer liquidez). Está documentado como simplificación, pero en producción es vector de MEV/sandwich.
- 🟡 **`SafeERC20`**: los contratos usan `transferFrom`/`approve` directos. Funciona con WETH/USDC/DAI, pero tokens no estándar (USDT) requerirían `SafeERC20`.
- 🟡 **Ownership del NFT**: `mintPosition` entrega el NFT a `msg.sender`; para que `decrease`/`collect` funcionen vía este contrato, el usuario tendría que aprobarle el NFT (o interactuar directo con el Position Manager). Es un detalle de diseño didáctico.

## Contratos y tests

- [`src/UniswapV3Swap.sol`](src/UniswapV3Swap.sol) · [`src/UniswapV3Liquidity.sol`](src/UniswapV3Liquidity.sol) · [`src/UniswapV3Flash.sol`](src/UniswapV3Flash.sol) · [`src/interfaces/INonfungiblePositionManager.sol`](src/interfaces/INonfungiblePositionManager.sol)
- [`test/fork/UniswapV3Test.t.sol`](test/fork/UniswapV3Test.t.sol) — **14 tests de fork** contra **Uniswap V3 real en mainnet**: swaps (exact in/out, multi-hop), ciclo de liquidez completo (mint → increase → decrease → collect, + collect de fees tras swaps reales), flash loans (un token, ambos tokens), un `fullLifecycle` end-to-end, y los reverts de los custom errors.

## Cómo probarlo

> Desde **adentro de este directorio** (`cd projects/21-uniswap-v3-interactions`).

```bash
forge build

# Los tests se auto-forkean de mainnet (RPC público por default)
forge test

# Con tu propio RPC (más rápido / sin rate limits):
MAINNET_RPC_URL=<tu_rpc> forge test
```

> Los tests usan **`deal()`** para fondear a Alice con WETH/USDC/DAI en el estado forkeado, y operan contra las **direcciones reales** de Uniswap (SwapRouter, NonfungiblePositionManager, Factory). Sin mocks: es integración de verdad.

## Aprendizajes

- **V2 → V3**: la liquidez concentrada es más eficiente pero te obliga a elegir un **rango** — y a gestionarlo cuando el precio se sale.
- **El precio en V3 vive como `sqrtPriceX96`** (raíz, fixed-point Q64.96): no es un `uint` "lindo", hay que convertir desde/hacia ticks.
- **El check del flash callback es no negociable**: validar que `msg.sender` es el pool real (vía factory) es lo que evita que te vacíen.
- **Fork testing > mocks** para integrar con un protocolo real: probás contra el comportamiento exacto de Uniswap, no contra una imitación.

## Posibles mejoras

- `SafeERC20` para soportar tokens no estándar.
- Slippage real (`amountXMin > 0`) en las funciones de liquidez.
- Aclarar el flujo de ownership del NFT (que el contrato custodie las posiciones, o documentar el approve).
