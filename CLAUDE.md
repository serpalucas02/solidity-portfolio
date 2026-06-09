# CLAUDE.md — Contexto para Claude Code

> Este archivo lo lee automáticamente cualquier instancia de Claude Code que abra este repo. Contiene el contexto de cómo trabajamos en este portfolio para que la colaboración sea consistente entre máquinas/sesiones.

## Sobre el usuario (Lucas)

- **Lucas** está cursando un curso de **desarrollo de smart contracts en Solidity** y usa este repo como **portfolio personal** de cara a recruiters.
- **Idioma**: español rioplatense (usa "dale", "vos", "che", "joya", "bárbaro"). Respondé siempre en español salvo que pida lo contrario.
- **Nivel**: estudiante / en formación. Las explicaciones tienen que ir con el **por qué** del concepto, no solo el qué. Usar analogías simples cuando sea posible.
- **Entorno**: Lucas **alterna entre dos máquinas** según el día:
  - 🪟 **Windows 10** + VSCode. Shell por defecto = PowerShell, pero también tiene Git Bash instalado.
  - 🍎 **macOS** + VSCode. Shell = zsh. Foundry en `~/.foundry/bin/`.
  - **IMPORTANTE**: antes de aplicar cualquier gotcha o comando dependiente del SO, fijate en qué plataforma estás corriendo (el entorno de la sesión lo indica) y usá la sección que corresponda. Los "Gotchas de Windows + PowerShell" de más abajo **NO aplican en macOS**.

## Estado del portfolio

| # | Proyecto | Tipo | Estado |
|---|----------|------|--------|
| 00 | Template | Estructura base para arrancar un proyecto Remix | Activo |
| 01 | First Contract — Calculadora | Práctica Remix (variables, modifiers, events) | ✅ Cerrado |
| 02 | First Token — ERC-20 | OpenZeppelin via npm + Remix | ✅ Cerrado |
| 03 | Smart Contract Systems | Cheat-sheet multi-contrato (msg.sender, errors, ether) | ✅ Cerrado |
| 04 | Cryptobank | Banco descentralizado con CEI (Remix) | ✅ Cerrado |
| 05 | Foundry · Calculadora | Primer Foundry — 11 tests (unit + fuzz) | ✅ Cerrado |
| 06 | Staking App | ERC-20 + Staking con rewards ETH, SafeERC20, 14 tests | ✅ Cerrado |
| 07 | NFT Collection | ERC-721 con IPFS metadata + deploy script Arbitrum | ✅ Código completo, ⏸ deploy real pendiente |
| 08 | NFT Marketplace | Marketplace ERC-721 sin custodia (list/cancel/buy en ETH), CEI + ReentrancyGuard, 9 tests | ✅ Cerrado |
| 09 | Swapping App | Wrapper de Uniswap V2 para swap de tokens, fork testing contra Arbitrum (USDC ↔ DAI) | ✅ Cerrado |
| 10 | Liquidity Pools | Extensión del wrapper con add/remove liquidity + combo "swap + add", fork de Arbitrum, 4 tests | ✅ Cerrado |
| 11 | Presale | Preventa multi-fase con USDC/DAI/ETH + Chainlink Price Feed, claim pattern, blacklist, emergency withdraws, 24 tests | ✅ Cerrado |
| 12 | Reentrancy Attack | PoC de seguridad: `SimpleBank` vulnerable (CEI roto) + `Attacker` que lo drena vía reentrancy, 2 tests | ✅ Cerrado |
| 13 | ABI Encoding & Decoding | Codificación/hashing de parámetros para estructuras DeFi (pool IDs, posiciones, órdenes, swap data): `abi.encode` vs `abi.encodePacked`, colisiones y `keccak256`, 18 tests | ✅ Cerrado |
| 14 | Yield Farming | Staking con rewards (patrón `accRewardPerShare` + `rewardDebt`), mock tokens ERC-20, create pool / stake / unstake / claim. Trae `ABIEncoder.sol` del módulo 13 como base | 🚧 En curso |

La tabla en el [README raíz](README.md) es la fuente de verdad para los proyectos completos.

## Workflow acordado

