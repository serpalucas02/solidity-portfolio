# 08 — NFT Marketplace

> Marketplace descentralizado de NFTs estilo OpenSea simplificado: los usuarios **listan** sus NFTs (ERC-721) a un precio en **ETH**, otros los **compran**, y el contrato hace de intermediario confiable **sin custodia** — nunca se queda los NFTs. Construido con Foundry + OpenZeppelin.

## Descripción

`NFTMarketplace` es un contrato que coordina la compra-venta de NFTs entre usuarios. Maneja tres operaciones:

1. **Listar** (`listNFT`): el dueño de un NFT lo publica a la venta a un precio en ETH.
2. **Cancelar** (`cancelListing`): el vendedor retira su NFT de la venta.
3. **Comprar** (`buyNFT`): un comprador paga el precio exacto en ETH, recibe el NFT, y el vendedor cobra al instante.

**Insight central — marketplace ≠ custodia**: el contrato **nunca toma posesión** de los NFTs. El NFT se queda en la wallet del vendedor durante todo el listing; recién en el momento de la compra el marketplace lo transfiere **directo del vendedor al comprador** (vía `approve` + `safeTransferFrom`). Esto es clave: el vendedor mantiene el control hasta el último segundo y no hay un pozo de NFTs que hackear.

Los listings viven on-chain en un `mapping(address => mapping(uint256 => Listing))`: indexados por **contrato NFT** y después por **tokenId**, porque el marketplace es agnóstico — puede vender NFTs de cualquier colección ERC-721.

Esta es la primera vez en el portfolio que un contrato **interactúa con contratos externos que no controla** (cualquier ERC-721 que el vendedor le pase) y mueve **fondos de terceros**, así que el foco está en los patrones de seguridad: CEI, `ReentrancyGuard` y validaciones de ownership.

## Features implementadas

- ✅ **NFT Marketplace** — overview y diseño del sistema (intermediario sin custodia).
- ✅ **Arquitectura del contrato** — un único `NFTMarketplace` que hereda `ReentrancyGuard` e interactúa con cualquier ERC-721 vía la interfaz `IERC721`.
- ✅ **Listing** — `struct Listing { seller, nftAddress, tokenId, price }` guardado en un mapping anidado.
- ✅ **List function** — `listNFT`: valida precio > 0 y que el caller sea el dueño del NFT.
- ✅ **Cancel listing** — `cancelListing`: solo el seller puede retirar su listing.
- ✅ **Buy NFT** — `buyNFT`: pago exacto en ETH, transfiere el NFT y paga al vendedor, con CEI + `nonReentrant`.
- ✅ **Mock NFT** — `MockNFT` (ERC-721 con `mint` público) dentro del test para tener con qué jugar.
- ✅ **Testing setup** — `setUp()` que deploya marketplace + mock y mintea un NFT al usuario.
- ✅ **Test listing** — happy path + reverts (precio 0, no-owner).
- ✅ **Test cancel listing** — solo el seller cancela; el listing se borra.
- ✅ **Test buy** — happy path con verificación de balances + reverts (no listado, monto incorrecto).

**Estado final**: 9/9 tests pasando ✅

## Estructura del proyecto

```
08-nft-marketplace/
├── foundry.toml                    ← Solidity 0.8.24, EVM Cancun
├── remappings.txt                  ← @openzeppelin/contracts/, forge-std/
├── src/
│   └── NFTMarketplace.sol          ← contrato del marketplace
├── test/
│   └── NFTMarketplace.t.sol        ← 9 tests + MockNFT (ERC-721 de prueba)
└── lib/
    ├── forge-std/                  ← cheatcodes y asserts
    └── openzeppelin-contracts/     ← IERC721, ERC721, ReentrancyGuard
```

## Contratos y tests

- [`src/NFTMarketplace.sol`](src/NFTMarketplace.sol) — marketplace sin custodia; hereda `ReentrancyGuard`, opera sobre cualquier `IERC721`.
- [`test/NFTMarketplace.t.sol`](test/NFTMarketplace.t.sol) — 9 tests (list / cancel / buy + reverts) y el `MockNFT` usado como NFT de prueba.

