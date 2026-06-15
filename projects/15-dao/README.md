# 15 — DAO / Governance

> **Organización Autónoma Descentralizada (DAO)**: un sistema de gobernanza on-chain donde los holders de un token de voto **proponen**, **votan** y **ejecutan** cambios sin un administrador central. La regla es código: si una propuesta junta los votos necesarios, se ejecuta sola. Construido con Foundry + OpenZeppelin (`Governor` + `ERC20Votes` + `TimelockController`).

## Descripción

_Por completar a medida que avance el proyecto._

La idea central de una DAO es reemplazar al "dueño" (`onlyOwner`) por una **votación**. En vez de que una wallet decida, las decisiones pasan por un ciclo: alguien **propone** una acción (ej. "transferir X del tesoro", "cambiar un parámetro"), los holders del token de gobernanza **votan** durante una ventana de tiempo, y si se alcanza el **quórum** y la mayoría, la propuesta queda **lista para ejecutarse** (normalmente tras un *timelock* de seguridad).

## Conceptos clave (preview)

- **Token de gobernanza (`ERC20Votes`)**: un ERC-20 que además trackea **poder de voto** con *checkpoints* históricos. El peso del voto se mide en un bloque pasado (`snapshot`) para que nadie compre tokens justo antes de votar.
- **Delegación**: el poder de voto **no se activa solo** — hay que delegarlo (a uno mismo o a otro). Tener tokens ≠ tener votos hasta delegar. Es el gotcha #1 de los principiantes con `ERC20Votes`.
- **`Governor`**: el contrato que orquesta el ciclo de vida de una propuesta (`propose` → `castVote` → `queue` → `execute`) y define las reglas: *voting delay*, *voting period*, *proposal threshold*, *quorum*.
- **Quórum**: el mínimo de votos para que una propuesta sea válida (ej. 4% del supply). Sin quórum, aunque gane el "sí", no pasa.
- **`TimelockController`**: una vez aprobada, la propuesta no se ejecuta al instante sino tras un **retraso obligatorio**. Da tiempo a que la comunidad reaccione (ej. salir) si la propuesta es maliciosa. El Timelock suele ser el verdadero dueño del tesoro.
- **Estados de una propuesta**: `Pending → Active → Succeeded/Defeated → Queued → Executed` (o `Canceled`/`Expired`). Entender la máquina de estados es clave para testear.

## Posible stack (OpenZeppelin)

```
GovernanceToken (ERC20Votes)  ← poder de voto con checkpoints
        │ delega
        ▼
MyGovernor (Governor)         ← propose / vote / queue / execute
        │ es proposer/executor del
        ▼
TimelockController            ← retraso de seguridad; dueño del tesoro
        │ controla
        ▼
Treasury / contrato objetivo  ← lo que la DAO gobierna
```

## Features del módulo

- [ ] **Governance token** — `ERC20Votes` con delegación y checkpoints.
- [ ] **Governor** — configuración de voting delay / period / threshold / quórum.
- [ ] **Timelock** — `TimelockController` con su delay y roles (proposer / executor).
- [ ] **Wiring de roles** — conectar Governor ↔ Timelock ↔ contrato objetivo.
- [ ] **Proponer** — crear una propuesta (targets, values, calldatas, description).
- [ ] **Votar** — `castVote` (a favor / en contra / abstención) tras el voting delay.
- [ ] **Queue + Execute** — encolar en el timelock y ejecutar al vencer el delay.
- [ ] **Testing** — ciclo completo con `vm.roll` / `vm.warp` para avanzar bloques y tiempo, y verificar estados de la propuesta.

## Estructura del proyecto

```
15-dao/
├── foundry.toml                ← Solidity 0.8.24, EVM Cancun, via_ir + optimizer
├── remappings.txt              ← forge-std/, @openzeppelin/contracts/
├── src/                        ← acá van los contratos de la DAO
├── test/                       ← tests Solidity (.t.sol)
├── script/                     ← (deploy scripts, vacío por ahora)
└── lib/
    ├── forge-std/              ← cheatcodes y asserts
    └── openzeppelin-contracts/ ← Governor, ERC20Votes, TimelockController, ...
```

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/15-dao`).

```bash
# Compilar
forge build

# Correr toda la suite
forge test

# Con traces detallados
forge test -vvv

# Un test específico
forge test --match-test testPropose
```

## Aprendizajes

- _Qué aprendí, qué me costó, qué haría distinto._

## Posibles mejoras

- _Ideas para extender el proyecto._
