# Conceptos Clave — Solidity & Blockchain Development

> Documento de estudio basado en los 11 proyectos del portfolio. Organizado por tema (no por proyecto) para que sirva como referencia rápida pre-entrevista y review de conceptos.

## 📑 Índice

1. [Fundamentos de Solidity](#1-fundamentos-de-solidity)
2. [Identidad y Access Control](#2-identidad-y-access-control)
3. [ETH y Activos Nativos](#3-eth-y-activos-nativos)
4. [Tokens ERC-20](#4-tokens-erc-20)
5. [NFTs (ERC-721)](#5-nfts-erc-721)
6. [Comunicación entre Contratos](#6-comunicación-entre-contratos)
7. [Patrones de Seguridad](#7-patrones-de-seguridad)
8. [DeFi y Composability](#8-defi-y-composability)
9. [Oracles (Chainlink)](#9-oracles-chainlink)
10. [Matemática de Decimales](#10-matemática-de-decimales)
11. [State Machines](#11-state-machines)
12. [Foundry y Testing](#12-foundry-y-testing)
13. [Patrones Comunes](#13-patrones-comunes)
14. [Gotchas Frecuentes](#14-gotchas-frecuentes)

---

## 1. Fundamentos de Solidity

### Licencia SPDX y Pragma

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
```

- **SPDX** declara la licencia para herramientas legales.
- **`pragma solidity 0.8.24`** (pinned) → un solo compilador exacto.
- **`pragma solidity ^0.8.20`** → cualquier versión `>=0.8.20 <0.9.0`.

### Tipos de datos

| Tipo | Descripción | Default |
|---|---|---|
| `uint256` | Entero sin signo (0 a 2²⁵⁶-1) | `0` |
| `int256` | Entero con signo | `0` |
| `bool` | true/false | `false` |
| `address` | Dirección de 20 bytes | `address(0)` |
| `address payable` | Address que puede recibir ETH | `address(0)` |
| `bytes32` | 32 bytes fijos | `0x00..0` |
| `bytes` | Bytes dinámicos | `""` |
| `string` | Texto UTF-8 dinámico | `""` |

### Visibilidad de funciones

| Visibilidad | Quién puede llamarla |
|---|---|
| **`public`** | Cualquiera (interno y externo). Genera getter si es state var. |
| **`external`** | Solo desde afuera del contrato (otros contratos, EOAs). Más barato en gas que `public` para args grandes. |
| **`internal`** | El contrato mismo y sus herederos. |
| **`private`** | **Solo el contrato mismo** (ni siquiera herederos). |

> ⚠️ **`private` NO significa secreto**. Cualquiera puede leer storage on-chain con tools como `cast storage`. "Privado" en Solidity es solo restricción de acceso a nivel código.

### Modifiers

Funciones que **se ejecutan antes (o después)** del cuerpo de la función. El `_;` marca dónde corre la lógica original.

```solidity
modifier onlyAdmin() {
    require(msg.sender == admin, "Not allowed");
    _;   // ← acá corre la función decorada
}

function modifyMaxBalance(uint256 newMax_) external onlyAdmin {
    maxBalance = newMax_;
}
```

### Events

Logs persistentes en la blockchain. **Más baratos que storage**. Indispensables para que frontends/indexers (TheGraph, OpenSea) se enteren de cambios.

```solidity
event Deposited(address indexed user, uint256 amount);
emit Deposited(msg.sender, msg.value);
```

- **`indexed`** (hasta 3 params): permite filtrar por ese campo en logs.
- **Sin `indexed`**: incluido en data, no filtrable pero pesado.

### State Variables

Vivien en **storage** (caro: ~20,000 gas un SSTORE). Si una variable es `public`, Solidity genera automáticamente un getter.

```solidity
uint256 public balance;   // genera function balance() public view returns (uint256)
```

### `require` vs `revert` vs Custom Errors

```solidity
// 1. require — clásico, string en bytecode (caro)
require(amount > 0, "Amount must be > 0");

// 2. revert con string — equivalente
if (amount == 0) revert("Amount must be > 0");

// 3. Custom error (Solidity ≥0.8.4) — barato + tipado
error InvalidAmount(uint256 provided);
if (amount == 0) revert InvalidAmount(amount);
```

**Cuál usar**: en código moderno, **custom errors siempre que sea posible** — más baratos en gas y más informativos para los tests.

### Convenciones de naming

- **Contracts/Events/Structs**: `PascalCase` (`StakingApp`, `Listing`).
- **Functions/variables/modifiers**: `camelCase` (`buyNFT`, `userBalance`).
- **Constants**: `UPPER_CASE_WITH_UNDERSCORES`.
- **Parámetros (convención del curso)**: sufijo `_` (`amount_`, `tokenId_`).

---

## 2. Identidad y Access Control

### `msg.sender` vs `tx.origin`

| | `msg.sender` | `tx.origin` |
|---|---|---|
| **Qué es** | Quien llamó la función directamente | Quien firmó la tx original (siempre EOA) |
| **Cambia con contratos intermedios** | Sí | No |
| **Uso para auth** | ✅ Correcto | ❌ Peligroso (vulnerable a phishing contracts) |

**El ataque típico de `tx.origin`**:

```
Lucas (EOA) → Atacante (contrato) → Sumador
```

Para Sumador:
- `msg.sender` = Atacante ✅ (rechazaría el call si onlyAdmin con msg.sender)
- `tx.origin` = Lucas ❌ (si admin == Lucas, pasaría el check)

**Regla**: nunca usar `tx.origin` para autorización.

### `Ownable` (OpenZeppelin)

Standard de access control de single-owner.

```solidity
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyContract is Ownable {
    constructor() Ownable(msg.sender) {}   // OZ v5 requiere pasar el owner explícito
    
    function adminOnly() external onlyOwner { ... }
}
```

**Errores de Ownable v5**:
- `Ownable.OwnableUnauthorizedAccount(address account)` — non-owner trata de llamar.
- `Ownable.OwnableInvalidOwner(address owner)` — owner inválido (e.g. address(0)).

Test con specifier:
```solidity
vm.expectRevert(
    abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user)
);
```

### `Ownable2Step`

Variant de `Ownable` que **requiere dos pasos** para transferir ownership: `transferOwnership` + `acceptOwnership`. Previene transferir accidentalmente a una address equivocada.

### Custom access control

Para gating más complejo (whitelist, roles, blacklist), suele ser custom:

```solidity
mapping(address => bool) public isBlacklisted;

function blacklistAddress(address user_) external onlyOwner {
    isBlacklisted[user_] = true;
}

function someAction() external {
    require(!isBlacklisted[msg.sender], "Blacklisted");
    // ...
}
```

---

## 3. ETH y Activos Nativos

### `payable`

Modificador que permite a una función **recibir ETH**.

```solidity
function deposit() external payable {
    // msg.value contiene la cantidad de ETH enviada
}
```

Sin `payable`, si alguien envía ETH al llamar la función → revierte automáticamente.

### `msg.value`

Variable global con la cantidad de **wei** enviada en la tx.

```solidity
1 ETH = 10^18 wei
1 gwei = 10^9 wei
```

### `receive()` y `fallback()`

Funciones especiales que ejecutan **cuando llega ETH** o cuando se llama una función inexistente.

```solidity
receive() external payable {}      // se dispara con ETH "pelado" (calldata vacío)
fallback() external payable {}     // se dispara cuando no matchea ninguna función
```

**Decision tree cuando llega una call a un contrato**:

```
Calldata vacío + ETH → ¿receive()? → Sí: ejecuta. No: ¿fallback() payable? → Sí: ejecuta. No: REVIERTE.

Calldata con selector que no matchea → ¿fallback()? → Sí: ejecuta. No: REVIERTE.

Calldata con selector que matchea → ejecuta esa función.
```

### EOAs vs Contratos para recibir ETH

| | Aceptar ETH sin nada extra |
|---|---|
| **EOA** (wallet normal) | ✅ Siempre |
| **Contrato** | ❌ Necesita `receive()` o `fallback() payable` |

### `transfer` vs `send` vs `call` para enviar ETH

```solidity
// 1. transfer — DEPRECATED — forwarder 2300 gas, revierte si falla
payable(to).transfer(amount);

// 2. send — DEPRECATED — forwarder 2300 gas, devuelve bool
bool success = payable(to).send(amount);

// 3. call — RECOMENDADO — forwarder todo el gas, devuelve (bool, bytes)
(bool success, ) = to.call{value: amount}("");
require(success, "Transfer failed");
```

**Por qué `call` es el estándar moderno**:
- El límite de 2300 gas de `transfer`/`send` está obsoleto desde EIP-1884.
- Si el receptor es un contrato con receive/fallback que cuesta más de 2300 gas → falla con `transfer`.
- `.call` reenvía todo el gas → robusto contra cualquier receptor.

### Sintaxis de `call`

```solidity
(bool success, bytes memory data) = address.call{value: X, gas: Y}(calldata);
```

- `value: X` → cantidad de ETH a adjuntar (opcional).
- `gas: Y` → límite de gas (opcional).
- `calldata` → bytes que indican qué función llamar (vacío `""` para ETH pelado).

---

## 4. Tokens ERC-20

### El estándar

```solidity
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
```

### Patrón `approve` + `transferFrom`

A diferencia de ETH, **no podés mandar tokens "adjuntos" a una tx**. El flujo es:

```
1. user.approve(spender, amount)
   ↓ (registra allowance en storage del token)
2. spender.transferFrom(user, recipient, amount)
   ↓ (toma los tokens del user, los manda al recipient)
```

**Cuándo se usa**:
- Cuando un contrato (spender) necesita mover tokens **de** un user.
- Ejemplo: marketplace que vende NFT por USDC — el user `approve` al marketplace, el marketplace hace `transferFrom`.

### `_mint` y `_burn`

```solidity
// Mintear = crear tokens nuevos
_mint(to, amount);     // suma a balance + totalSupply

// Burn = destruir tokens
_burn(from, amount);   // resta de balance + totalSupply
```

Son `internal` en OpenZeppelin → el contrato hijo decide cuándo/cómo exponerlos.

### Decimales

`ERC-20` no impone decimales, pero la convención es **18** (igual que ETH).

```solidity
contract Token is ERC20 {
    // decimals() devuelve 18 por default
}
```

**Excepciones famosas**:
- **USDC**: 6 decimales
- **USDT**: 6 decimales
- **WBTC**: 8 decimales

### `SafeERC20`

Wrapper de OpenZeppelin que protege contra tokens "no estándar". El problema: el ERC-20 spec dice que `transfer`/`transferFrom` deben devolver `bool`, pero **algunos tokens (USDT, BNB viejo) devuelven `false` en vez de revertir, o no devuelven nada**.

```solidity
using SafeERC20 for IERC20;

IERC20(token).safeTransfer(to, amount);        // revierte si transfer devuelve false
IERC20(token).safeTransferFrom(from, to, amt); // idem para transferFrom
IERC20(token).safeApprove(spender, amount);    // DEPRECATED, usar forceApprove
IERC20(token).forceApprove(spender, amount);   // maneja el quirk de USDT
```

### El bug del `approve` de USDT (race condition)

El ERC-20 estándar tiene una race condition conocida: si bajás tu allowance de 100 → 50, un spender malicioso puede `transferFrom` los 100 viejos + los 50 nuevos antes que tu tx se confirme.

**USDT lo "arregló"** rechazando `approve(X)` si ya hay `allowance > 0` (te obliga a hacer `approve(0)` primero).

**`forceApprove`** te resuelve esto automáticamente:

```solidity
function forceApprove(token, spender, value) {
    try token.approve(spender, value) {
        // OK
    } catch {
        token.approve(spender, 0);          // reset
        token.approve(spender, value);       // try again
    }
}
```

---

## 5. NFTs (ERC-721)

### El estándar

```solidity
interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    // ...
}
```

**Diferencia clave con ERC-20**: cada `tokenId` es **único e indivisible**. No tiene `decimals`, no se "fragmenta".

### `_safeMint` vs `_mint`

```solidity
_mint(to, tokenId);       // mintea sin validar
_safeMint(to, tokenId);   // mintea + verifica que el receptor pueda recibir NFTs
```

**Por qué `_safeMint`**: si el receptor es un contrato que no implementa `onERC721Received`, el NFT queda **atrapado para siempre** (nadie lo puede transferir). `_safeMint` verifica el handshake antes de transferir.

**Tradeoff**: `_safeMint` es ligeramente más caro (hace un call externo al receptor si es contrato).

### Token URIs y metadata

El contrato **no guarda metadata** (imagen, nombre, atributos). Solo guarda una **URI** que apunta a un JSON.

```solidity
function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    return string.concat(baseURI, tokenId.toString(), ".json");
}
```

**Patrón `baseURI`**: en lugar de setear URI por cada token (caro en storage), seteás una `baseURI` única y derivás cada URI con concatenación.

### Formato OpenSea de la metadata

```json
{
    "name": "Solidity Portfolio #0",
    "description": "First NFT",
    "image": "ipfs://CID_de_la_imagen",
    "attributes": [
        {
            "trait_type": "Edition",
            "value": "Genesis"
        },
        {
            "display_type": "number",
            "trait_type": "Token ID",
            "value": 0
        }
    ]
}
```

### IPFS

Sistema de archivos descentralizado direccionable por contenido (cada archivo tiene un CID = hash de su contenido).

**Workflow estándar para subir NFTs**:
1. Subir imágenes a IPFS → te devuelve CID por imagen.
2. Editar JSONs con las URIs `ipfs://CID_imagen_X`.
3. Subir los JSONs a IPFS (en una carpeta) → te devuelve CID de la carpeta.
4. Setear `baseURI = ipfs://CID_carpeta_jsons/` en el contrato.

---

## 6. Comunicación entre Contratos

### Interfaces

Declaran solo las **firmas** de funciones, sin implementación. Tu contrato puede hablar con otro contrato sabiendo solo su interfaz.

```solidity
interface IV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

// Para llamarlo:
IV2Router02(routerAddress).swapExactTokensForTokens(...);
```

### El triple patrón "wrapper de protocolo"

Cuando tu contrato actúa como intermediario para mover tokens del user a un protocolo externo (Uniswap, Aave, etc.):

```solidity
// 1. CHEQUEAR: validaciones, modifier, requires
// 2. CHUPAR tokens del user al contrato
IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
// 3. AUTORIZAR al protocolo a usar nuestros tokens
IERC20(token).forceApprove(externalProtocol, amount);
// 4. LLAMAR al protocolo (que hará el transferFrom)
IExternalProtocol(externalProtocol).doStuff(amount);
```

### `abi.encodeWithSelector` y selectors

El selector de una función son los **primeros 4 bytes del hash keccak256 de su firma**.

```solidity
bytes4 selector = bytes4(keccak256("transfer(address,uint256)"));
// = 0xa9059cbb
```

Útil en:
- `vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user))`
- Llamadas de bajo nivel con `call`.

### Composability ("Money Legos")

Tu contrato puede **enchufar con cualquier otro contrato deployado** en la chain sin necesitar su código fuente — alcanza con conocer su interfaz. Esa es la magia de DeFi.

---

## 7. Patrones de Seguridad

### CEI (Checks-Effects-Interactions)

Orden de operaciones en una función para **prevenir reentrancy**:

1. **Checks**: validar precondiciones (requires).
2. **Effects**: actualizar state variables.
3. **Interactions**: llamadas externas (transfers, calls).

```solidity
function withdraw(uint256 amount_) external {
    // 1. CHECKS
    require(amount_ <= userBalance[msg.sender], "Not enough");
    
    // 2. EFFECTS (antes que la call externa)
    userBalance[msg.sender] -= amount_;
    
    // 3. INTERACTIONS (al final)
    (bool success, ) = msg.sender.call{value: amount_}("");
    require(success, "Transfer failed");
}
```

**Por qué funciona**: si el receptor intenta re-entrar `withdraw` desde su `receive()`, ya encuentra `userBalance` en 0 → el `require` revierte → no se duplica el retiro.

### Reentrancy Attack (clásico)

```
Atacante.attack():
  → Vulnerable.withdraw()
       check(balance >= X) ✅
       send ETH to Atacante
            → Atacante.receive()
                 → Vulnerable.withdraw()    ← reentrada!
                      check(balance >= X) ✅ (no se actualizó)
                      send ETH again
                      ...
```

Resultado: el atacante drena el contrato.

### `ReentrancyGuard`

Mutex que bloquea reentrancias:

```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Foo is ReentrancyGuard {
    function withdraw() external nonReentrant {
        // ...
    }
}
```

**CEI vs ReentrancyGuard**: CEI es el patrón "limpio" (sin overhead de gas). `nonReentrant` es la "red de seguridad" (cuesta ~5000 gas por uso). En código serio se usan **los dos juntos** (cinturón y tiradores).

### Custom errors vs require strings

```solidity
// Caro:
require(amount > 0, "Amount must be positive");

// Barato + tipado:
error InvalidAmount(uint256 amount);
if (amount == 0) revert InvalidAmount(amount);
```

**Gas savings**: ~50 gas por revert + ~200 gas por byte del string (que vive en bytecode).

### `_safeMint` y `safeTransferFrom`

Variantes "safe" de `_mint` y `transferFrom` que verifican que el receptor pueda recibir el activo. Sin esto, los NFTs/tokens enviados a contratos no preparados se **pierden para siempre**.

### Pull over Push (claim pattern)

En lugar de que el contrato "pushee" assets a los users (`for (uint i = 0; i < users.length; i++) users[i].transfer(...)`), se hace que los users los "puleen" (`claim()`).

**Por qué**: si un user es un contrato malicioso que reverte el `receive`, el push freeze al contrato. Con pull, el riesgo está aislado en cada user.

### Emergency withdraw

Función `onlyOwner` para retirar fondos en caso de bug/ataque. Trade-off: **centralización**. El owner SIEMPRE puede drenar. En producción se mitiga con multisig o timelock.

---

## 8. DeFi y Composability

### AMM (Automated Market Maker)

Reemplazo del orderbook tradicional. En vez de matching orders, usás una **fórmula matemática** sobre las reservas del pool.

**Uniswap V2 fórmula**: `x * y = k` (constant product).

```
Pool: 1,000,000 USDC + 1,000,000 DAI  (k = 1e12)

Swap 100 USDC → ?
Nueva reserva USDC: 1,000,100
Nueva reserva DAI: k / 1,000,100 = 999,900.01
DAI out: 1,000,000 - 999,900.01 = 99.99 DAI
```

El **precio se ajusta automáticamente** con cada swap. Cuanto más sacás de un lado, más caro se vuelve.

### Liquidity Provider (LP)

Quien deposita tokens en un pool. A cambio recibe **LP tokens** que representan su porción del pool. Gana **fees** (0.30% por swap en V2) pero asume **impermanent loss** (si los precios relativos cambian).

### Router de Uniswap

Contrato "puerta de entrada". Tu contrato NO habla con los pools directo — habla con el router. El router rutea, calcula montos, maneja paths multi-hop.

```solidity
// Funciones clave del router V2:
swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
swapExactETHForTokens(amountOutMin, path, to, deadline) payable;
swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);
addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline);
removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
```

### Parámetros típicos del Router

| Parámetro | Para qué |
|---|---|
| `amountIn` | Cuánto del token de entrada |
| `amountOutMin` | Mínimo aceptable de salida (**slippage protection**) |
| `path` | Array de tokens del swap (`[USDC, DAI]` directo o `[USDC, WETH, DAI]` multi-hop) |
| `to` | Quién recibe el output |
| `deadline` | Timestamp después del cual revierte |

### Slippage

El precio del pool **cambia con cada swap**. Si firmás una tx pero pasan otras txs antes que la tuya, podrías recibir menos de lo esperado. `amountOutMin` te protege.

**Anti-MEV** también: el `deadline` evita que mineros holdeen tu tx por horas para ejecutarla en el peor momento.

### Add/Remove Liquidity

```
addLiquidity:
  USER → token A + token B → POOL
  POOL → LP tokens → USER

removeLiquidity:
  USER → LP tokens → POOL
  POOL → token A + token B → USER (proporcional)
```

### Factory

Contrato que **crea pools y mantiene el registro** `(tokenA, tokenB) → poolAddress`.

```solidity
address pool = IV2Factory(factory).getPair(tokenA, tokenB);
```

### Marketplace sin custodia

Modelo de OpenSea simplificado:
- El contrato del marketplace **NUNCA toma posesión del NFT**.
- El vendedor da `approve(marketplace, tokenId)`.
- Cuando alguien compra, el marketplace hace `safeTransferFrom(seller, buyer, tokenId)` directo.

**Ventaja**: si el marketplace se hackea, los NFTs siguen estando en las wallets de los vendedores. No hay un "pool" gigante de NFTs en riesgo.

---

## 9. Oracles (Chainlink)

### Por qué necesitamos oracles

Los smart contracts **no tienen acceso a data del mundo real**:
- Precio de ETH en USD
- Resultado de un partido de fútbol
- Clima
- Tipos de cambio fiat

Un **oracle** es un servicio que trae esa data **on-chain** firmada por nodos confiables.

### ¿Por qué no usar el precio de un DEX?

Los precios de los DEX (Uniswap pools) son **manipulables con flash loans**:

```
1. Atacante toma flash loan de 1M USDC.
2. Hace un swap gigante en el pool → distorsiona el precio.
3. Tu protocolo lee el precio "manipulado" → liquida o presta en exceso.
4. Atacante revierte el swap, devuelve el flash loan, queda con el profit.
```

Chainlink usa **datos agregados de múltiples sources off-chain** y los publica firmados → mucho más difícil de manipular.

### `AggregatorV3Interface`

Interfaz estándar de Chainlink Price Feeds.

```solidity
interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,         // ← el precio
        uint256 startedAt,
        uint256 updatedAt,     // ← cuándo se actualizó
        uint80 answeredInRound
    );
    
    function decimals() external view returns (uint8);   // ← cuántos decimales
}
```

### Decimales de Chainlink

Casi todos los price feeds de Chainlink **devuelven precios con 8 decimales**.

- ETH/USD = $3,000 → `answer = 3000 * 1e8 = 300_000_000_000`

Para normalizar a 18 decimales (estándar de DeFi):
```solidity
uint256 price = uint256(answer) * 10**10;   // 8 → 18 decimales
```

### Stale price check

```solidity
(, int256 price, , uint256 updatedAt, ) = aggregator.latestRoundData();
require(price > 0, "Invalid price");
require(updatedAt > block.timestamp - 1 hours, "Price too old");
```

### Ejemplo: comprar con ETH en una presale

```solidity
function buyWithEther() external payable {
    uint256 etherPrice = getEtherPrice();              // ETH en USD (18 decimales)
    uint256 usdValue = (msg.value * etherPrice) / 1e18; // valor en USD
    uint256 tokens = (usdValue * 1e6) / pricePerToken; // tokens a entregar
    userBalance[msg.sender] += tokens;
}
```

---

## 10. Matemática de Decimales

### Las "tres realidades" de DeFi

| Activo | Decimales |
|---|---|
| ETH | 18 |
| WETH | 18 |
| USDC | 6 |
| USDT | 6 |
| DAI | 18 |
| WBTC | 8 |
| Chainlink prices | 8 |

### Bug clásico de unidades

```solidity
uint256 totalSupply = 100;                  // ¿escalado o no?
uint256 amount = userInput;                 // ¿en qué decimales?
require(totalSupply <= someCap, "...");     // ¿qué unidades tiene someCap?
```

Si una comparación involucra valores en distintas escalas, **algo va a romper**.

### Normalización a 18 decimales

Patrón típico cuando aceptás múltiples stablecoins:

```solidity
// Cantidad escalada a 18 decimales:
uint256 scaledAmount = amount * (10 ** (18 - ERC20(token).decimals()));

// Para USDC (6): amount * 10^12 → escala a 18
// Para DAI (18): amount * 10^0 = amount → ya está en 18
```

### Multiplicar antes de dividir

```solidity
// MAL — pierde precisión (división trunca):
uint256 result = (a / b) * c;

// BIEN — preserva precisión:
uint256 result = (a * c) / b;
```

### Overflow / Underflow

En Solidity ≥0.8.0, las operaciones aritméticas tienen check automático y **revierten** en overflow/underflow.

```solidity
uint256 x = 0;
x -= 1;   // revierte (underflow)
```

Para opt-out (cuando estás seguro y querés ahorrar gas):
```solidity
unchecked {
    x -= 1;   // wraps around, no revierte
}
```

---

## 11. State Machines

### El patrón

Cuando tu contrato tiene **estados discretos con transiciones**:

```solidity
enum Phase { Seed, Private, Public, Ended }
Phase public currentPhase;

modifier inPhase(Phase phase_) {
    require(currentPhase == phase_, "Wrong phase");
    _;
}

function advancePhase() external onlyOwner {
    currentPhase = Phase(uint(currentPhase) + 1);
}
```

### Transiciones automáticas

A veces la transición no es manual sino **condicional** (cap alcanzado, tiempo pasado).

```solidity
function checkPhase(uint256 amount_) internal {
    if (totalSold + amount_ >= phases[currentPhase].cap ||
        block.timestamp >= phases[currentPhase].deadline) {
        if (currentPhase < MAX_PHASE) currentPhase++;
    }
}
```

### Ejemplos donde aparece

- Presales (Seed → Private → Public → Ended)
- Vesting (Cliff → Linear → Done)
- Auctions (Bidding → Reveal → Settled)
- Crowdfunding (Active → Failed → Refund / Success → Claim)
- Games (Setup → Playing → GameOver)

---

## 12. Foundry y Testing

### Comandos básicos

```bash
forge init <dir> --use-parent-git --empty   # crear proyecto
forge build                                  # compilar
forge test                                   # correr tests
forge test -vvv                              # con traces detallados
forge test --match-test testFoo              # un test específico
forge test --gas-report                      # reporte de gas
forge coverage                               # coverage
forge install <repo>                         # instalar dependencias
forge remappings > remappings.txt           # generar remappings
forge script script/Deploy.s.sol            # correr script de deploy
```

### `foundry.toml` típico

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.24"
evm_version = "cancun"
via_ir = true               # para evitar stack-too-deep
optimizer = true
optimizer_runs = 200
```

### Estructura de un proyecto Foundry

```
project/
├── foundry.toml
├── remappings.txt
├── src/                # contratos
├── test/               # archivos .t.sol
├── script/             # archivos .s.sol
└── lib/                # submódulos (forge-std, OpenZeppelin)
```

### Naming convention

```
TestContract.t.sol    → archivo de tests
DeployContract.s.sol  → archivo de script
```

### Setup básico de un test

```solidity
import "forge-std/Test.sol";
import "../src/MyContract.sol";

contract MyContractTest is Test {
    MyContract myContract;
    
    function setUp() public {
        myContract = new MyContract();
    }
    
    function testSomething() public {
        // ...
    }
}
```

### `setUp()`

Se ejecuta **antes de cada test**. Es como un "beforeEach".

### Cheatcodes (`vm.*`)

| Cheatcode | Para qué |
|---|---|
| **`vm.prank(addr)`** | El **próximo** call tiene `msg.sender = addr` |
| **`vm.startPrank(addr)`** + **`vm.stopPrank()`** | Todos los calls hasta el `stop` tienen `msg.sender = addr` |
| **`vm.deal(addr, amount)`** | Setea el **balance de ETH** de `addr` |
| **`deal(token, addr, amount)`** | Mintea **ERC-20** (de StdCheats, no `vm.`) |
| **`vm.warp(timestamp)`** | Adelanta el reloj |
| **`vm.roll(blockNumber)`** | Adelanta el bloque |
| **`vm.expectRevert()`** | El próximo call debe revertir |
| **`vm.expectRevert("msg")`** | Debe revertir con ese mensaje |
| **`vm.expectRevert(abi.encodeWithSelector(...))`** | Debe revertir con ese custom error |
| **`vm.expectEmit(true, true, true, true)`** | El próximo emit debe matchear el siguiente |
| **`vm.assume(condition)`** | En fuzz tests, skip inputs que no cumplan |
| **`vm.addr(privateKey)`** | Genera address determinística desde una pk |
| **`vm.getNonce(addr)`** | Lee el nonce de una address |
| **`vm.computeCreateAddress(deployer, nonce)`** | Predice la futura address de un deploy |
| **`vm.envUint("KEY")`** | Lee variable de entorno (uint) |
| **`vm.startBroadcast(pk)`** | En scripts: las próximas operaciones se mandan a la red |

### `vm.prank` vs `vm.startPrank`

```solidity
vm.prank(user);              // solo el PRÓXIMO call
contract.foo();              // foo se ejecuta como user
contract.bar();              // bar se ejecuta como el test (default)

vm.startPrank(user);
contract.foo();              // user
contract.bar();              // user
vm.stopPrank();
contract.baz();              // default
```

**⚠️ Cuidado**: `vm.prank` se "consume" con **cualquier call**, incluyendo getters (lecturas).

```solidity
vm.prank(owner);
uint256 x = contract.someValue();   // ← este consume el prank
contract.adminFunction();           // ← este YA NO está pranqueado!
```

### Fork Testing

```bash
forge test --fork-url $RPC_URL -vvv
```

Foundry levanta una **copia local del estado real de una red** (mainnet, Arbitrum, Polygon...) y vos podés interactuar con los contratos reales (USDC real, Chainlink real, Uniswap real) **sin gastar gas**.

```solidity
contract ForkTest is Test {
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum
    
    function testRealUSDC() public {
        uint256 balance = IERC20(USDC).balanceOf(someWhale);
        // funciona porque estamos forkeando Arbitrum
    }
}
```

### Whale Prank

En fork tests: encontrar una EOA con balance del token que querés y "pranquearla":

```solidity
address whale = 0xe8D294F3fff2A5CB34D15eCdEF34A53b01f5A462;  // wallet con USDC en Arbitrum
vm.startPrank(whale);
IERC20(USDC).transfer(test, 1000 * 1e6);
vm.stopPrank();
```

### `deal()` para tokens

Cheatcode de `StdCheats` que **escribe directo en el storage** del token para darle un balance a una address.

```solidity
deal(USDC, user, 1000 * 1e6);   // user ahora tiene 1000 USDC
```

Más simple que el whale prank. Funciona con casi todos los tokens.

### Fuzz Testing

Foundry corre el test con **inputs random** (256 corridas por default).

```solidity
function testFuzzingAdd(uint256 a, uint256 b) public {
    vm.assume(a < type(uint256).max / 2);   // skip casos que overflowearían
    vm.assume(b < type(uint256).max / 2);
    
    uint256 sum = calculator.add(a, b);
    assertEq(sum, a + b);
}
```

### Mock Contracts

Versiones simplificadas de contratos externos para tests determinísticos:

```solidity
contract MockNFT is ERC721 {
    constructor() ERC721("Mock", "MNFT") {}
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);   // mint público para testing
    }
}

contract MockAggregator {
    int256 public price;
    constructor(int256 price_) { price = price_; }
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, price, 0, 0, 0);
    }
}
```

### `vm.expectRevert` con specifier

```solidity
// 1. Bare — matchea CUALQUIER revert (peligroso, da falsa cobertura)
vm.expectRevert();

// 2. Con string — matchea ese mensaje exacto
vm.expectRevert("Not allowed");

// 3. Con custom error (lo más preciso)
vm.expectRevert(
    abi.encodeWithSelector(MyError.selector, arg1, arg2)
);
```

### `vm.computeCreateAddress`

Predice la address de un futuro deploy. Útil cuando un constructor requiere `approve` antes del deploy (chicken-and-egg):

```solidity
uint64 nonce = vm.getNonce(address(this));
address futurePresale = vm.computeCreateAddress(address(this), nonce);
saleToken.approve(futurePresale, totalSupply);
presale = new Presale(...);   // deploya en futurePresale
```

### Stack too deep

Error que aparece cuando hay **más de ~16 variables locales** en una función. Solución típica: activar `via_ir = true` en `foundry.toml` (pipeline de compilación Yul-IR).

---

## 13. Patrones Comunes

### Pull over Push (Claim Pattern)

Los users **retiran** sus fondos cuando ellos quieren, en lugar de que el contrato se los push-ee.

**Casos**: presales (claim después de endingTime), airdrops, vesting, rewards de staking.

```solidity
mapping(address => uint256) public userBalance;

function buyTokens() external payable {
    userBalance[msg.sender] += calculateAmount(msg.value);   // boleta
}

function claim() external {
    require(block.timestamp >= claimStart, "Not yet");
    uint256 amount = userBalance[msg.sender];
    delete userBalance[msg.sender];
    token.safeTransfer(msg.sender, amount);
}
```

### CEI (Checks-Effects-Interactions)

(Ver sección Patrones de Seguridad.)

### Two-step Ownership Transfer

(Ver Ownable2Step en Identidad y Access Control.)

### Mock Contracts para Testing

(Ver sección Foundry y Testing.)

### Withdrawal Pattern

(Ya cubierto: variante de pull over push.)

### Wrapper de Protocolo

```solidity
// Triple patrón:
// 1. safeTransferFrom user → contract
// 2. forceApprove contract → external protocol
// 3. external protocol does the heavy lifting
```

### No-Custody Marketplace

El contrato del marketplace **nunca toma posesión** de los activos. Solo orquesta transferencias atómicas en el momento de la venta.

### Emergency Withdraw

Función `onlyOwner` para rescatar fondos en caso de bug/ataque. **Trade-off: centralización**.

### Predicting CREATE Address

(Ver `vm.computeCreateAddress`.)

---

## 14. Gotchas Frecuentes

### 1. `tx.origin` para auth

❌ Vulnerable a phishing contracts. Usar `msg.sender`.

### 2. Receive ETH en contratos

Sin `receive()` o `fallback() payable`, **el contrato no puede recibir ETH** (las EOAs sí pueden).

### 3. USDT approve quirk

El `approve(X)` de USDT revierte si ya hay `allowance > 0`. Usar `forceApprove` de OpenZeppelin SafeERC20.

### 4. Hardcoded deadline en tests

```solidity
uint256 deadline = 1780616130;   // ❌ se queda viejo
uint256 deadline = block.timestamp + 1 hours;   // ✅
```

### 5. `vm.deal` vs `deal`

```solidity
vm.deal(addr, amount);            // setea balance de ETH
deal(token, addr, amount);        // mintea ERC-20 (StdCheats, sin vm.)
```

### 6. Decimales mismatch

USDC (6) + DAI (18) + Chainlink (8) + tu token (18) = receta para bugs. **Siempre anotar la escala en cada lado de una ecuación**.

### 7. Stack too deep

Si tu test tiene muchas vars locales → activar `via_ir` en `foundry.toml`.

### 8. `vm.prank` consumido por getters

`vm.prank` se gasta en el **próximo call**, incluyendo lecturas. Para múltiples calls usá `vm.startPrank`.

### 9. `_safeMint` vs `_mint`

Sin `_safeMint`, un NFT enviado a un contrato no preparado queda **trabado para siempre**.

### 10. `transfer`/`send` con receptor complejo

El límite de 2300 gas hace que `transfer`/`send` fallen si el receptor es un contrato con lógica. Usar `.call{value:}("")`.

### 11. Chainlink decimals assumption

No todos los feeds tienen 8 decimales. **Consultar `aggregator.decimals()`** en lugar de hardcodear.

### 12. Reentrancy en functions con `payable`

Cualquier función que mueva ETH es candidata. Aplicar CEI o `nonReentrant`.

### 13. `address(0)` checks

Validar en constructores: `require(someAddress != address(0), "Zero address")`.

### 14. Stale price de oracles

Chequear `updatedAt > block.timestamp - X` para que el precio no sea muy viejo.

### 15. `block.timestamp` manipulation

Los validators pueden mover `block.timestamp` ~12 segundos. Para periodos de días/horas no importa. Para precisión <12s, usar `block.number`.

### 16. PowerShell + `forge remappings > file.txt`

Windows + PowerShell graban en UTF-16 con BOM → Foundry no parsea. **Usar Git Bash** o `Out-File -Encoding utf8`.

### 17. `private` no es secreto

Cualquiera puede leer storage on-chain. `private` es solo restricción de acceso a nivel código.

### 18. Approve race condition

El ERC-20 estándar tiene una race condition al cambiar allowance de X a Y. Usar `forceApprove` o `increaseAllowance`/`decreaseAllowance`.

### 19. `view` lying

Una función `view` puede llamar otras funciones que SÍ modifican estado vía low-level call. La sintaxis no garantiza inmutabilidad real.

### 20. Constructor `safeTransferFrom`

Si un constructor hace `safeTransferFrom`, el deployer tiene que aprobar **antes** del deploy. Pero la address del contrato no existe todavía. Solución: `vm.computeCreateAddress`.

---

## 📚 Recursos para profundizar

- [Solidity Docs](https://docs.soliditylang.org/) — referencia oficial.
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) — librería estándar.
- [Foundry Book](https://book.getfoundry.sh/) — referencia de Foundry.
- [solidity-by-example.org](https://solidity-by-example.org/) — ejemplos prácticos.
- [secureum.xyz](https://secureum.xyz/) — auditoría y seguridad.
- [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) — ejercicios de seguridad.

---

> **Tip de estudio**: leer un proyecto del portfolio, intentar recrear el contrato de cero **sin mirar el código**, y comparar después. Lo que no pudiste recrear es lo que falta consolidar.