**Rol de Claude**: tutor + scaffolder, **NO** copiloto que tipea por él.

1. **Arranque de proyecto nuevo**: cuando Lucas anuncia un módulo nuevo, Claude crea la base:
   - Para proyectos Remix (01-04): copiar `00-template/` a `projects/NN-nombre/`, contrato vacío con secciones comentadas, README esqueleto.
   - Para proyectos Foundry (05+): `forge init projects/NN-nombre --use-parent-git --empty`, configurar `foundry.toml` con la convención del curso, generar `remappings.txt`, eliminar el `.github/` que viene por default, escribir un README con checklist del módulo.
2. **Desarrollo**: Lucas escribe el código siguiendo el curso. **Claude NO toca el código** salvo que Lucas lo autorice explícitamente para un cambio puntual.
3. **Revisión iterativa**: cuando Lucas pide revisión, Claude:
   - Identifica conceptos a reforzar y los explica con analogías sencillas.
   - Marca bugs funcionales y de seguridad (ver "Cuándo flag y cuándo no" abajo).
   - Ayuda a completar las secciones del README a medida que avanza el módulo.
4. **Cierre del proyecto**: cuando Lucas termina un módulo, Claude:
   - Reviewa el código y los tests (corre `forge test` si aplica).
   - Reescribe el README del proyecto con descripción, conceptos aplicados, cómo probar, aprendizajes, posibles mejoras.
   - Agrega una fila al [README raíz](README.md) marcando el estado.
5. **Commits a GitHub**: solo cuando Lucas lo pide explícitamente. Usar commits temáticos (un commit por proyecto, no commits monolíticos), con mensajes en inglés y co-author de Claude. Mensajes en formato:
   ```
   feat(NN): nombre breve del proyecto
   
   Descripción multi-línea de qué hace.
   
   Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
   ```

## Convenciones técnicas del curso

### Licencia SPDX

- **`LGPL-3.0-only`** para proyectos basados en **Remix** (módulos 01-04).
- **`MIT`** para proyectos basados en **Foundry** (módulo 05 en adelante).
- Si Lucas arranca un proyecto nuevo y la herramienta no está obvia, preguntar antes de definir la licencia.

### Solidity y compilador

- `pragma solidity 0.8.24;` (pinned, sin caret `^`).
- EVM target: `cancun` (matchea el default de `solc 0.8.24`).

### Naming

- **Carpetas de proyectos**: `NN-nombre-en-kebab-case` (dos dígitos, en inglés).
- **Contratos**: `PascalCase` (ej. `Calculadora`, `CryptoBank`, `NFTCollection`).
- **Archivo `.sol`**: matchea el nombre del contrato principal (ej. `CryptoBank.sol` para `contract CryptoBank`).
- **Parámetros y locales que pueden chocar con state vars**: sufijo guión bajo. Ej. `function deposit(uint256 amount_) ... { balance += amount_; }`. Esta es **convención del curso**, no del Solidity Style Guide oficial — pero la mantenemos para consistencia.

### Estructura por herramienta

**Proyectos Remix** (01-04):
```
NN-nombre/
├── README.md
└── contracts/
    └── Contract.sol
```

**Proyectos Foundry** (05+):
```
NN-nombre/
├── foundry.toml
├── remappings.txt
├── src/
├── test/         (archivos .t.sol)
├── script/       (archivos .s.sol)
└── lib/          (submódulos: forge-std, openzeppelin-contracts)
```

## Tooling

- **Foundry** (primario desde el proyecto 05): instalado en `~/.foundry/bin/`. El binario `forge` puede no estar en el PATH de la sesión Bash de Claude Code — si pasa, usar la ruta completa `~/.foundry/bin/forge`.
- **OpenZeppelin**: se instala por proyecto con `forge install OpenZeppelin/openzeppelin-contracts` (queda como submódulo en `lib/`).
- **VSCode**: extensión **Juan Blanco (`JuanBlanco.solidity`)**, NO Nomic Foundation. Juan Blanco tiene mejor soporte de Foundry (lee `remappings.txt`, autodetecta `lib/`). Si en algún momento se pasa a Hardhat, ahí sí migrar a Nomic Foundation.
- **Settings de VSCode** (`.vscode/settings.json`): formato automático al guardar con Juan Blanco. El archivo está en el repo (excepción en `.gitignore` para que se versione).

