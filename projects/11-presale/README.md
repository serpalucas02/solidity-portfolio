# 11 — Presale (Token Sale con Chainlink)

> Contrato de **preventa de tokens** con fases (precios distintos en cada etapa), pago en **stablecoins** (USDC, DAI) o **ETH**, integración con **Chainlink Price Feeds** para obtener el precio de ETH en USD, blacklisting, emergency withdraw y claim de tokens al final. Testeado con **fork de Arbitrum** contra USDC, DAI y el aggregator ETH/USD reales.

## Descripción

`Presale` es un contrato que vende un token (saleToken) a inversores en una **secuencia de fases** con precios distintos. Los buyers pagan en **USDC**, **DAI** o **ETH** y reciben el **derecho** (no los tokens directamente) a reclamar saleTokens después de que termine la presale.

### Diseño clave

- **Multi-fase con state machine**: la fase avanza automáticamente cuando se alcanza el **cap de tokens vendidos** O cuando pasa el **deadline** de esa fase. Cada fase tiene su propio precio.
- **Multi-asset payments**: USDC (6 decimales), DAI (18 decimales) y ETH. El contrato normaliza todo a USD (18 decimales) internamente para calcular tokens.
- **Chainlink Price Feed**: para conocer el precio de ETH en USD, el contrato consulta el aggregator ETH/USD real de Chainlink en Arbitrum.
- **Claim pattern (pull over push)**: durante la presale los compradores **no reciben tokens inmediatamente** — el contrato registra cuántos les corresponden en `userBalance`. Después de `endingTime`, cada uno llama `claimTokens()` y los retira.
- **Blacklisting**: el owner puede bloquear addresses que detecte como sospechosas.
- **Emergency withdraw**: dos funciones `onlyOwner` para sacar tokens y ETH del contrato en caso de bug/ataque/migración.
- **Pago de stablecoins va directo a `fundsWallet`**: el contrato **no acumula** USDC/DAI/ETH durante el flujo normal — los pagos se forwardean directo a una wallet de tesorería. Eso reduce la superficie de ataque.

### Pipeline de compra (USDC):

```
1. user → approve(presale, X USDC)
2. user → presale.buyWithStableCoin(USDC, X)
   ├─ Valida: !blacklisted, started, !ended, token válido
   ├─ Calcula tokenAmountToReceive según decimales y precio de la fase
   ├─ checkCurrentPhase() puede avanzar de fase
   ├─ totalSold += tokenAmountToReceive
   ├─ Valida: totalSold <= totalSupply
   ├─ userBalance[user] += tokenAmountToReceive   ← boleta on-chain
   └─ safeTransferFrom(user, fundsWallet, X)      ← pago va a tesorería
3. (presale termina con vm.warp / paso del tiempo)
4. user → presale.claimTokens()
   └─ safeTransfer(saleToken, user, userBalance[user])
```

## Features implementadas

- ✅ **Preventa de tokens** — diseño multi-fase con caps de tokens y deadlines de tiempo.
- ✅ **Fases de la preventa** — `uint256[][3] phases` con `[cap, price, deadline]` por fase.
- ✅ **Blacklisting** — `blacklistAddress` y `removeAddressFromBlacklist` (`onlyOwner`).
- ✅ **Emergency withdraw** — `emergencyERC20Withdraw` + `emergencyETHWithdraw`.
- ✅ **Periodos** — `startingTime` / `endingTime` + `phases[currentPhase][2]` (deadline por fase).
- ✅ **Matemáticas DeFi** — normalización por decimales en `buyWithStableCoin` (USDC 6 dec vs DAI 18 dec).
- ✅ **Comprar con Stablecoins** — `buyWithStableCoin(token, amount)` con whitelist de tokens válidos.
- ✅ **Manejo de fases** — `checkCurrentPhase` privada, validada vía el side-effect en `currentPhase()`.
- ✅ **Price Feeds: integrar Chainlink como oracle** — `getEtherPrice()` consume `latestRoundData()` del Chainlink ETH/USD real en Arbitrum.
- ✅ **Claim tokens** — `claimTokens()` con `require(block.timestamp >= endingTime)`.
- ✅ **Testing Setup** — fixtures con mock del saleToken, fork de Arbitrum, whale para USDC/DAI.

