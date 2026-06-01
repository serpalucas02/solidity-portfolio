# 06 — Staking App

> **Aplicación de staking** con dos contratos: un ERC-20 (`StakingToken`) que los usuarios depositan, y un `StakingApp` que custodia los depósitos y paga **rewards en ETH** proporcionales al tiempo stakeado. Construido con Foundry + OpenZeppelin.

## Descripción

Sistema de staking de monto fijo:

- Cada usuario puede stakear exactamente `fixedStakingAmount` tokens del `StakingToken`.
- Solo se permite **un stake activo por usuario**. Para volver a stakear hay que retirar primero.
- Cuando pasa el `stakingPeriod`, el usuario puede llamar `claimRewards` y recibe `rewardPerPeriod` **ETH** (no más tokens — los rewards son en moneda nativa).
- El owner (vía `Ownable` de OpenZeppelin) puede:
  - Cambiar el `stakingPeriod` con `changeStakingPeriod`.
  - **Financiar el pot de ETH** mandando ether al contrato (`receive` gated con `onlyOwner`).

**Insight clave**: el contrato maneja **dos activos distintos**:
- 🪙 **Staking token (ERC-20)**: lo que el usuario *deposita*.
- 💎 **ETH (nativo)**: lo que el usuario *recibe como reward*.

Los rewards salen del pot de ETH pre-financiado por el owner — los tokens stakeados no se "convierten" en nada, simplemente se devuelven en el `withdraw`.

## Features implementadas

- ✅ **Staking App** — overview y diseño con dos contratos separados.
- ✅ **Crea tus Smart Contracts de Staking** — `StakingApp.sol` + `StakingToken.sol`.
- ✅ **Librerías de OpenZeppelin** — instaladas con `forge install` como submódulo.
- ✅ **Ownable** — heredado de OZ, owner pasado por constructor.
- ✅ **Staking Token** — ERC-20 con mint público (faucet) heredando de OZ.
- ✅ **Staking Period** — `stakingPeriod` configurable, validado en `claimRewards`.
- ✅ **Deposit Tokens** — `deposit()` con `safeTransferFrom`, monto fijo, un stake por user.
- ✅ **Withdraw Tokens** — `withdraw()` devuelve los tokens stakeados al user.
- ✅ **CEI Pattern** — aplicado en `withdraw` y `claimRewards` (effect antes del call externo).
- ✅ **Claim Rewards** — paga ETH del pot interno, valida tiempo transcurrido.
- ✅ **Feed Contract** — `receive() external payable onlyOwner` es el "feed" de ETH al pot.
- ✅ **Testing Staking 1 / 2 / 3 / 4 / 5** — 14 tests cubriendo deploys, admin, deposit, withdraw, claim y edge cases.

**Estado final**: 14/14 tests pasando ✅

## Estructura del proyecto

```
06-staking-app/
├── foundry.toml                    ← Solidity 0.8.24, EVM Cancun
├── remappings.txt                  ← forge-std/, @openzeppelin/contracts/
├── src/
│   ├── StakingApp.sol              ← contrato principal
│   └── StakingToken.sol            ← ERC-20 de prueba con mint público
├── test/
│   ├── StakingAppTest.t.sol        ← 13 tests
│   └── StakingTokenTest.t.sol      ← 1 test
└── lib/
    ├── forge-std/                  ← cheatcodes y asserts
    └── openzeppelin-contracts/     ← Ownable, ERC20, IERC20, SafeERC20
```

## Contratos

- [`src/StakingApp.sol`](src/StakingApp.sol) — staking de monto fijo con rewards en ETH; hereda `Ownable`, usa `SafeERC20`.
- [`src/StakingToken.sol`](src/StakingToken.sol) — ERC-20 con `mint(uint256)` público (faucet de tests).

## Conceptos aplicados

### De Solidity / OpenZeppelin

- **`Ownable` (OpenZeppelin)** — control de acceso para owner; pasado por constructor.
- **`SafeERC20`** — wrapper sobre `IERC20` que revierte si `transfer`/`transferFrom` devuelve `false` (importante para tokens tipo USDT).
- **`using SafeERC20 for IERC20`** — sintaxis para "pegarle" métodos `safeTransfer`/`safeTransferFrom` al tipo.
- **Approve + transferFrom pattern (EIP-20)** — antes de que el contrato pueda mover tokens del usuario, el usuario tiene que llamar `approve(contrato, monto)`. El contrato después usa `transferFrom` para chupárselos.
- **`receive() external payable onlyOwner`** — función especial que se dispara cuando llega ETH al contrato sin data. Aceptar ETH solo del owner es una forma de gatear quién financia el pot de rewards.
- **CEI pattern (Checks → Effects → Interactions)** — patrón anti-reentrancy: hacer todas las validaciones, después los cambios de estado, y recién al final las llamadas externas.
- **`block.timestamp`** — marca de tiempo del bloque actual; se usa para trackear cuándo arrancó el stake.

### De Foundry / forge-std

