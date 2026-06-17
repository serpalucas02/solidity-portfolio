# 16 — Lending & Borrowing

> Protocolo de **préstamos con colateral** estilo Aave / Compound: los usuarios **depositan** un activo como garantía, **piden prestado** otro hasta un porcentaje de su colateral, **pagan** la deuda y, si su posición queda sub-colateralizada, pueden ser **liquidados**. Usa un **oráculo de precios** (Chainlink) para valuar el colateral. Construido con Foundry + OpenZeppelin.

## Descripción

_Por completar a medida que avance el proyecto._

La idea central de un protocolo de lending: yo deposito un activo que vale (ej. ETH) y, contra esa garantía, puedo pedir prestado otro (ej. una stablecoin) **pero menos de lo que vale mi colateral** (sobre-colateralización). Un **oráculo** dice cuánto vale el colateral en todo momento; si el precio cae y mi deuda queda demasiado cerca (o por encima) de mi garantía, un **liquidador** puede pagar mi deuda y quedarse con parte de mi colateral como premio. Así el protocolo nunca queda con deuda incobrable.

## Features del módulo

- [ ] **Mock tokens** — ERC-20 de prueba (activo colateral + activo a prestar).
- [ ] **Price oracle** — integración con Chainlink (`IAggregator.latestRoundData()`) para valuar el colateral.
- [ ] **Deposit / supply** — depositar colateral en el protocolo.
- [ ] **Borrow** — pedir prestado contra el colateral, respetando el ratio máximo (LTV).
- [ ] **Repay** — pagar la deuda (total o parcial).
- [ ] **Withdraw** — retirar colateral (si la posición sigue sana).
- [ ] **Health factor / ratio de colateralización** — el número que dice si una posición es segura o liquidable.
- [ ] **Liquidación** — un tercero paga la deuda de una posición insana y se lleva colateral con descuento.
- [ ] **Interés** (si aplica) — acumulación de interés sobre la deuda con el tiempo.
- [ ] **Testing** — happy paths, reverts, y escenarios de liquidación (bajando el precio del oráculo con un mock).

## Conceptos clave (preview)

- **Sobre-colateralización**: siempre se pide prestado **menos** de lo que vale el colateral. La diferencia es el colchón de seguridad del protocolo.
- **LTV (Loan-To-Value)**: el % máximo que podés pedir contra tu colateral (ej. 75% → con $100 de colateral pedís hasta $75).
- **Health Factor**: `(colateral × liquidation threshold) / deuda`. Si baja de 1, la posición es **liquidable**. Es el termómetro de toda posición.
- **Oráculo de precios (Chainlink)**: el protocolo no puede "adivinar" el precio del colateral — lo lee de un price feed externo vía `latestRoundData()`. En los tests se usa un **mock del aggregator** para simular subas/bajas de precio y disparar liquidaciones.
- **Liquidación**: cuando el health factor cae, un liquidador repaga (parte de) la deuda y recibe colateral + un **bonus**. Es lo que mantiene al protocolo solvente.
- **`SafeERC20` + `ReentrancyGuard`**: mover tokens de forma segura y blindar las funciones con interacciones externas (default del curso).

## Estructura del proyecto

```
16-lending-borrowing/
├── foundry.toml                ← Solidity 0.8.24, EVM Cancun, via_ir + optimizer
├── remappings.txt              ← forge-std/, @openzeppelin/contracts/
├── src/
│   ├── interfaces/
│   │   └── IAggregator.sol     ← interfaz de Chainlink price feed (latestRoundData), lista para usar
│   └── ...                     ← acá van los contratos del protocolo
├── test/                       ← tests Solidity (.t.sol)
├── script/                     ← (vacío por ahora)
└── lib/
    ├── forge-std/
    └── openzeppelin-contracts/ ← ERC20, IERC20, SafeERC20, Ownable
```

## Contratos y tests

- [`src/interfaces/IAggregator.sol`](src/interfaces/IAggregator.sol) — interfaz mínima de Chainlink (price feed), copiada del proyecto 11. Para los tests conviene un **mock** que implemente `latestRoundData()` y permita cambiar el precio a mano.
- _El resto se irá listando a medida que se cree._

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/16-lending-borrowing`).

```bash
# Compilar
forge build

# Correr toda la suite
forge test

# Con traces detallados
forge test -vvv

# Un test específico
forge test --match-test testLiquidation

# Reporte de cobertura
forge coverage
```

## Aprendizajes

- _Qué aprendí, qué me costó, qué haría distinto._

## Posibles mejoras

- _Ideas para extender el proyecto._
