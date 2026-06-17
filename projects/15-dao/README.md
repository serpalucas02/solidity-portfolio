# 15 — DAO / Governance

> Gobernanza on-chain **hecha a mano** (sin el `Governor` de OpenZeppelin): un token de governance, un `DAO` que maneja el ciclo de vida de las propuestas (crear → votar → ejecutar / cancelar) y un `DAOTreasury` separado que custodia los fondos y solo obedece al DAO. Construido con Foundry + OpenZeppelin (ERC20 / Ownable / SafeERC20).

## Descripción

El sistema son **tres contratos** con responsabilidades separadas:

1. **`DAOGovernanceToken`** — un ERC-20 cuyo `balanceOf` **es** el poder de voto (`getVotingPower(x) == balanceOf(x)`). Tiene `mint`/`burn` (owner) y una "delegación" propia.
2. **`DAO`** — el cerebro. Cualquiera con tokens por encima del `proposalThreshold` puede **crear una propuesta** (pagar `amount` de un `token` a un `recipient`). Los holders **votan** (a favor / en contra, con peso = su balance) durante el `votingPeriod`. Pasado ese plazo, si hay **quórum** y **mayoría**, cualquiera puede **ejecutarla**.
3. **`DAOTreasury`** — la caja. Guarda ETH y ERC-20s, y **solo el DAO** puede aprobar y gastar fondos. Tiene un `emergencyWithdraw` para el owner.

**Insight de diseño — separación de poderes**: el DAO **decide** pero no toca la plata; el treasury **tiene** la plata pero no decide nada (solo ejecuta lo que el DAO le ordena, validando `msg.sender == address(dao)`). Esa separación es un patrón clásico: si el contrato de lógica tiene un bug, los fondos están en otro contrato con una superficie de ataque mínima.

> ⚠️ **Es una implementación didáctica.** A diferencia de un `Governor` + `ERC20Votes` + `TimelockController` reales, este DAO mide el voto con el **balance en vivo** (sin snapshot) y no tiene timelock. Eso abre un agujero conocido que **el propio test demuestra** (ver Aprendizajes).

## Features implementadas

- ✅ **DAOGovernanceToken** — ERC-20 (`mint`/`burn` onlyOwner) con `getVotingPower == balanceOf`.
- ✅ **Delegación** — `delegateVotingPower` / `undelegateVotingPower` (ojo: acá "delegar" **transfiere** los tokens al delegado).
- ✅ **createProposal** — gated por `proposalThreshold`, valida descripción / monto / recipient.
- ✅ **vote** — a favor / en contra, peso = `balanceOf`, un voto por address (`hasVoted`).
- ✅ **cancelProposal** — solo el proposer o el owner.
- ✅ **executeProposal** — chequea fin de votación + **quórum** + **mayoría**, y ordena el pago al treasury.
- ✅ **updateConfiguration / setTreasury** — administración (onlyOwner).
- ✅ **proposalPassed** — getter del estado final de una propuesta.
- ✅ **DAOTreasury** — `fundTreasury` (ETH) / `fundTreasuryWithToken` / `receive`, `approveProposal` + `spendFunds` (solo DAO, ETH y ERC-20), `emergencyWithdraw` (onlyOwner).
- ✅ **Testing exhaustivo** — 83 tests cubriendo happy paths, todos los reverts alcanzables y el caveat de seguridad.

**Estado final**: 83/83 tests pasando ✅ · **100%** líneas / statements / funciones · **97.4%** branches (el resto son guardas inalcanzables, ver abajo).

## Estructura del proyecto

```
15-dao/
├── foundry.toml                       ← Solidity 0.8.24, EVM Cancun
├── remappings.txt                     ← forge-std/, @openzeppelin/contracts/
├── src/
│   ├── DAO.sol                        ← lógica de governance (propuestas, voto, ejecución)
│   ├── DAOGovernanceToken.sol         ← ERC-20 con voting power = balanceOf
│   ├── DAOTreasury.sol                ← custodia de fondos, obedece solo al DAO
│   └── interfaces/
│       └── IDAOTreasury.sol           ← interfaz que el DAO usa para hablarle al treasury
├── test/
│   ├── DAO.t.sol                      ← 38 tests
│   ├── DAOGovernanceToken.t.sol       ← 16 tests
│   └── DAOTreasury.t.sol              ← 29 tests
└── lib/
    ├── forge-std/
    └── openzeppelin-contracts/        ← ERC20, Ownable, SafeERC20
```

## Contratos y tests

- [`src/DAO.sol`](src/DAO.sol) — ciclo de vida de propuestas (create / vote / cancel / execute) + config.
- [`src/DAOGovernanceToken.sol`](src/DAOGovernanceToken.sol) — token de governance, voting power = balance.
- [`src/DAOTreasury.sol`](src/DAOTreasury.sol) — tesoro custodiado, gasto gated por el DAO.
- [`src/interfaces/IDAOTreasury.sol`](src/interfaces/IDAOTreasury.sol) — interfaz DAO → Treasury.
- [`test/DAO.t.sol`](test/DAO.t.sol) · [`test/DAOGovernanceToken.t.sol`](test/DAOGovernanceToken.t.sol) · [`test/DAOTreasury.t.sol`](test/DAOTreasury.t.sol)

## Conceptos aplicados

### De governance

