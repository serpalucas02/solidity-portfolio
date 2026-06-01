# 02 — First Token

> Primera crypto del portfolio. Un token ERC-20 estándar implementado heredando de la librería [OpenZeppelin](https://www.openzeppelin.com/contracts), con minteo inicial al deployer.

## Descripción

`Token` es un contrato **ERC-20** que demuestra el patrón más simple de creación de criptomonedas en Ethereum:

- Hereda de [`ERC20`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol) de OpenZeppelin → se obtienen "gratis" `transfer`, `transferFrom`, `approve`, `allowance`, `balanceOf`, `totalSupply`, `decimals`.
- El constructor recibe `name_` y `symbol_` como parámetros → el mismo contrato puede deployarse como distintos tokens.
- Al deployar se mintean **1000 unidades** al `msg.sender` (la wallet que despliega).

No define lógica propia más allá del mint inicial — el objetivo es ver cómo se compone un contrato usando una librería estándar y entender qué se gana usándola.

## Conceptos aplicados

- **Estándar ERC-20**: la "interfaz" universal de tokens fungibles en Ethereum (lo que MetaMask, Uniswap, exchanges, etc. saben leer).
- **Herencia en Solidity** (`is ERC20`): el contrato adopta todas las funciones públicas y el estado del padre.
- **Imports externos**: uso de `@openzeppelin/contracts/token/ERC20/ERC20.sol` resuelto por Remix automáticamente y vía `node_modules` en VS Code (ver [setup local](#setup-local-vs-code)).
- **Constructor con parámetros y pase al padre**: `constructor(...) ERC20(name_, symbol_) { ... }`.
- **Ubicación de datos**: `string memory` para tipos de longitud dinámica en parámetros de función.
- **`_mint` (internal)**: función heredada de OpenZeppelin para emitir tokens. Como es `internal`, solo se la puede llamar desde el contrato hijo, no desde afuera.
- **Convención de 18 decimales**: `1000 * 1e18` → 1000 unidades visibles para el usuario, porque ERC-20 (igual que ETH) usa 18 decimales por defecto.
- **`msg.sender`**: quien dispara la transacción de deploy recibe los tokens.

## Contratos

- [`Token.sol`](contracts/Token.sol) — token ERC-20 con name/symbol parametrizables y mint inicial de 1000 unidades al deployer.

## Cómo probarlo

### Opción A — Remix VM (rápido, sin MetaMask)

1. Abrir [Remix IDE](https://remix.ethereum.org/).
2. Crear `Token.sol` y pegar el contenido de [`contracts/Token.sol`](contracts/Token.sol).
3. Compilar con Solidity `0.8.24` (EVM target: **Cancun**).
4. En "Deploy & Run", elegir **Remix VM** y completar el constructor con `name = "MiToken"`, `symbol = "MTK"`.
5. Deployar y llamar `balanceOf(<tu dirección>)` → debe devolver `1000000000000000000000` (1000 × 10¹⁸).

### Opción B — Sepolia testnet con MetaMask (deploy real)

1. Tener MetaMask conectado a **Sepolia** y un poco de ETH de testnet ([Sepolia faucet](https://sepoliafaucet.com/)).
2. En Remix → Deploy & Run → Environment = **Injected Provider - MetaMask**.
3. Confirmar la transacción de deploy desde MetaMask.
4. Copiar la dirección del contrato deployado.
5. En MetaMask: **Import token** → pegar la dirección → aparecen los 1000 tokens en la wallet. 🎉

### Setup local (VS Code)

Para que VS Code resuelva el `import "@openzeppelin/contracts/..."` y no marque rojo:

```bash
npm install --save-dev @openzeppelin/contracts
```

> Esto solo afecta a la edición/autocompletado en VS Code. El deploy en Remix sigue funcionando igual porque Remix tiene su propio resolver de npm.

## Aprendizajes

- **El estándar ERC-20 no es código, es un contrato social**: solo es un set de funciones con firmas acordadas (EIP-20). Cualquier contrato que las implemente "es" un token ERC-20 y va a funcionar con todo el ecosistema.
- **Por qué heredar de OpenZeppelin en vez de escribir el ERC-20 a mano**: el suyo está auditado, probado en producción contra miles de millones de USD, y evita bugs sutiles (overflow, reentrancy, etc.). En entornos serios **nunca** reimplementás estándares.
- **18 decimales no es una variable**: es una convención. Si poné `1000` en `_mint`, MetaMask lo ve como `0.000000000000001000` MTK. Hay que escalar con `* 1e18` (o usar la variable `decimals()`).
- **Diferencia Remix VM vs Injected Provider**:
  - **Remix VM** → blockchain fake que vive en memoria del navegador. Las cuentas son falsas, los tokens no aparecen en MetaMask.
  - **Injected Provider (MetaMask)** → deploy real a una red (mainnet o testnet) usando la cuenta y firmas de MetaMask.
- **Importar para MetaMask**: cuando deployás un token, MetaMask **no lo detecta solo** — hay que importarlo manualmente con la dirección del contrato.
- **VS Code y los imports de npm**: la extensión de Juan Blanco resuelve imports buscando en `node_modules`. Sin `npm install` local, no encuentra el archivo aunque Remix sí pueda. No es un bug del código, es solo el editor.

## Posibles mejoras

- **Initial supply parametrizable**: recibir `uint256 initialSupply_` por constructor en lugar de hardcodear `1000`.
- **Ownable**: permitir que solo el deployer pueda mintear más tokens después (`Ownable` + función `mint(address, uint256)` con `onlyOwner`).
- **Burnable**: extender de [`ERC20Burnable`](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#ERC20Burnable) para permitir quemar tokens.
- **Permit (EIP-2612)**: usar `ERC20Permit` para que los usuarios puedan aprobar gastos firmando un mensaje en lugar de mandar tx (mejor UX y ahorro de gas).
- **Tests con Hardhat / Foundry**: empezar a versionar tests automatizados en vez de probar a mano en Remix.
