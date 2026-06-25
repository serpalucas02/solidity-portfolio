# 18 — Lottery (Chainlink VRF)

> **Lotería 100% random y verificable**: los usuarios compran tickets durante una ventana de tiempo, y al cerrar la ronda se eligen hasta **3 ganadores** con números aleatorios de **Chainlink VRF 2.5** (random con prueba criptográfica). Reparto 50/30/20, comisión del protocolo, y rondas que se reinician. Construido con Foundry + Chainlink VRF.

## Descripción

El desafío central de una lotería on-chain: **no se puede generar aleatoriedad de forma segura en la EVM**. Todo es determinista (`block.timestamp`, `blockhash`, `prevrandao` son predecibles o manipulables por validators) — fatal cuando hay plata en juego. La solución es **Chainlink VRF**: el contrato pide un número random off-chain y Chainlink lo entrega **junto con una prueba** que el contrato verifica. Random imparcial y auditable.

Cada ronda: el owner la abre → los jugadores compran tickets (más tickets = más chances) → vencido el plazo, cualquiera dispara el sorteo → Chainlink responde → se eligen 3 ganadores únicos y se les **asigna** el premio (lo cobran ellos).

## Conceptos aplicados

- **Chainlink VRF 2.5 + modelo asíncrono de 2 pasos**: `requestRandomWords()` devuelve un `requestId` (la respuesta NO llega en esa tx) y luego Chainlink llama de vuelta a `fulfillRandomWords()` — el callback donde se eligen los ganadores. Subscription model (la sub paga las requests).
- **Selección ponderada por tickets**: cada ticket es una entrada en el array `players`; el random indexa ahí, así que más tickets = más probabilidad. Re-hashing con nonce para evitar ganadores duplicados.
- **Máquina de estados** de la ronda: `OPEN → CALCULATING → CLOSED` (o refund si no hubo jugadores suficientes).
- **CEI** estricto y **custom errors** en cada validación.

## Seguridad: la vulnerabilidad encontrada y corregida

Auditando el contrato apareció el bug clásico de toda lotería con VRF:

🔴 **Push payments en el callback (DoS / lotería trabada).** La versión original **transfería** los premios dentro de `fulfillRandomWords`. Como ese callback lo llama Chainlink, si **un ganador es un contrato que rechaza ETH** (a propósito o no), el `.call` falla → **el callback entero revierte** → la ronda queda en `CALCULATING` **para siempre**, con los fondos atrapados y los demás ganadores sin cobrar. Un atacante traba la lotería comprando un ticket desde un contrato que rechaza ETH.

✅ **Fix — pull payment pattern.** Ahora `fulfillRandomWords` **solo asigna** los premios a un ledger (`s_prizes`); cada ganador los retira con **`claimPrize()`**. El callback quedó **a prueba de revert**: nadie puede trabarlo. Además, **`ReentrancyGuard`** en todas las funciones que mueven ETH.

> El test [`testMaliciousWinnerCannotBrickLottery`](test/Lottery.t.sol) **demuestra el ataque**: un contrato que rechaza ETH gana el primer premio, el callback **completa igual** (ronda `CLOSED`), los ganadores honestos cobran, y el atacante simplemente no puede reclamar **su** premio — sin afectar a nadie.

## Contratos y tests

- [`src/Lottery.sol`](src/Lottery.sol) — la lotería completa: rondas, compra de tickets, sorteo (request VRF), callback con selección de ganadores (pull payment), refunds, comisiones y admin.
- [`test/Lottery.t.sol`](test/Lottery.t.sol) — **29 tests** con el **`VRFCoordinatorV2_5Mock`** de Chainlink (sin fork): simula la respuesta del oráculo con `fulfillRandomWordsWithOverride` y un helper que **fuerza qué jugador gana** (calcula el seed que cae en cada índice). Cubre el ciclo completo + reverts + el test del ataque.

**Cobertura**: `Lottery.sol` al **100% de líneas y funciones**, 97% statements, 86% branches (el resto son guardas de borde — el `maxAttempts` del selector, el `TransferFailed` del refund de excedente — alcanzables solo con escenarios artificiales).

## Cómo probarlo

> Desde **adentro de este directorio** (`cd projects/18-lottery-vrf`).

```bash
forge build
forge test
forge test --match-test testMaliciousWinnerCannotBrickLottery -vvv  # el test de seguridad
forge coverage
```

> No hace falta fork: el **mock del VRF Coordinator** permite simular en local la respuesta del oráculo (incluso elegir las palabras random) y testear todo el ciclo request → fulfill → ganadores.

## Aprendizajes

- **El random on-chain no existe**: hay que delegarlo a un oráculo verificable (VRF). Cualquier fuente "casera" es predecible o manipulable.
- **El callback de VRF nunca debe poder revertir por una causa externa**: si paga con push y un ganador rechaza ETH, la lotería se traba. **Pull payments** lo resuelven — el mismo patrón que hace seguro a cualquier sistema de pagos a terceros.
- **El flujo asíncrono (request → fulfill)** obliga a pensar en estados: la ronda "espera" la respuesta en `CALCULATING`.

## Posibles mejoras

- **Keeper / Automation** para disparar `requestDraw` automáticamente al vencer la ronda (hoy es manual/permissionless).
- **`callbackGasLimit` dinámico** según la cantidad de jugadores (la selección con re-hash consume gas variable).
- Pasar el `_selectUniqueWinners` a un algoritmo sin re-hashing (ej. Fisher-Yates parcial) para gas más predecible.
- `require` con strings heredados de Chainlink (`ConfirmedOwner`) vs custom errors propios.