## Gotchas del entorno (Windows + PowerShell)

- **`forge remappings > remappings.txt` en PowerShell rompe el archivo**: el redireccionamiento `>` de PowerShell escribe en UTF-16 con BOM. Foundry y los editores esperan UTF-8 → no parsean el archivo y tiran "import not found". **Solución**: correr ese comando desde **Git Bash**, o usar `forge remappings | Out-File -Encoding utf8 remappings.txt` en PowerShell. Siempre que se instale una dependencia nueva, regenerar.
- **Regenerar `remappings.txt`**: después de cualquier `forge install`, regenerar y recargar VSCode (`Ctrl+Shift+P` → `Developer: Reload Window`).
- **Tools de Foundry en sesión Bash de Claude Code**: el `~/.bashrc` no se carga; el binario está en `~/.foundry/bin/forge`. Usar la ruta completa o `cd` al proyecto y armar el comando.

## Cuándo flag y cuándo no

### Siempre flag (bugs funcionales)

- Typos en código (`Substraction` → `Subtraction`, etc.).
- Uso incorrecto de variables (ej. emitir state var en vez de la local recién calculada).
- Events declarados pero no emitidos.
- Tests que pasan por casualidad (ej. fuzz tests sin asserts).
- Inconsistencias contrato vs test (ej. contrato devuelve 0 pero test espera revert).

### Flag UNA vez en "Posibles mejoras", sin insistir

Para código **didáctico del curso** (foco en demostrar un concepto, no caso real):

- Falta de access control en mocks/faucets.
- `require` con strings en lugar de custom errors.
- Falta de `indexed` en eventos.
- Falta de NatSpec.
- CEI roto pero sin riesgo concreto en el contexto.

Si Lucas levanta el flag y decide arreglarlo, dale. Si no, dejar pasar.

### Proponer como DEFAULT (no como afterthought)

Para patrones "production-quality" que vale la pena internalizar desde el principio:

- `SafeERC20` para `transfer`/`transferFrom` (Lucas pidió explícitamente que esto sea default).
- `_safeMint` en lugar de `_mint` en ERC-721.
- `ReentrancyGuard` cuando hay interacciones externas con value.
- CEI estricto siempre.

## Pendientes

- **Deploy real de la NFT Collection (proyecto 07) a Arbitrum Sepolia**: el código está completo y compilado, falta ejecutar el deploy en una red real. Lucas no tenía ETH en wallet al cerrar el módulo y las faucets pedían balance mínimo. Pasos cuando consiga test ETH:
  1. Subir las imágenes y los JSONs (`uris/0.json`, `uris/1.json`) a IPFS (Pinata, NFT.Storage).
  2. Actualizar el `baseURI` en `DeployNFTCollection.s.sol` con el CID real.
  3. Crear `.env` con `DEPLOYER_PRIVATE_KEY`, `ARBITRUM_RPC`, `ARBISCAN_API_KEY`.
  4. Correr `forge script script/DeployNFTCollection.s.sol --rpc-url $ARBITRUM_RPC --broadcast --verify`.
  5. Actualizar el [README del proyecto 07](projects/07-nft-collection/README.md) con address del contrato, link a Arbiscan, link a OpenSea, screenshots.

## Para el otro Claude

Si estás picando este repo desde otra máquina:

- **Lee este archivo + el [README raíz](README.md) + el README del proyecto en el que esté trabajando Lucas** antes de responder.
- **Mantené el workflow**: scaffolding mínimo, no toques código sin permiso explícito, revisá con foco en aprendizaje.
- **Si descubrís algo nuevo durante la sesión** (un patrón que Lucas prefiere, un quirk del entorno, una decisión de diseño), **actualizá este archivo** y commiteá el cambio. Es la única forma de que el contexto persista entre máquinas.
- **Si tenés dudas de qué hacer**, pregúntale a Lucas. El curso va por orden cronológico, así que el "próximo paso" suele estar claro desde el contexto, pero el camino exacto lo define él.
