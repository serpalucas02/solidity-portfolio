# 13 — ABI Encoding & Decoding

> Colección de helpers de **codificación y hashing de parámetros** para estructuras típicas de DeFi: identificadores de pools, posiciones de trading/yield, swap data, órdenes (limit / stop-loss / take-profit / trailing), flash loans, configuraciones de staking y datos de bridge cross-chain. El foco del módulo es entender **`abi.encode` vs `abi.encodePacked`** y cómo se generan identificadores deterministas con `keccak256`. Construido con Foundry.

## Descripción

`ABIEncoder` es un contrato-laboratorio: cada función **serializa** un conjunto de parámetros con `abi.encodePacked`, le saca el `keccak256` para generar un identificador/hash, y emite un evento con el resultado. No mueve fondos ni tiene lógica de negocio — es una pieza **didáctica** para internalizar cómo Solidity empaqueta datos.

El hilo conductor es la diferencia entre las dos formas de codificar:

- **`abi.encode`** → cada argumento se **paddea a 32 bytes**. Largo pero **decodificable sin ambigüedad** (`abi.decode`) y **sin colisiones**.
- **`abi.encodePacked`** → concatena **sin padding**. Corto y barato de hashear, pero **NO decodificable** y **propenso a colisiones** cuando hay tipos dinámicos adyacentes.

El módulo usa `encodePacked` a propósito (para demostrarlo) y deja a la vista justamente los casos donde, en un contrato real, habría que usar `abi.encode`.

## Features implementadas

- ✅ **`abi.encodePacked` / ABIEncoder Demo** — encoding compacto + hashing con `keccak256`.
- ✅ **Pool identifiers** — `createPoolIdentifier`: ID determinista ordenando los tokens (`token0 < token1`), estilo Uniswap.
- ✅ **Trading positions** — `encodeTradingPosition`: empaqueta una posición y su `positionId`.
- ✅ **SwapData encoding** — `encodeSwapData`: empaqueta `path` + `amounts` + `deadline`.
- ✅ **Limit orders** — `encodeLimitOrder` + dominio (`"LIMIT_ORDER"`) para el hash.
- ✅ **Stop-loss / Take-profit / Trailing-stop orders** — `encodeStopLossOrder`, `encodeTakeProfitOrder`, `encodeTrailingStopOrder`.
- ✅ **Yield positions** — `encodeYieldFarmingPosition` + `encodeYieldStrategy` (multi-pool con pesos).
- ✅ **Funciones extra** — `encodeFlashLoan`, `encodeStakingPoolConfiguration`, `createUserMultiPoolHash`, `encodeCrossChainBridgeData`, `createDefiTransactionId`.
- ✅ **Hashing testing** — verificación de cada identificador reconstruyendo el encoding esperado.
- ✅ **Positions testing** — tests de trading / yield positions.
- ✅ **Extra testing** — reverts por length mismatch (swap, multi-pool, yield strategy).

**Estado final**: 18/18 tests pasando ✅

## Estructura del proyecto

```
13-abi-encoding/
├── foundry.toml                ← Solidity 0.8.24, EVM Cancun, via_ir + optimizer
├── remappings.txt              ← forge-std/
├── src/
│   └── ABIEncoder.sol          ← helpers de encoding/hashing
├── test/
│   └── ABIEncoder.t.sol        ← 18 tests (hashing + positions + reverts)
└── lib/
    └── forge-std/              ← cheatcodes y asserts
```

## Contratos y tests

- [`src/ABIEncoder.sol`](src/ABIEncoder.sol) — 15 funciones de encoding/hashing para estructuras DeFi.
- [`test/ABIEncoder.t.sol`](test/ABIEncoder.t.sol) — 18 tests que reconstruyen cada encoding esperado y lo comparan.

## Conceptos aplicados

### Encoding y hashing

- **`abi.encode` vs `abi.encodePacked`** — el corazón del módulo. `encode` paddea a 32 bytes (decodificable, sin colisiones); `encodePacked` concatena sin padding (compacto, para hashear, pero colisionable con dinámicos).
- **`keccak256(abi.encodePacked(...))`** — patrón para generar **identificadores deterministas**: mismos inputs → mismo ID. Se usa para pool IDs, order hashes, position IDs.
- **Ordenar inputs para canonicalizar** — en `createPoolIdentifier` se ordena `(token0, token1)` por valor de address, así `pool(A,B)` y `pool(B,A)` dan el **mismo** ID (igual que Uniswap).
- **"Dominio" en el hash** — agregar un literal como `"LIMIT_ORDER"` / `"YIELD_FARMING"` al final del encoding **separa namespaces**: evita que dos estructuras distintas con los mismos campos colisionen. (Versión casera de la idea detrás de EIP-712.)
- **Construir `bytes` en loop** — `data = abi.encodePacked(data, elemento)` para serializar arrays de tamaño variable.