- **Ciclo de vida de una propuesta**: `createProposal → vote → (espera votingPeriod) → executeProposal`, con `cancelProposal` como salida.
- **Quórum vs mayoría**: dos condiciones distintas para ejecutar. **Quórum** = participación mínima (`forVotes + againstVotes >= quorumVotes`); **mayoría** = que el "a favor" gane (`forVotes > againstVotes`). Una propuesta puede tener mayoría pero no quórum (no participó suficiente gente) y no pasa.
- **Voting power = `balanceOf`**: simple pero peligroso (ver Aprendizajes). En governance real se usa `ERC20Votes` con **checkpoints** fijados al bloque de creación de la propuesta.
- **Separación de poderes (DAO ↔ Treasury)**: el treasury valida `msg.sender == address(dao)` en cada gasto. La lógica y los fondos viven en contratos distintos.

### De Solidity / OpenZeppelin

- **`Ownable`** para administración (config del DAO, emergency del treasury).
- **`SafeERC20`** (`safeTransfer` / `safeTransferFrom`) para mover tokens en el treasury.
- **`call{value:}` + chequeo de `success`** para enviar ETH.
- **Dependencia circular** treasury ↔ DAO resuelta con un setter (`setDAO`/`setTreasury`) post-deploy.
- **`struct` con mappings anidados** (`hasVoted`, `hasVotedFor`) dentro de `Proposal`.

### De Foundry / forge-std

- **`vm.prank` / `vm.startPrank`** — simular distintos votantes y al "DAO" (en los tests del treasury, el propio test actúa como DAO).
- **`vm.warp`** — saltar el `votingPeriod` para poder ejecutar.
- **`vm.deal`** — fondear el treasury con ETH.
- **`vm.expectRevert` con strings y con selectors** — `abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, x)` para los custom errors de OZ v5.
- **`vm.expectEmit`** — verificar que se emita el evento `Voted` con los argumentos correctos.
- **Contrato auxiliar `RejectETH`** — un contrato sin `receive`/`fallback` para forzar el camino de "envío de ETH fallido".

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/15-dao`).

```bash
# Compilar
forge build

# Correr toda la suite (83 tests)
forge test

# Un test específico (ej. el caveat de seguridad)
forge test --match-test testDoubleVoteByTransferringTokens -vvv

# Cobertura
forge coverage
```

## Aprendizajes

- **Voto por `balanceOf` en vivo = doble voto reusando tokens.** El test [`testDoubleVoteByTransferringTokens`](test/DAO.t.sol) lo demuestra: alice vota con 100e18, los transfiere a carol, y carol **vuelve a votar** con los mismos tokens → el `forVotes` cuenta 200e18 con 100e18 reales. El `hasVoted` es **por address**, no por token. Por eso la governance seria usa `ERC20Votes` (snapshots con checkpoints al bloque de la propuesta): congela el poder de voto y los tokens dejan de ser "reutilizables".
- **Separar la lógica de los fondos baja el riesgo.** El treasury no sabe nada de propuestas ni votos: solo confía en una address (el DAO). Si el DAO tuviera un bug, el atacante igual tiene que pasar por la validación `msg.sender == dao` del treasury.
- **No siempre se llega al 100% de branches, y está bien.** Quedaron 3 ramas sin cubrir porque son **inalcanzables** por los invariantes del contrato: el revert "voting not started" (el `startTime` es el bloque de creación), votar una propuesta ya ejecutada (votar exige votación abierta), y el `delegate != 0` en `undelegate` (si delegaste, siempre hay delegado). Saber explicar *por qué* una branch no se puede cubrir vale más que inflar el número con tests artificiales.
- **`vm.expectRevert` para custom errors va con el selector**, no con un string: OZ v5 dejó de usar `require("...")` y usa `error OwnableUnauthorizedAccount(address)`.

## Posibles mejoras

### 🔒 Seguridad / production-quality

- **Migrar a `ERC20Votes` + snapshots**: es **el** fix del doble voto. Fijar el poder de voto al bloque de creación de la propuesta (checkpoints) hace que transferir tokens no agregue votos.
- **Timelock entre aprobación y ejecución**: un `Governor` real mete un `TimelockController` (delay entre que pasa la votación y se ejecuta) para que la comunidad pueda reaccionar a una propuesta maliciosa. Acá la ejecución es inmediata.
- **`emergencyWithdraw` demasiado poderoso**: el owner puede vaciar **todo** el treasury (incluido lo que la comunidad votó). En un DAO real eso contradice la descentralización — habría que limitarlo o eliminarlo.
- **La "delegación" no es delegación**: `delegateVotingPower` **transfiere** los tokens al delegado (que pasa a controlarlos de verdad). Una delegación real (estilo `ERC20Votes`) delega el *poder de voto* sin mover la propiedad de los tokens.

### 🧹 Limpieza / gas

- **Código inalcanzable**: las 3 guardas que no se pueden cubrir (`vote` "not started" / "executed", `undelegate` "no delegate") son efectivamente código muerto — se podrían eliminar.
- **`proposalPassed` duplica la lógica de `executeProposal`** (mismas guardas de quórum/mayoría). Se podría refactorizar en un helper interno para no repetir.
- **Custom errors** en vez de `require` con strings (más barato y testeable por selector).
- **`require(block.timestamp ...)`** dispara un warning de lint de Foundry (manipulable por validadores) — aceptable acá, pero conviene conocerlo.