## Conceptos aplicados

### De Solidity / OpenZeppelin

- **`IERC721` (interfaz, no implementación)** — el marketplace no hereda de `ERC721`, sino que **habla** con NFTs externos vía su interfaz. Hace `ownerOf(tokenId)` para validar y `safeTransferFrom(from, to, tokenId)` para mover el NFT. Es agnóstico a la colección.
- **`approve` + `safeTransferFrom` (modelo de delegación de ERC-721)** — para que el marketplace pueda transferir el NFT del seller, el seller primero tiene que llamar `approve(marketplace, tokenId)` (o `setApprovalForAll`). Sin ese permiso, el `safeTransferFrom` revierte. Es el "consentimiento explícito" del estándar.
- **`safeTransferFrom` vs `transferFrom`** — `safeTransferFrom` chequea que el receptor (si es un contrato) sepa recibir NFTs (`onERC721Received`), evitando que un NFT quede trabado para siempre.
- **`ReentrancyGuard` + `nonReentrant`** — `buyNFT` mueve un NFT y manda ETH (dos interacciones externas). El modifier bloquea reentradas mientras se ejecuta.
- **CEI pattern (Checks → Effects → Interactions)** — en `buyNFT` se valida, se **borra el listing** (effect) y recién después se transfiere el NFT y se paga al seller (interactions). Si alguien intenta reentrar, el listing ya no existe.
- **Pago con `call{value:}` + chequeo del `success`** — la forma recomendada de mandar ETH hoy (en vez de `transfer`/`send`), validando el booleano de retorno.
- **Pago exacto (`msg.value == price`)** — exigir el monto justo evita tener que manejar devolución de vuelto.
- **`mapping` anidado** — `nftAddress => (tokenId => Listing)` para identificar de forma única cualquier NFT de cualquier colección.

### De Foundry / forge-std

- **Mock contracts para testing** — `MockNFT` es un ERC-721 con `mint` público: en vez de testear contra una colección real, se usa una versión "tonta" y reproducible.
- **`vm.addr(uint256)`** — addresses determinísticas para los roles (`deployer`, `user`, `user2`).
- **`vm.prank` / `vm.startPrank` / `vm.stopPrank`** — ejecutar llamadas como distintas identidades (el seller lista, el buyer compra).
- **`vm.deal(addr, amount)`** — darle ETH al comprador para que pueda pagar.
- **`vm.expectRevert("mensaje")`** — verificar que las validaciones revierten con el mensaje correcto.
- **Verificación de balances** — en `testBuyNFTCorrectly` se compara `user.balance` antes/después para confirmar que el vendedor **realmente cobró** el ETH (no alcanza con que cambie el owner del NFT).

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/08-nft-marketplace`).

```bash
# Compilar
forge build

# Correr toda la suite
forge test

# Con traces detallados
forge test -vvv

# Un test específico
forge test --match-test testBuyNFTCorrectly

# Reporte de gas
forge test --gas-report
```

### Flujo end-to-end (lo que prueba `testBuyNFTCorrectly`)

```
1. Deployer deploya NFTMarketplace y MockNFT.
2. User mintea el NFT (tokenId 0).
3. User:
   3.1. Lista el NFT en el marketplace a 1 ETH (listNFT).
   3.2. Aprueba al marketplace a mover ese NFT (nft.approve).
4. User2 (comprador):
   4.1. Tiene 1 ETH (vm.deal).
   4.2. Llama buyNFT{value: 1 ether}.
5. El marketplace borra el listing, transfiere el NFT user → user2,
   y le paga el ETH al user (seller).