### De Foundry / forge-std

- **`assertEq` con mensaje** — `assertEq(a, b, "mensaje")` imprime ambos valores y el motivo cuando falla. Mejor que `assert`.
- **Reconstruir el esperado en el test** — el test calcula el `abi.encodePacked` esperado por su cuenta y lo compara con el del contrato, en vez de hardcodear un hash mágico.
- **`vm.warp(timestamp)`** — congelar el tiempo para tests deterministas cuando el encoding depende de `block.timestamp`.
- **`vm.expectRevert(abi.encodeWithSignature("Error(string)", "..."))`** — verificar reverts de `require` con string.

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/13-abi-encoding`).

```bash
# Compilar
forge build

# Correr toda la suite
forge test

# Con traces detallados
forge test -vvv

# Un test específico
forge test --match-test testCreatePoolIdentifier

# Reporte de gas
forge test --gas-report
```

## Aprendizajes

- **`abi.encodePacked` con tipos dinámicos adyacentes = colisiones.** Es el aprendizaje central. Si concatenás dos cosas de longitud variable sin separador ni length-prefix (ej. `string` + `bytes`, o un `array` pegado a otro `array`), dos inputs distintos pueden producir **los mismos bytes** → el mismo hash. El ejemplo clásico: `encodePacked("a","bc") == encodePacked("ab","c")`. En este módulo `encodeYieldStrategy` (string + bytes) y `encodeSwapData` (path + amounts sin length prefix) son justo esos casos.
- **La regla práctica**: `encodePacked` solo para **un** tipo dinámico, o para tipos de **tamaño fijo**. Si hay varios dinámicos y vas a hashear, usá `abi.encode` (paddea y es inyectivo) o incluí length-prefixes. Para pasar datos que después se decodifican, **siempre** `abi.encode`.
- **`encode` es decodificable, `encodePacked` no.** `abi.decode` solo funciona sobre data generada con `abi.encode`. El packed es un camino de ida (sirve para hashear, no para recuperar).
- **Ordenar para canonicalizar.** Generar el mismo ID para `(A,B)` y `(B,A)` se logra ordenando los inputs antes de hashear — patrón directo de Uniswap.
- **El "dominio" separa estructuras.** Sumar un sufijo identificador (`"LIMIT_ORDER"`, etc.) evita que un limit order y, digamos, un stop-loss con los mismos números compartan hash. Es la semilla de lo que EIP-712 formaliza con domain separators.

## Posibles mejoras

### 🔒 Robustez / "siguiente nivel"

- **Usar `abi.encode` donde hay varios dinámicos**: `encodeYieldStrategy`, `encodeSwapData`, `encodeFlashLoan` y `createUserMultiPoolHash` deberían usar `abi.encode` (o length-prefixes) para ser **a prueba de colisiones**. Hoy, al ser didácticos, demuestran el packed — pero en producción serían explotables.
- **`block.timestamp` dentro del hash**: en `encodeStakingPoolConfiguration` y `encodeYieldStrategy` el ID depende de cuándo se llamó, así que **no es recomputable** off-chain. Si el ID tiene que ser determinista, recibir el timestamp como parámetro; si querés unicidad por-llamada, está OK pero conviene documentarlo.
- **Custom errors** en vez de `require` con strings: `error LengthMismatch();` es más barato en gas y permite `vm.expectRevert(ABIEncoder.LengthMismatch.selector)`.

### 🧹 Consistencia / estilo

- **Devolver `positionId_` en `encodeTradingPosition`**: hoy lo calcula y lo emite pero devuelve solo `encodedData_`; las demás funciones devuelven `(id, data)`. Unificar el patrón.
- **Funciones `pure` + eventos**: como cada función emite un evento, son `external` (cambian estado vía logs). Si el objetivo fuera solo encodear, versiones `pure` (sin evento) permitirían obtener el encoding **gratis** vía `eth_call` off-chain. Decisión de diseño según si querés el log on-chain o no.

### 🧪 Testing

- **Test de colisión**: un test que **demuestre** la colisión de `encodePacked` con dos inputs distintos que dan el mismo hash sería el broche de oro didáctico del módulo.
- **Decoding (`abi.decode`)**: el módulo se llama "encoding & decoding" pero el contrato solo encodea/hashea. Agregar una función que use `abi.encode` + `abi.decode` y un test de round-trip (`decode(encode(x)) == x`) cerraría el otro 50% del título.
- **Fuzz tests**: fuzzear los inputs de los identificadores para verificar que distintos inputs → distintos IDs (y descubrir colisiones del packed).
