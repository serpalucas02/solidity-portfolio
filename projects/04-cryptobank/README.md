# 04 — Cryptobank

> Primer proyecto del nivel intermedio. Un **banco descentralizado** donde los usuarios depositan y retiran ETH, con un límite máximo de balance por cuenta gestionado por un admin.

## Descripción

`CryptoBank` simula un banco simple en Ethereum:

- Cualquier wallet puede depositar ETH llamando a `depositEther()` (función `payable`).
- El contrato mantiene un **balance por usuario** en un `mapping(address => uint256)`.
- Cada usuario tiene un **límite máximo de balance** (`maxBalance`) — un depósito que lo exceda revierte.
- Los usuarios pueden retirar su balance en cualquier momento con `withdrawEther(amount)`.
- Un `admin` (seteado en el constructor) puede modificar el `maxBalance` con `modifyMaxBalance()`.

A diferencia del `PayableContractV2` del módulo anterior, este contrato:
- **No es drainable**: cada usuario solo puede retirar su propio balance, no el de otros.
- **Implementa el patrón CEI** (Checks-Effects-Interactions) para prevenir reentrancy.
- **Maneja la lógica completa** de un banco (depósito, retiro, tope, admin).

## Features implementadas

- ✅ **Crea tu banco crypto** — estructura base del contrato (variables, eventos, modifier, constructor).
- ✅ **Deposit Ether** — `depositEther()` payable, valida `maxBalance`.
- ✅ **Withdraw Ether** — `withdrawEther(amount)` con CEI pattern + `.call{value:}`.
- ✅ **Max Balance** — admin puede modificarlo con `modifyMaxBalance()`; `depositEther` lo respeta.
- ✅ **Deploy del banco** — en Remix VM con constructor params.
- ✅ **Test del banco** — flujos probados manualmente en Remix.

## Conceptos aplicados

- **`mapping(address => uint256)`** para trackear balance per-user.
- **Función `payable`** para recibir ETH (`depositEther`).
- **Patrón CEI** (Checks → Effects → Interactions) en `withdrawEther` para prevenir reentrancy.
- **Transferencia con `.call{value:}("")`** + check de `success` (patrón moderno recomendado).
- **`modifier`** reusable (`onlyAdmin`) para restringir funciones a una sola dirección.
- **`require` con mensaje** para validar precondiciones (cap, monto a retirar).
- **Eventos** (`EtherDeposit`, `EtherWithdraw`) para tracking off-chain.
- **Convención de naming**: sufijo `_` en parámetros para evitar shadow.

## Contratos

- [`CryptoBank.sol`](contracts/CryptoBank.sol) — banco descentralizado con depósito, retiro, max balance y admin.

## Cómo probarlo

### En Remix

1. Abrir [Remix IDE](https://remix.ethereum.org/).
2. Crear `CryptoBank.sol` y pegar el contenido.
3. Compilar con Solidity `0.8.24` (EVM target: **Cancun**).
4. Desplegar en **Remix VM** con los argumentos del constructor:
   - `maxBalance_` = `1000000000000000000` (1 ETH expresado en wei).
   - `admin_` = una de las cuentas de Remix VM (la primera, p. ej. `0x5B38...`).

### Flujos a probar

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Depositar 0.5 ETH con otra cuenta (no admin) | `userBalance` de esa cuenta = `5e17` |
| 2 | Depositar 0.6 ETH más con la misma cuenta | ⛔ revierte: "Max balance reached" (0.5 + 0.6 > 1) |
| 3 | Retirar 0.1 ETH (`withdrawEther(1e17)`) | Balance baja a `4e17`; el ETH vuelve a la wallet |
| 4 | Retirar 10 ETH (más del saldo) | ⛔ revierte: "Not enough ether" |
| 5 | Desde la cuenta admin: `modifyMaxBalance(2e18)` | `maxBalance` ahora es 2 ETH; deposit acepta hasta ese monto |
| 6 | Desde otra cuenta: `modifyMaxBalance(...)` | ⛔ revierte: "Not allowed" |

## Aprendizajes

- **`mapping` para state per-user** era el reflejo que faltaba en `PayableContractV2`. Sin el mapping, el contrato queda drainable porque no hay forma de saber cuánto le corresponde a cada usuario.
- **Patrón CEI** (Checks → Effects → Interactions) es la regla anti-reentrancy más simple: hacer los cambios de estado (`userBalance[msg.sender] -= amount_`) **antes** de la interacción externa (`.call{value:}`). Así, si el receptor intenta reentrar al contrato, el balance ya bajó y el segundo retiro falla.
- **`.call{value:}("")` + check de `success`** es el patrón moderno para enviar ETH. `transfer`/`send` quedaron deprecados por el límite arbitrario de 2300 gas.
- **`msg.value`** ya está disponible automáticamente en funciones `payable` — no hay que pasarlo como parámetro, es la cantidad de ETH enviada en la tx.
- **El check de `maxBalance` se hace sobre `balance acumulado + msg.value`**, no solo `msg.value`. Si no, depósitos chicos múltiples se zafan del tope.
- **`userBalance` vs `address(this).balance`**: el primero es el tracking interno (suma de los depósitos de cada usuario), el segundo es el balance real del contrato on-chain. Pueden divergir si alguien fuerza ETH al contrato sin pasar por `depositEther` (p. ej. `selfdestruct` de otro contrato).
- **Modifier reusable**: separar `onlyAdmin` como modifier (en vez de inlinearlo en `modifyMaxBalance`) permite reutilizarlo si en el futuro hay más funciones de admin.

## Posibles mejoras

- **`indexed` en eventos**: marcar `address user_` como `indexed` permite filtrar logs por usuario en herramientas off-chain (frontends, indexers, The Graph).
  ```solidity
  event EtherDeposit(address indexed user_, uint256 etherAmount_);
  event EtherWithdraw(address indexed user_, uint256 etherAmount_);
  ```
- **Custom errors** en vez de `require` con strings — más baratos en gas y con contexto tipado:
  ```solidity
  error MaxBalanceReached(uint256 balance, uint256 max);
  error InsufficientBalance(uint256 requested, uint256 available);
  error NotAdmin(address sender);
  ```
- **NatSpec docs** en las funciones `external` (`@notice`, `@param`).
- **Transferencia de admin**: hoy el admin queda fijo desde el constructor. Una mejora típica es agregar `transferAdmin(address newAdmin_) external onlyAdmin`. Mejor todavía: heredar de [`Ownable`](https://docs.openzeppelin.com/contracts/5.x/api/access#Ownable) de OpenZeppelin.
- **`receive()` para ETH directo**: si alguien envía ETH al contrato sin llamar `depositEther` (transfer directo desde una wallet), el ETH queda atrapado sin ser contabilizado. Opciones:
  - Agregar `receive() external payable` que llame internamente a la lógica de deposit.
  - O dejar `receive()` que revierta, para forzar el uso explícito de `depositEther`.
- **Validación de `admin_ != address(0)`** en el constructor.
- **Tests automatizados con Foundry** — justo el próximo módulo. Pasa de probar a mano en Remix a un suite de tests reproducibles.
