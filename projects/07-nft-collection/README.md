# 07 — NFT Collection (ERC-721)

> Primera colección NFT del portfolio. Un contrato **ERC-721** con metadata off-chain en IPFS, preparado para deployar en **Arbitrum** y aparecer en **OpenSea**. Construido con Foundry + OpenZeppelin.

## Descripción

`NFTCollection` es una colección de tokens no fungibles (NFT) con tope de supply configurable y mint público gratis. La metadata de cada NFT vive **off-chain** en IPFS — el contrato solo guarda un `baseURI` y compone el path completo al JSON de cada token:

```
tokenURI(0)  →  "ipfs://<CID>/0.json"
tokenURI(1)  →  "ipfs://<CID>/1.json"
```

Cada JSON describe el NFT (nombre, descripción, imagen, atributos) y sigue el [estándar de OpenSea](https://docs.opensea.io/docs/metadata-standards).

Esta es la primera vez en el portfolio donde **no todo vive on-chain**: el contrato es pequeño y barato, pero los archivos pesados (imágenes, JSON con muchos atributos) viven en IPFS porque guardar bytes en Ethereum cuesta una fortuna.

## Features implementadas

- ✅ **Tipos de Tokens** — entendimiento de fungibles (ERC-20) vs no fungibles (ERC-721).
- ✅ **Tokens ERC-721** — herencia de `ERC721` de OpenZeppelin.
- ✅ **Colección NFT** — contrato con `totalSupply` configurable y counter de mints.
- ✅ **Safemint** — uso de `_safeMint` (valida que el receptor pueda recibir NFTs).
- ✅ **Token URIs** — override de `tokenURI()` que compone `baseURI + tokenId + ".json"`.
- ✅ **IPFS** — JSONs de metadata creados (`uris/0.json`, `uris/1.json`) siguiendo el estándar OpenSea.
- ✅ **Set URIs** — patrón de **baseURI** (eficiente en gas — un solo string en lugar de uno por token).
- ✅ **Deploy ERC-721** — `DeployNFTCollection.s.sol` con `vm.startBroadcast` y private key de env.
- ✅ **Tests** — suite de Foundry: **10 tests, 100% de coverage** (mint, cap de supply, safe-receiver, `tokenURI`, reverts).

## Estructura del proyecto

```
07-nft-collection/
├── foundry.toml                       ← Solidity 0.8.24, EVM Cancun
├── remappings.txt                     ← @openzeppelin/, forge-std/
├── src/
│   └── NFTCollection.sol              ← contrato ERC-721
├── test/
│   └── NFTCollection.t.sol            ← 10 tests (100% coverage)
├── script/
│   └── DeployNFTCollection.s.sol      ← script de deploy
├── uris/
│   ├── 0.json                         ← metadata del NFT #0 (estándar OpenSea)
│   └── 1.json                         ← metadata del NFT #1
└── lib/
    ├── forge-std/                     ← cheatcodes y Script.sol
    └── openzeppelin-contracts/        ← ERC721, Strings
```

## Contratos

- [`src/NFTCollection.sol`](src/NFTCollection.sol) — colección ERC-721 con tope de supply, mint público y metadata via baseURI.
- [`script/DeployNFTCollection.s.sol`](script/DeployNFTCollection.s.sol) — script de deploy parametrizable por variables de entorno.

## Conceptos aplicados

### ERC-721 (NFT)

- **`tokenId` único por NFT**: a diferencia de ERC-20 (donde 1 token = 1 token, intercambiables), cada NFT tiene un identificador único. `tokenId 0` ≠ `tokenId 1`, son piezas distintas.
- **`_safeMint` vs `_mint`**: `_safeMint` chequea que el receptor (si es contrato) implemente `IERC721Receiver.onERC721Received` antes de transferir. Sin ese chequeo, los NFTs enviados a contratos no preparados se pierden para siempre.
- **`Strings.toString(uint256)`**: util de OZ para convertir un `uint` a su representación decimal en string (necesario para componer el path `0.json`, `1.json`, etc.).
- **`string.concat(...)`**: builtin de Solidity ≥0.8.12 para concatenar strings sin tener que pasarlos por `abi.encodePacked` + cast.
- **Override de `_baseURI()`**: la implementación default en OZ es vacía (`return ""`). Sobreescribirla con tu `baseUri` evita tener que setear el URI manual por cada token.
- **Override de `tokenURI(uint256)`**: la implementación default de OZ devolvería `"<baseURI><tokenId>"` (sin extensión). La sobreescribimos para incluir `".json"` al final.
- **`_requireOwned(tokenId)`**: helper de OZ v5 que revierte si el token no existe — más prolijo que `require(ownerOf(tokenId) != address(0))`.

### Metadata y IPFS

- **Metadata off-chain**: guardar imágenes y JSON on-chain en Ethereum cuesta cientos/miles de dólares por NFT. La práctica universal es subirlos a un sistema **descentralizado** (IPFS) y solo guardar el CID en el contrato.
- **Estructura del JSON** (estándar OpenSea):
  ```json
  {
    "name": "...",
    "description": "...",
    "image": "ipfs://CID_de_la_imagen",
    "attributes": [
      { "trait_type": "Edition", "value": "Genesis" },
      { "display_type": "number", "trait_type": "Token ID", "value": 0 }
    ]
  }
  ```
- **Orden de upload importa**: primero las imágenes a IPFS (genera CIDs), después se editan los JSON con esos CIDs, recién después se suben los JSONs a IPFS (que generan SU propio CID, el que el contrato usa como `baseURI`).
- **Patrón de baseURI**: en vez de hacer `setTokenURI(tokenId, uri)` por cada NFT (un SSTORE por uno = caro), se guarda un solo `baseURI` y se compone dinámicamente. Si el folder de IPFS contiene `0.json`, `1.json`, ..., funciona out-of-the-box.

### Foundry scripting (deploy)

- **Heredar de `forge-std/Script.sol`** y exponer una función `run()` que el CLI ejecuta.
- **`vm.envUint("DEPLOYER_PRIVATE_KEY")`**: lee variables de entorno. En lugar de hardcodear la private key (peligroso), se mete en un `.env` y el script la lee al deploy.
- **`vm.startBroadcast(privateKey)` / `vm.stopBroadcast()`**: todo lo que se ejecute entre medio se firma con esa private key y se manda a la red real (si pasás `--broadcast` al CLI).

## Cómo probarlo

### Build y tests

```bash
cd projects/07-nft-collection
forge build
forge test        # 10 tests
forge coverage    # 100%
```

### Simulación del deploy (dry-run, sin gastar ETH)

```bash
forge script script/DeployNFTCollection.s.sol --rpc-url $ARBITRUM_RPC
```

Esto **simula** el deploy localmente — te dice cuánto gas costaría, qué addresses deployaría, etc. **Sin `--broadcast` no manda nada a la red**.

### Mintear desde Arbiscan

1. Ir al contrato deployado en [Arbiscan](https://sepolia.arbiscan.io/) (o el explorer de la red usada).
2. Tab "Contract" → "Write Contract" → conectar la wallet.
3. Llamar `mint()` (sin args). Confirmar la tx desde MetaMask.
4. Después de que la tx confirma, abrir el NFT en [testnets.opensea.io](https://testnets.opensea.io/) buscando por la address del contrato.

## Aprendizajes

- **ERC-721 vs ERC-20**: la diferencia más importante es la **unicidad** — cada NFT es identificable por `tokenId`. Eso cambia la API: `ownerOf(tokenId)` en lugar de `balanceOf(user)`, `transferFrom(from, to, tokenId)` (no monto), etc.
- **`_safeMint` no es opcional para producción**: si alguien mintea hacia un contrato que no implementa `onERC721Received`, los NFTs quedan **trabados ahí para siempre**. Con `_safeMint` la tx revierte en vez de "perder" el NFT.
- **El contrato es chiquito, la metadata es donde está la "obra"**: el JSON + la imagen en IPFS son lo que el usuario realmente ve. El contrato solo apunta a ellos. Esa separación abarata MUCHO el costo de mintear.
- **`baseURI` ahorra gas vs `_setTokenURI` por token**: con baseURI guardás un solo string. Con `_setTokenURI` por token es un SSTORE (~20k gas) por cada NFT. Multiplicado por 10000 NFTs son 200M de gas extra solo en setup.
- **El orden de upload a IPFS**: imágenes primero, después JSONs (que apuntan a las imágenes), después usar el CID del **folder de JSONs** como `baseURI` en el contrato.
- **Layer 2 importa para NFTs**: en mainnet Ethereum, deployar un ERC-721 puede costar US$50-200 y mintear US$5-20. En Arbitrum es ~10x más barato. Esa diferencia define qué tipo de proyectos son viables.
- **Deploy scripts con `vm.envUint`**: nunca hardcodear private keys. El patrón estándar es `.env` + `vm.envUint` + agregar `.env` al `.gitignore` raíz (que ya lo tenemos).
- **Override de `tokenURI` con `.json` al final**: la implementación default de OZ no incluye la extensión. Si tu folder de IPFS es `<CID>/0.json`, `<CID>/1.json`, vas a tener que sobreescribir para incluir `".json"`. Si no, el JSON nunca se va a fetchear bien.

## Próximos pasos

El contrato está completo, **testeado (100% coverage)** y compilado, con el **script de deploy listo** (`DeployNFTCollection.s.sol`). Como continuación natural: deploy a una **testnet** (Arbitrum Sepolia) y subida de la metadata definitiva a **IPFS**, para enlazar luego el contrato en Arbiscan y la colección en OpenSea.

## Posibles mejoras

### 🐞 Detalles del contrato

- **CEI estricto en `mint`**: incrementar `currentTokenId` **antes** del `_safeMint`. Hoy el orden es `_safeMint → currentTokenId++`, lo cual técnicamente viola CEI. No hay riesgo concreto (OZ's `_safeMint` revierte si el tokenId ya existe), pero el hábito vale.
  ```solidity
  function mint() external {
      require(currentTokenId < totalSupply, "All NFTs have been minted");
      uint256 tokenId = currentTokenId;
      currentTokenId++;                          // Effect primero
      emit NFTMinted(msg.sender, tokenId);
      _safeMint(msg.sender, tokenId);            // Interaction al final
  }
  ```
- **`indexed` en `NFTMinted`**: el parámetro `address userAddress_` debería ser `indexed` para poder filtrar logs por usuario.

### 🔒 Hardening para producción

- **`Ownable`**: agregar para tener funciones admin como `setBaseURI(string)` (útil si la metadata IPFS cambia de pinning service y querés actualizar la ruta) o `withdraw()` si querés cobrar por mintear.
- **Mint pago**: hoy es free. En producción típico es un `payable mint() external payable { require(msg.value >= price); ... }`.
- **Mint cap por wallet**: hoy una wallet puede mintear toda la colección. Para evitarlo: `mapping(address => uint256) public mintedPerUser` + check.
- **Allowlist / Merkle**: si querés gatear el mint a una lista, usar Merkle proofs (estándar) para no tener que guardar la lista on-chain.
- **`indexed` en eventos** (mencionado arriba).
- **Custom errors** en vez de require strings.

### 🖼️ Producto

- **Subir las imágenes reales a IPFS** y completar los CIDs en los JSONs de metadata.
- **`contractURI()`**: agregar para que OpenSea muestre metadata de la **colección completa** (nombre, descripción, banner, link). Es un endpoint opcional pero mejora mucho la presentación.
