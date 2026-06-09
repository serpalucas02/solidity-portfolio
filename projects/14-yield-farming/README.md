# 14 — Yield Farming

> Protocolo de **yield farming / staking con rewards**: los usuarios depositan (stake) un token y van acumulando recompensas en otro token, proporcionales a **cuánto** stakearon y por **cuánto tiempo**. Implementa el patrón clásico de `accRewardPerShare` (acumulador de rewards por token stakeado). Construido con Foundry + OpenZeppelin.

## Descripción

_Por completar a medida que avance el proyecto._

La idea central del yield farming es repartir un flujo de rewards entre todos los que stakean, **en proporción a su participación y al tiempo**. El truco para hacerlo eficiente (sin loopear sobre todos los usuarios) es el patrón **`accRewardPerShare`**: un acumulador global de "rewards por cada token stakeado" que se actualiza con el tiempo, y un `rewardDebt` por usuario que marca desde dónde empezó a contar. Así, `pending = staked * accRewardPerShare - rewardDebt`.

## Features del módulo

- [ ] **Yield Farming** — overview del sistema (stake → acumular rewards → claim → unstake).
- [ ] **Mock tokens** — ERC-20 de prueba (staking token + reward token) con mint público para tests.
- [ ] **Yield Farming Pool** — estructura de la pool (token stakeado, reward rate, acumulador, etc.).
- [ ] **Crear una pool** — función para crear/configurar una pool de farming.
- [ ] **Stake tokens** — depositar tokens en la pool (`transferFrom` + actualización de estado).
- [ ] **Unstake tokens** — retirar lo stakeado (con su CEI correspondiente).
- [ ] **Claim rewards** — reclamar las recompensas acumuladas.
- [ ] **Update pool** — recalcular el acumulador de rewards según el tiempo transcurrido.
- [ ] **Funciones externas** — helpers/getters (pending rewards, info de pool, etc.).
- [ ] **Cálculo de rewards por cada token staked** — el `accRewardPerShare`.
- [ ] **Cálculo de pending rewards** — `pending = staked * accRewardPerShare - rewardDebt`.
- [ ] **Testing Yield Farming** — stake / unstake / claim, avance de tiempo (`vm.warp`) y verificación de balances.

## Conceptos clave (preview)

- **`accRewardPerShare` (acumulador)**: en vez de recalcular las rewards de cada usuario en un loop (caro e inescalable), se mantiene **un solo número global** que representa "cuántas rewards acumuló cada token stakeado desde el inicio". Cuando un usuario interactúa, se calcula su parte con una resta. Es el mismo patrón de MasterChef (SushiSwap) y de muchos staking de OZ.
- **`rewardDebt`**: marca el punto del acumulador desde el cual el usuario "tiene derecho a cobrar". `pending = (staked * accRewardPerShare) - rewardDebt`. Cada vez que stakea/unstakea/claimea, se actualiza.
- **`updatePool()`**: antes de cualquier operación que cambie el staked total, hay que **actualizar el acumulador** con las rewards generadas desde la última vez (`tiempo transcurrido * rewardRate`). Si no, se reparte mal.
- **Precisión / `1e12`**: como Solidity no tiene decimales, el acumulador se escala por un factor (ej. `1e12`) para no perder rewards por redondeo, y se divide al final.
- **Dos tokens distintos**: lo que se **stakea** (staking token) y lo que se **cobra** (reward token) suelen ser ERC-20 distintos — separar mentalmente los dos flujos es clave (ya lo viste en el módulo 06).
- **`SafeERC20`**: usar `safeTransfer` / `safeTransferFrom` para mover los tokens (default del curso).

## Estructura del proyecto

```
14-yield-farming/
├── foundry.toml                ← Solidity 0.8.24, EVM Cancun, via_ir + optimizer
├── remappings.txt              ← forge-std/, @openzeppelin/contracts/
├── src/
│   ├── ABIEncoder.sol          ← base traída del módulo 13 (encoding/hashing de IDs)
│   └── ...                     ← acá van los contratos del yield farming
├── test/                       ← tests Solidity (.t.sol)
├── script/                     ← (vacío por ahora)
└── lib/
    ├── forge-std/              ← cheatcodes y asserts
    └── openzeppelin-contracts/ ← ERC20, IERC20, SafeERC20, Ownable
```

## Contratos y tests

_Se irán listando a medida que se creen._

- [`src/ABIEncoder.sol`](src/ABIEncoder.sol) — base traída del proyecto 13 (helpers de encoding/hashing para generar IDs de pools, posiciones, etc.).

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/14-yield-farming`).

```bash
# Compilar
forge build

# Correr toda la suite
forge test

# Con traces detallados
forge test -vvv

# Un test específico
forge test --match-test testStake

# Reporte de gas
forge test --gas-report
```

## Aprendizajes

- _Qué aprendí, qué me costó, qué haría distinto._

## Posibles mejoras

- _Ideas para extender el proyecto._