- **`vm.prank` vs `vm.startPrank`**: `vm.prank` aplica a UN solo call; `vm.startPrank` persiste hasta `vm.stopPrank`. **Cuidado con los getters**: leer un `public` var también consume el `vm.prank`.
- **`vm.deal(addr, amount)`** — setea el balance de ETH de una address (no transfiere, lo *crea*).
- **`vm.warp(timestamp)`** — adelanta el reloj del EVM al timestamp dado. Esencial para testear lógicas con tiempo.
- **`vm.expectRevert("mensaje")`** — la siguiente llamada DEBE revertir con ese mensaje exacto, si no falla el test.
- **`address.balance`** — atajo para leer el balance de ETH de una address (no hace falta `address(addr).balance` si ya es `address`).

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/06-staking-app`).

```bash
# Compilar
forge build

# Correr toda la suite
forge test

# Con traces detallados
forge test -vvv

# Un test específico
forge test --match-test testCanClaimRewardsAfterElapsedTime

# Reporte de gas
forge test --gas-report
```

### Flujo end-to-end (lo que probás en los tests)

```
1. Owner deploya StakingToken y StakingApp.
2. Owner manda ETH al StakingApp (financia el pot de rewards).
3. Usuario:
   3.1. Mintea staking tokens (faucet público).
   3.2. Aprueba al StakingApp a mover sus tokens.
   3.3. Llama deposit() → el StakingApp chupa los tokens vía transferFrom.
4. Pasa el tiempo (vm.warp en tests, esperar en realidad).
5. Usuario llama claimRewards() → recibe ETH del pot.
6. Usuario llama withdraw() → recupera sus tokens stakeados.
```

## Aprendizajes

- **Dos activos en una misma app**: separar mentalmente "lo que se deposita" de "lo que se recibe como reward" es clave para entender (y testear) este tipo de sistemas. Acá los tokens son ERC-20 pero los rewards son ETH; en otros sistemas pueden ser el mismo token, dos ERC-20 distintos, NFTs, etc.
- **Approve + transferFrom es un baile de dos pasos**: el usuario primero firma `approve(contrato, X)` y recién después puede llamar `deposit`. Es el "consentimiento explícito" del modelo ERC-20 — sin approve, el contrato no puede tocar tus tokens. **Si te olvidás del approve, el deposit revierte sin razón obvia**.
- **`SafeERC20` desde el principio**: aprendí que `transfer`/`transferFrom` siempre devolvieron `bool`, pero algunos tokens (USDT, BNB) NO revierten en fallo — devuelven `false`. Si no chequeás el bool, el bug es silencioso. `SafeERC20` te lo resuelve.
- **`vm.prank` se "consume"**: aplica al **próximo call**, incluyendo getters como `stakingApp.stakingPeriod()`. Para múltiples calls bajo la misma identidad, `vm.startPrank` + `vm.stopPrank`.
- **`vm.warp` para testear lógica temporal**: en lugar de esperar 1 día real, le decís al EVM "saltá al timestamp X". Tests rápidos, deterministas, reproducibles.
- **CEI previene reentrancy "gratis"**: en `claimRewards`, actualizar `elapsePeriod = block.timestamp` *antes* del `call{value:}` significa que si el receptor reentra, la siguiente verificación `elapsed >= stakingPeriod` da `0 >= stakingPeriod` y revierte. No hace falta `ReentrancyGuard` para este caso.
- **Dependencia del pot de ETH**: un buen test de `claimRewards` no es solo "que pague" — es **"que falle clarito si el contrato no tiene ETH"** (lo que prueba [`testCanNotClaimRewardsAfterElapsedTime`](test/StakingAppTest.t.sol#L200)). Estados borde como este son donde se esconden los bugs reales.

## Posibles mejoras

### 🐞 Bugs/inconsistencias menores

- **Evento `RewardsClaimed` declarado pero no emitido**: en `claimRewards` falta `emit RewardsClaimed(msg.sender, rewardPerPeriod);`. Lo mismo aplicaría para revisar que `Withdrawn`, `Deposited` y `StakingPeriodChanged` estén bien emitidos en todos los flujos.

### 🔒 Hardening para producción

- **`StakingToken.mint` es público sin restricción**: cualquiera puede mintearse infinitos tokens. Es a propósito (faucet para tests) — en producción sería `onlyOwner` o eliminado completamente y reemplazado por mint inicial fijo en el constructor.
- **Custom errors** en vez de `require` con strings: más baratos en gas y descriptivos. `error AlreadyStaked();` + `if (...) revert AlreadyStaked();`.
- **`indexed` en eventos**: el parámetro `address user_` debería ser `indexed` para poder filtrar logs por usuario en herramientas off-chain.
- **NatSpec docs** en funciones `external` (`@notice`, `@param`).
- **Validaciones del constructor**: `require(stakingToken_ != address(0))`, `require(stakingPeriod_ > 0)`, etc.
- **Función para que el owner retire ETH sobrante** del pot, por si quiere recuperar fondos no usados.

### 🧪 Testing

- **Fuzz tests**: variar `amount_`, `time elapsed`, `rewardPerPeriod` para encontrar edge cases.
- **`vm.expectEmit`**: verificar que los eventos se emiten con los argumentos correctos (especialmente útil para detectar el bug del `RewardsClaimed` no emitido).
- **Invariant testing**: definir invariantes globales (ej. "el balance del contrato siempre cubre el balance de tokens stakeados") y dejar que Foundry los pruebe con secuencias random.
- **Test del flujo completo**: un solo test que haga deposit → wait → claim → withdraw end-to-end y verifique balances finales.