**Estado final**: **24/24 tests pasando** ✅ con fork de Arbitrum. Coverage: **100% líneas, 100% statements, 100% funciones, 93.33% branches**.

> Los 2 branches no cubiertos son los paths "tiempo" + "max phase" del `checkCurrentPhase`, y los `require(success, "Transfer failed.")` de `.call{value:}` (necesitan setup con contratos rejecter para forzar el fallo). No se persigue esa cobertura porque agrega ruido sin ganancia funcional real — el 100% en líneas/funciones ya valida toda la lógica.

## Estructura del proyecto

```
11-presale/
├── foundry.toml                       ← Solidity 0.8.24 + Cancun + via_ir + optimizer
├── remappings.txt                     ← @openzeppelin/contracts/, forge-std/
├── src/
│   ├── Presale.sol                    ← contrato principal
│   └── interfaces/
│       └── IAggregator.sol            ← interfaz mínima de Chainlink (latestRoundData)
├── test/
│   └── Presale.t.sol                  ← 24 tests con fork de Arbitrum
└── lib/
    ├── forge-std/                     ← cheatcodes y asserts
    └── openzeppelin-contracts/        ← Ownable, ERC20, IERC20, SafeERC20
```

## Contratos

- [`src/Presale.sol`](src/Presale.sol) — contrato de preventa con multi-fase, multi-asset, Chainlink price feed, claim pattern, blacklist y emergency withdraws.
- [`src/interfaces/IAggregator.sol`](src/interfaces/IAggregator.sol) — interfaz mínima de Chainlink (solo `latestRoundData`).
- [`test/Presale.t.sol`](test/Presale.t.sol) — 24 tests cubriendo todos los flujos.

## Conceptos aplicados

### State machines y manejo de fases

- **State machine implícita**: `currentPhase` es la variable que define el estado actual. Cada fase tiene `[cap, price, deadline]`.
- **Transición automática**: `checkCurrentPhase` chequea si el cap o el deadline se alcanzaron y avanza el estado si corresponde.
- **Composición de condiciones**: la condición de avance es `(cap_reached || time_passed) && phase < max_phase`. El `phase < max_phase` evita overflow del estado.

### Oráculos (Chainlink)

- **`AggregatorV3Interface`**: el estándar de Chainlink para price feeds. Solo necesitás `latestRoundData()` para el caso típico.
- **Decimales del oracle**: Chainlink devuelve precios con **8 decimales**. Si querés trabajar en 18 decimales, multiplicás por `10**10`.
- **Hardcoded vs dynamic decimals**: este contrato asume 8 decimales (multiplica por `10**10` directo). Una versión más robusta consultaría `aggregator.decimals()` y haría el ajuste dinámico — esto evita el problema con feeds "raros" (como los SVR).
- **Address del aggregator en Arbitrum**: `0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612` (ETH/USD).

### Matemáticas DeFi con decimales

- **El bug clásico de unidades**: si `totalSupply_` no está escalado igual que `phases[0][0]` (cap), las comparaciones rompen. Lección aprendida: **siempre que veas un valor en una matemática DeFi, preguntate "qué decimales tiene"**.
- **Normalización a 18 decimales**: cuando aceptás múltiples stablecoins (USDC con 6, DAI con 18), normalizar todo a la "moneda interna" simplifica la matemática.
- **Cálculo en `buyWithStableCoin`**:
  ```solidity
  // DAI (18 decimales):
  tokenAmountToReceive = (amount * 1e6) / phases[currentPhase][1];
  
  // USDC (6 decimales) — escala a 18 antes:
  tokenAmountToReceive = (amount * 10**(18 - decimals) * 1e6) / phases[currentPhase][1];
  ```

### Claim pattern (pull over push)

- **Por qué no transferir tokens en el momento del buy**: si un comprador es un contrato sin `receive()` o con bug en `onERC20Received`, la transferencia revierte y **toda la presale se traba**. Con el claim pattern, el riesgo está aislado en cada user — si uno no puede claim, los otros sí pueden.
- **`userBalance[user]`** es la "boleta on-chain" que registra el derecho. Es state crítico que merece test dedicado.