6. Se verifica: nuevo owner == user2, listing borrado, y el seller cobró el ETH.
```

## Aprendizajes

- **Un marketplace bueno no custodia nada**: la primera intuición es "el contrato se queda el NFT hasta que se venda", pero eso crea un pozo gigante de NFTs en riesgo. El patrón real es `approve` + transferencia directa seller → buyer en el momento de la compra. El NFT nunca pasa por el contrato.
- **Hablar con contratos por interfaz (`IERC721`)**: no hace falta heredar de `ERC721` para operar sobre NFTs ajenos — alcanza con la interfaz. Eso hace al marketplace **agnóstico**: funciona con cualquier colección que respete el estándar.
- **El `approve` es un paso aparte y fácil de olvidar**: si el seller lista pero no aprueba, el listing existe pero `buyNFT` revierte al intentar mover el NFT. El comprador no pierde plata (la tx revierte entera), pero es mala UX. Aprendí que conviene validar la aprobación al listar.
- **CEI + `nonReentrant` no son opcionales cuando movés value**: `buyNFT` hace dos llamadas externas (transferir NFT y pagar al seller). Borrar el listing **antes** de esas llamadas + el guard cierra la puerta a la reentrancy.
- **Pago exacto simplifica la vida**: exigir `msg.value == price` evita toda la lógica de calcular y devolver vuelto, que es justo donde se cuelan bugs.
- **Testear el balance, no solo el estado**: que el NFT cambie de dueño no prueba que el vendedor cobró. El test del happy path verifica las dos cosas — esa es la diferencia entre un test que "pasa" y uno que **prueba** que el dinero fluyó bien.

## Posibles mejoras

### 🔒 Hardening / robustez

- **Validar la aprobación en `listNFT`**: chequear `getApproved(tokenId) == address(this) || isApprovedForAll(seller, address(this))` al listar, para no crear listings "fantasma" que después revientan en la compra.
- **Listings "stale"**: si el seller transfiere el NFT a otro lado después de listar, el listing queda viejo y `buyNFT` revierte. Se podría revalidar el `ownerOf` en `buyNFT` (o limpiar listings inválidos) para un mensaje de error más claro.
- **Custom errors** en vez de `require` con strings: `error NotOwner();` + `if (...) revert NotOwner();` es más barato en gas y permite testear el revert por selector exacto.
- **Owner + fees**: agregar `Ownable` para cobrar una comisión por venta (un % al marketplace) y poder retirarla — el modelo de negocio típico de un marketplace.

### ⛽ Gas

- **Campos redundantes en el `struct Listing`**: `nftAddress` y `tokenId` ya son las claves del mapping, así que guardarlos de nuevo dentro del `Listing` son SSTORE extra al listar. Se podrían omitir y reconstruir desde las claves.

### 🧪 Testing

- **`assertEq` en vez de `assert`**: `assertEq(a, b)` imprime ambos valores cuando falla; `assert` solo dice "falló". Más fácil de debuggear.
- **`vm.expectEmit`**: el contrato emite `NFTListed`, `NFTListingCancelled` y `NFTSold`, pero ningún test verifica que se emitan con los argumentos correctos.
- **Test del caso "comprar sin aprobación"**: hoy el happy path siempre aprueba antes; falta un test que confirme que `buyNFT` revierte si el seller no aprobó.
- **Test de reentrancy explícito**: un `MaliciousBuyer` (contrato) que en su `onERC721Received` o en su `receive()` payable intente volver a llamar `buyNFT` para el mismo NFT. Hoy el `nonReentrant` + el `delete` previo lo bloquean, pero un test dedicado *demuestra* que la defensa funciona y queda como ejercicio didáctico de cómo se ven los ataques.
- **Fuzz tests**: variar `price` y `tokenId` para descubrir edge cases.

### 🛠️ Features

- **`updateListing(price)`**: cambiar el precio de un listing sin tener que cancelar y volver a listar.
- **Pago en ERC-20**: además de ETH, permitir comprar con un token (ej. USDC) vía `SafeERC20`.
- **Script de deploy**: agregar `script/DeployNFTMarketplace.s.sol` para poder deployar a testnet.
