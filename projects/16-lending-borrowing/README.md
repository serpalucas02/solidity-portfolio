# 16 — Lending & Borrowing

> Protocolo de **préstamos con colateral** estilo Aave / Compound: los usuarios **depositan** un activo como garantía, **piden prestado** otro hasta un porcentaje de su colateral, **pagan** la deuda y, si su posición queda sub-colateralizada, pueden ser **liquidados**. Usa un **oráculo de precios Chainlink** para valuar colateral y deuda en USD. Construido con Foundry + OpenZeppelin.

## Descripción

Deposito un activo que vale (ej. WETH) y, contra esa garantía, puedo pedir prestado otro (ej. USDC) **por menos de lo que vale mi colateral** (sobre-colateralización). Un **oráculo** dice cuánto vale cada activo en todo momento; si el precio del colateral cae y mi deuda queda demasiado cerca de mi garantía, un **liquidador** repaga parte de mi deuda y se queda con colateral + una penalidad como premio. Así el protocolo nunca acumula deuda incobrable.

El corazón del protocolo es valuar **todo en una unidad común (USD)**: como el colateral y la deuda pueden ser tokens distintos con decimales distintos (WETH 18, USDC 6) y precios distintos, no se pueden comparar cantidades crudas. El oráculo + la normalización de decimales resuelven eso.

## Conceptos aplicados

- **Sobre-colateralización y `collateralFactor`**: cada market define qué fracción de su valor cuenta como garantía (ej. 80%). Se presta contra eso, no contra el 100%.
- **Ratio de colateralización**: `(valor del colateral ponderado × 10000) / valor de la deuda`, todo en USD. Si cae por debajo del `LIQUIDATION_THRESHOLD`, la posición es liquidable.
- **Oráculo Chainlink (`IAggregator.latestRoundData`)**: el contrato no adivina precios, los lee de un price feed. `getPrice` valida que el precio sea positivo.
- **Normalización de decimales**: `_getUsdValue` convierte `cantidad × precio` a un valor USD de 18 decimales, combinando los decimales del token (6/18) con los del feed (8). Su inversa `_getTokenAmountFromUsd` se usa en la liquidación para pasar de USD a cantidad del token de colateral.
- **Firma off-chain (`depositWithSignature`)**: depósito autorizado por una firma ECDSA (patrón EIP-191), para que un relayer pueda pagar el gas. Nonce + deadline contra replay.
- **`SafeERC20` + `ReentrancyGuard` + `Pausable` + `Ownable`**: transferencias seguras, blindaje de reentrancy, pausa de emergencia y administración — todos defaults del curso.

## Seguridad: dos bugs encontrados y corregidos

El proceso de testing (sobre todo el **fork con precios reales**) destapó dos vulnerabilidades que se arreglaron:

1. **`canBorrow` — primer préstamo sin colateral.** Un early-return (`if ratio == max return true`) hacía que el *primer* borrow de un usuario (sin deuda previa) **nunca se validara** contra el colateral → cualquiera podía drenar el pool. Fix: eliminar el atajo y simular siempre la deuda nueva. (El mismo patrón es correcto en `canWithdraw` y un bug en `canBorrow`: el contexto cambia si un atajo es válido o un agujero.)

2. **`liquidate` — colateral mal valuado.** `collateralToSeize = amount × 1.05` trataba 1 unidad de deuda = 1 unidad de colateral, **sin convertir por precio ni decimales**. El liquidador recibía una cantidad absurda (a veces una miga, a veces de más). Fix: convertir el valor de la deuda repagada a USD, sumar la penalidad, y volver a convertir a cantidad del token de colateral al precio actual.

## Contratos y tests

- [`src/LendingProtocol.sol`](src/LendingProtocol.sol) — el protocolo: markets, deposit / withdraw / borrow / repay / liquidate, `depositWithSignature`, oráculo (`setPriceFeed` / `getPrice`), health checks y getters.
- [`src/interfaces/IAggregator.sol`](src/interfaces/IAggregator.sol) — interfaz mínima de Chainlink (`latestRoundData`).
- [`test/LendingProtocol.t.sol`](test/LendingProtocol.t.sol) — **36 tests** con mocks (`MockToken` con decimales configurables + `MockAggregator` con precio controlable). Cubre todo, incluida la liquidación bajando el precio.
- [`test/LendingProtocol.fork.t.sol`](test/LendingProtocol.fork.t.sol) — **3 tests** contra **Arbitrum One** con tokens (WETH/USDC) y feeds de Chainlink **reales**.

**39 tests en total** · `LendingProtocol.sol` al **100% de líneas y funciones**, 99% statements, 85% branches (el resto son guardas defensivas inalcanzables — ver abajo).

### Por qué los mocks Y el fork

- **Fork (precios reales)**: valida la integración con Chainlink y la normalización de decimales con tokens de verdad. Pero no se puede **mover** el precio de ETH real.
- **Mocks (precio controlable)**: para testear la **liquidación** hay que poder bajar el precio del colateral y forzar que un usuario quede insano. Eso solo se hace con un `MockAggregator` que controlamos.

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/16-lending-borrowing`).

```bash
# Compilar
forge build

# Toda la suite (la de fork se auto-forkea contra Arbitrum)
forge test

# Solo la suite con mocks (rápida, sin red)
forge test --match-path test/LendingProtocol.t.sol

# El fork usa un RPC público por default; para uno propio:
ARBITRUM_RPC=<tu_rpc> forge test --match-path test/LendingProtocol.fork.t.sol

# Cobertura
forge coverage --match-path test/LendingProtocol.t.sol
```

## Aprendizajes

- **El test no está para confirmar que el código anda, sino para intentar romperlo.** El test "pedí 50k USDC contra 1 ETH" reveló el bug de `canBorrow` que un test optimista habría tapado.
- **Valuar en una unidad común es todo.** Sumar cantidades de tokens con decimales/precios distintos no tiene sentido; hay que pasar todo a USD con una escala fija (18) usando el oráculo.
- **Fork tests vs mocks no es uno u otro**: fork para integración real, mocks para los casos que requieren control (liquidaciones).
- **Coverage 100% ≠ correcto**: las branches que quedan sin cubrir son guardas defensivas inalcanzables (ver abajo), y saber *por qué* es mejor que inflar el número con tests artificiales.

## Posibles mejoras

- **Guardas defensivas redundantes**: los `require(token_ != address(0))` en funciones con el modifier `onlyActiveMarket` son inalcanzables (el modifier revierte antes con `address(0)`). Igual el `require(markets[token_].isActive)` dentro de `deposit`. Se podrían eliminar.
- **Interés**: el contrato guarda `supplyRate` / `borrowRate` pero no acumula interés sobre la deuda con el tiempo. Sería el siguiente paso para un lending realista.
- **`marketId` con `abi.encodePacked`**: en `addMarket` se podría hashear un `marketId` (como en el módulo 13) en vez de usar el address del token como key.
- **Liquidación parcial / close factor**: limitar qué fracción de la deuda se puede liquidar de una (Aave usa 50%).
- **`require` con strings**: migrar a custom errors (más baratos en gas).