### Foundry / Testing

- **`vm.computeCreateAddress` + `vm.getNonce`**: para resolver el chicken-and-egg de aprobar tokens al Presale ANTES de deployarlo. Predecís la futura address del contrato y aprobás ahí.
- **`deal(token, addr, amount)`** vs **`vm.deal(addr, amount)`**: el primero mintea ERC-20 (StdCheats), el segundo setea balance de ETH. Confusión común.
- **Fork testing** contra Arbitrum: usar USDC, DAI y Chainlink ETH/USD **reales** valida la integración como si estuvieras en producción.
- **`receive() external payable {}`**: el test contract necesita esta función para poder recibir ETH del `emergencyETHWithdraw` (porque actúa como owner).
- **`vm.expectRevert` con specifier**: `abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user)` para verificar el revert específico de OZ Ownable v5. Mucho más preciso que `vm.expectRevert()` pelado.

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/11-presale`).

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

### Coverage

```bash
forge coverage --fork-url $ARBITRUM_RPC --report summary
```

## Aprendizajes

- **State machines en Solidity son simples pero merecen tests dedicados**: no alcanza con probar happy paths — hay que probar las transiciones (avance por cap, avance por tiempo, no-avance en fase máxima). Es el patrón que aparece en presales, vesting, airdrops, lotteries y un montón de otros lugares.
- **El cheatcode `vm.computeCreateAddress(deployer, nonce)`**: cambia totalmente cómo se testean contratos cuyo constructor hace `transferFrom`. Antes te obligaba a refactorizar el contrato para separar deploy de init; ahora podés mantener el constructor "natural" y predecir la address en el test.
- **`deal()` (sin `vm.`) vs `vm.deal()`**: la confusión más común con cheatcodes. Una mintea ERC-20, la otra setea balance de ETH. Anotalo y dejalo a mano.
- **Chainlink: cuidado con qué feed elegís**: el ETH/USD estándar tiene 8 decimales. Los SVR feeds o feeds "experimentales" pueden tener escalas distintas. **Si tu math asume 8 decimales y el feed devuelve 18, todo tu sistema se rompe en silencio** y solo lo descubrís por revertís con números astronómicos.
- **Decimales son el #1 source de bugs en DeFi**: USDC (6) vs DAI/saleToken (18) vs Chainlink (8) vs precios en la fase (5000? unidad?). Cada vez que escribís una fórmula, anotá qué decimales tiene cada lado de la ecuación.
- **El claim pattern aísla fallas**: cuando hay un contrato externo en el medio (token, oracle, lo que sea), separar "registro de derecho" de "transferencia física" hace que los bugs/ataques afecten a una sola wallet, no a toda la presale.
- **`receive()` y `fallback()` son obligatorias para contratos que reciben ETH**: las EOAs aceptan ETH sin nada; los contratos NO. Es la causa #1 del error "Transfer failed." en tests.
- **`vm.expectRevert(abi.encodeWithSelector(...))`**: matchea el revert exacto. Sin esto, un test "pasa" cuando otro revert (no relacionado al que querías validar) se dispara — falsa cobertura.
- **Coverage no es todo**: priorizar 100% líneas/funciones > 90% branches con casos artificiales. Los branches restantes (success false del `.call`, casos edge del state machine) requieren mocks de "rejecter" que agregan complejidad sin ganancia funcional real para un proyecto didáctico.

## Posibles mejoras

### 🔒 Hardening de seguridad

- **`USDC`/`DAI` como `immutable`**: ya que se setean en el constructor y no cambian, podrían ser `immutable` para ahorrar SLOAD por lectura (igual que `V2Router02Address` lo era en el proyecto 09).
- **Validaciones del constructor**: verificar `address(0)` en `saleTokenAddress_`, `daiAddress_`, `usdcAddress_`, `fundsWallet_`, `dataFeedAddress_`. Hoy no hay protección.
- **Stale price check en `getEtherPrice()`**: verificar que `updatedAt` esté en un rango razonable. Si el feed está roto/desactualizado, el cálculo se basa en datos viejos. Patrón típico:
  ```solidity
  (, int256 price, , uint256 updatedAt, ) = aggregator.latestRoundData();
  require(price > 0, "Stale or invalid price");
  require(updatedAt > block.timestamp - 1 hours, "Price too old");
  ```
- **`Ownable2Step`** en vez de `Ownable`: ownership transfers en dos pasos protegen contra transferir a una address equivocada.
- **Custom errors** en lugar de `require` con strings: más baratos en gas y más tipados para los tests.
- **Reentrancy guard en `claimTokens` y `emergencyERC20Withdraw`**: ambos hacen transferencia externa. Si bien usan `safeTransfer` (no `transferFrom`), un `nonReentrant` es defensa adicional.
- **Decimales dinámicos en `getEtherPrice`**: leer `aggregator.decimals()` y normalizar dinámicamente. Hoy hardcodea 8 → falla con feeds que devuelvan otra escala.
- **Emergency withdraw con timelock o multisig**: hoy el owner puede drenar el contrato en cualquier momento. En producción real, gatearlo con un timelock (anuncia retiro con 48hs de aviso) o multisig (N de M firmas).

### 🐞 Detalles del contrato

- **`require` con strings vs custom errors**: ya mencionado, pero también afecta el linter de Foundry — varios warnings de `block-timestamp` aparecen en build. No son bugs, son advertencias informativas.
- **`phases` como struct en vez de `uint256[][3]`**: hoy las fases son `[cap, price, deadline]` como array. Un struct `Phase { uint256 cap; uint256 price; uint256 deadline; }` es más legible (acceso por nombre vs índice numérico).
- **Eventos faltantes**: `blacklistAddress`, `removeAddressFromBlacklist`, `emergencyERC20Withdraw` y `emergencyETHWithdraw` no emiten eventos. Off-chain indexers (frontends, The Graph) no se enteran cuando cambian estos estados críticos.
- **NatSpec comments**: el módulo del curso lo lista como feature pero el contrato no tiene documentación NatSpec (`@notice`, `@param`, `@return`). Agregarla mejora la legibilidad y permite herramientas como Solidoc generar docs.

### 🧪 Testing

- **`vm.expectEmit`** para verificar que `TokensSold` se emite con los argumentos correctos en `buyWithStableCoin` y `buyWithEther`.
- **Test de avance por tiempo en `checkCurrentPhase`**: explícito (con `vm.warp` al deadline). Cubriría 1 de los 2 branches faltantes.
- **Test de phase máxima en `checkCurrentPhase`**: que el currentPhase no avance más allá de 3 incluso cuando se llega al final. Cubriría el otro branch.
- **Test de transferencia ETH fallida**: con un contrato "rejecter" como owner / fundsWallet, forzar que `.call{value:}` devuelva `false` y verificar que el `require(success, ...)` revierte. Cubriría los branches de success en buyWithEther y emergencyETHWithdraw.
- **Mock de Chainlink Aggregator**: para tests determinísticos (no depender del precio real de ETH en el bloque del fork). Tests más rápidos y reproducibles.
- **Test de "boleta on-chain"**: verificar que `userBalance[user]` se incrementa en el monto esperado tras un buy. (Ya está parcialmente en los happy paths pero podría tener un test dedicado.)
- **Fuzz tests**: variar `amount`, `price`, `currentPhase` para descubrir edge cases en la matemática de decimales.

### 🛠️ Features

- **`refund()`**: si la presale no alcanza un cap mínimo (soft cap), permitir a buyers retirar lo que invirtieron. Patrón común en presales reales.
- **`updatePhase()` por owner**: hoy las fases son inmutables. Permitir al owner ajustar caps/precios/deadlines (gateado por timelock) da flexibilidad.
- **Vesting linear post-presale**: en lugar de claim total al final, distribuir los tokens gradualmente (ej. 25% al final, 25% cada mes durante 3 meses). Más alineado con economía real de tokens.
- **Soporte para más stablecoins**: hoy hardcodea USDC + DAI. Generalizar a un `mapping(address => bool) public acceptedStablecoins` que el owner pueda manejar.
- **Anti-bot / anti-whale**: límite de compra por wallet (`maxBuyPerAddress`) para evitar concentraciones.
- **Script de deploy**: agregar `script/DeployPresale.s.sol` para deployar a una testnet.
