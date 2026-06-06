# 11 — Presale (Token Sale con Chainlink)

> Contrato de **preventa de tokens** con fases (precios distintos en cada etapa), pago en **stablecoins** y/o **ETH**, integración con **Chainlink Price Feeds** para obtener el precio de ETH en USD, blacklisting, emergency withdraw y claim de tokens al final.

## Descripción

_Por completar a medida que avance el proyecto._

## Features del módulo

- [ ] **Preventa de tokens** — overview y arquitectura.
- [ ] **Fases de la preventa** — múltiples rondas con precios y caps distintos.
- [ ] **Blacklisting** — el owner puede bloquear addresses sospechosas.
- [ ] **NatSpec comments** — documentación inline estándar (`@notice`, `@param`, `@return`).
- [ ] **Emergency withdraw** — escape hatch para que el owner saque fondos en una emergencia.
- [ ] **Periodos** — manejo de tiempos de inicio/fin con `block.timestamp`.
- [ ] **Matemáticas DeFi** — manejo de decimales, conversiones, precisión.
- [ ] **Comprar con Stablecoins** — flujo de compra pagando USDC/DAI.
- [ ] **Manejo de fases** — transición entre fases, validaciones de cap por fase.
- [ ] **Price Feeds: integrar Chainlink como oracle** — obtener precio de ETH/USD on-chain para calcular cuántos tokens corresponden a una compra en ETH.
- [ ] **Claim tokens** — los compradores reclaman sus tokens al final de la preventa.
- [ ] **Testing Setup** — fixtures, mocks de Chainlink, mocks de stablecoins, fork si aplica.

## Conceptos clave (preview)

- **Presale (preventa)**: venta de tokens a inversores antes de que estén disponibles públicamente. Típicamente con **descuento progresivo** (cuanto antes comprás, mejor precio) y **caps** por fase.
- **Multi-fase**: una sola preventa con varias rondas (Seed, Private, Public, etc.), cada una con su precio y su tope. El contrato avanza de fase cuando se cumple cap o tiempo.
- **Pago multi-asset**: aceptar **ETH** y **stablecoins** (USDC, DAI) requiere normalizar todo a un valor común (típicamente USD). Para ETH se necesita un **oracle** que diga "1 ETH = ? USD".
- **Chainlink Price Feeds**: el oracle estándar de la industria. Tu contrato llama a un contrato de Chainlink (deployado en cada red) y obtiene el precio del último bloque. **Nunca confiar en el precio de un DEX** para esto — son manipulables con flash loans.
- **Claim pattern (pull over push)**: durante la presale los buyers no reciben los tokens inmediatamente — se guarda cuánto les corresponde. Cuando termina la presale (o cuando el owner habilita), cada uno llama `claim()` y los retira. Evita que un revert en una transferencia frene toda la presale.
- **Blacklisting**: mapping de addresses bloqueadas; el `buy()` revierte si el sender está en la lista. Sirve para compliance / KYC fallido.
- **Emergency withdraw**: función `onlyOwner` para vaciar el contrato en caso de bug o ataque. Trade-off: simplifica la operación, pero centraliza el riesgo.

## Estructura del proyecto

```
11-presale/
├── foundry.toml         ← Solidity 0.8.24 + Cancun + via_ir + optimizer
├── remappings.txt       ← @openzeppelin/, forge-std/
├── src/                 ← contratos (Presale + Token + mocks de Chainlink)
├── test/                ← unit tests + posiblemente fork
├── script/              ← scripts de deploy
└── lib/
    ├── forge-std/                ← cheatcodes y asserts
    └── openzeppelin-contracts/   ← ERC20, Ownable, SafeERC20
```

> 💡 **Chainlink**: cuando llegues a la lección de Price Feeds vas a tener que instalar `smartcontractkit/chainlink-brownie-contracts` (donde están las interfaces). Te lo aviso ahí cuando lo necesites.

## Contratos

_Se irán listando a medida que se creen._

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/11-presale`).

```bash
# Compilar
forge build

# Correr tests
forge test

# Con traces detallados
forge test -vvv

# Reporte de gas
forge test --gas-report

# Cuando haya tests con fork (para Chainlink real):
forge test --fork-url $RPC_URL -vvv
```

## Aprendizajes

- _Qué aprendí, qué me costó, qué haría distinto._

## Posibles mejoras

- _Ideas para extender el proyecto._
