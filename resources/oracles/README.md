# Oráculos — referencia de seguridad (Chainlink & Pyth)

> Material de **consulta** (no es un proyecto): cómo conectar un smart contract a un oráculo de precios y, sobre todo, **qué validar** para no comerse un exploit. Viene del workshop de oráculos del curso. Para usar cuando un proyecto necesite leer el precio de un activo on-chain.

Los contratos en [`src/`](src/) están en pares: la versión **básica** (sin checks, didáctica) y la versión **con checks** (las buenas prácticas).

| Archivo | Qué muestra |
|---|---|
| [`ChainlinkOracle.sol`](src/ChainlinkOracle.sol) | Lectura básica de un feed de Chainlink (sin validación). |
| [`ChainlinkOracleChecks.sol`](src/ChainlinkOracleChecks.sol) | Lectura **segura**: staleness, precio > 0, feed de respaldo. |
| [`PythOracle.sol`](src/PythOracle.sol) | Lectura básica de Pyth (sin validación). |
| [`PythOracleChecks.sol`](src/PythOracleChecks.sol) | Lectura **segura**: freshness, confidence interval, expo. |

> Son de referencia para leer — no compilan sueltos (les faltan las libs de Chainlink / Pyth). El valor está en los patrones de validación.

---

## Por qué los oráculos son un punto crítico de seguridad

El precio que devuelve el oráculo **decide plata**: cuánto podés pedir prestado, cuándo te liquidan, a qué precio swapeás. Si el contrato confía ciegamente en un precio **viejo, manipulado o roto**, un atacante puede drenar fondos. La regla: **nunca uses un precio sin validarlo.**

---

## Chainlink — modelo "push"

Chainlink **empuja** (push) el precio on-chain: una red de nodos actualiza el feed periódicamente, y vos solo lo **leés** con `latestRoundData()`. El precio ya está ahí, no pagás por actualizarlo.

### Qué validar (lo que hace `ChainlinkOracleChecks.sol`)

```solidity
(uint80 roundId, int256 answer, , uint256 updatedAt, ) = feed.latestRoundData();

require(answer > 0, "price <= 0");                                  // 1. precio válido
require(updatedAt > 0, "invalid timestamp");                       // 2. round completo
require(block.timestamp - updatedAt <= staleThreshold, "stale");   // 3. no viejo (staleness)
```

1. **`answer > 0`** — un precio 0 o negativo es un feed roto. Nunca lo uses.
2. **`updatedAt > 0`** — si es 0, el round no se completó (dato incompleto).
3. **Staleness (lo más importante)** — `block.timestamp - updatedAt <= umbral`. Cada feed tiene un *heartbeat* (cada cuánto se actualiza). Si el dato es más viejo que tu umbral, **revertí**: un precio viejo es tan peligroso como uno falso (ej. el activo se desplomó pero el feed no se actualizó).

### Otras buenas prácticas

- **Feed de respaldo (fallback)**: `ChainlinkOracleChecks` usa `try/catch` — si el feed primario falla, cae a uno secundario, y si los dos fallan, revierte. Evita que un feed caído frene todo el protocolo.
- **`decimals()`**: leé los decimales del feed (Chainlink USD = 8) para normalizar, no los hardcodees a ciegas.
- **⚠️ NO uses `latestAnswer()`**: está **deprecada** y no trae el timestamp, así que no podés chequear staleness. Usá siempre **`latestRoundData()`**.

---

## Pyth — modelo "pull"

Pyth funciona al revés: vos **traés** (pull) el precio. El precio vive off-chain (más fresco, sub-segundo) y **vos lo subís on-chain** justo antes de usarlo, pagando una fee. Por eso el flujo tiene un paso extra: **actualizar y después leer**.

### El flujo seguro (lo que hace `PythOracleChecks.sol`)

```solidity
function getLatestPrice(bytes[] calldata updateData) public payable returns (...) {
    updatePrice(updateData);                                       // 1. actualizá el precio (pagás fee)
    PythStructs.Price memory p =
        pyth.getPriceNoOlderThan(priceId, MAX_AGE_SECONDS);        // 2. leé con tope de antigüedad
    _validatePrice(p.price, p.conf, p.expo);                       // 3. validá
    ...
}
```

1. **Actualizar primero**: `updatePriceFeeds{value: fee}(updateData)` con el `updateData` que traés de la API de Pyth off-chain. Hay que **pagar la fee** (`getUpdateFee`).
2. **`getPriceNoOlderThan` (NO `getPriceUnsafe`)**: el método seguro revierte solo si el precio es más viejo que `MAX_AGE_SECONDS`. `getPriceUnsafe` no chequea nada → solo para casos donde validás vos.

### Qué validar (en `_validatePrice`)

```solidity
require(price > 0, "invalid price");                  // 1. precio válido
require(expo >= MIN_ACCEPTABLE_EXPO, "invalid expo"); // 2. exponente razonable (>= -18)
require(                                               // 3. confidence interval
    confidence > 0 && (abs(price) * 1e4) / confidence > MIN_CONFIDENCE_RATIO,
    "untrusted price"
);
```

1. **`price > 0`** — igual que Chainlink.
2. **`expo`** — Pyth da el precio como `price × 10^expo`. Validá que el exponente esté en un rango sano (no más chico que -18) para no comerte una escala rara.
3. **Confidence interval (lo distintivo de Pyth)** — Pyth devuelve un `conf` (intervalo de confianza): qué tan seguro está del precio. Si el intervalo es **muy ancho** respecto al precio (o 0 = feed pausado), el precio es **poco confiable** → revertí. Es el chequeo que Chainlink no tiene.

---

## Push (Chainlink) vs Pull (Pyth) — la diferencia que hay que saber

| | **Chainlink (push)** | **Pyth (pull)** |
|---|---|---|
| Quién actualiza | La red de nodos, periódicamente | **Vos**, justo antes de leer |
| Costo de leer | Gratis (solo gas de la lectura) | Pagás una **fee** de actualización |
| Frescura | Hasta el último heartbeat | Sub-segundo (lo traés al momento) |
| Chequeo estrella | **Staleness** (`updatedAt`) | **Confidence interval** (`conf`) |
| Método correcto | `latestRoundData()` (no `latestAnswer`) | `getPriceNoOlderThan` (no `getPriceUnsafe`) |

---

## Checklist rápido (para pegar en cualquier integración)

**Chainlink:**
- [ ] `latestRoundData()`, nunca `latestAnswer()`
- [ ] `answer > 0`
- [ ] `updatedAt > 0`
- [ ] `block.timestamp - updatedAt <= staleThreshold`
- [ ] normalizar con `decimals()` (USD = 8)
- [ ] (ideal) feed de respaldo con `try/catch`

**Pyth:**
- [ ] actualizar (`updatePriceFeeds`) y pagar la `getUpdateFee`
- [ ] leer con `getPriceNoOlderThan`, no `getPriceUnsafe`
- [ ] `price > 0`
- [ ] `expo` en rango razonable
- [ ] chequear el `confidence` interval (no muy ancho, no 0)

---

## Links

- [Chainlink Price Feeds](https://docs.chain.link/data-feeds) · [directorio de feeds por red](https://docs.chain.link/data-feeds/price-feeds/addresses)
- [Pyth Network Docs](https://docs.pyth.network/) · [price feed IDs](https://pyth.network/developers/price-feed-ids)
