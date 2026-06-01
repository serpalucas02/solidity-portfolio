# 05 — Foundry · Calculadora

> Primer proyecto del portfolio usando [**Foundry**](https://book.getfoundry.sh/). La `Calculadora` rehecha desde cero pero ahora con **build, tests unitarios y fuzz testing escritos en Solidity** corriendo en una toolchain profesional.

## Descripción

Misma idea conceptual que el contrato del proyecto 01 (operaciones aritméticas básicas), pero con tres saltos:

1. **Estructura de proyecto Foundry** (`src/`, `test/`, `script/`, `lib/`, `foundry.toml`).
2. **Tests automatizados en Solidity** usando `forge-std`, con cheatcodes (`vm.prank`, `vm.expectRevert`, `vm.assume`).
3. **Fuzz testing**: el framework genera 256 inputs aleatorios por test para descubrir edge cases.

A nivel contrato, este se diferencia del 01 en que tiene 4 operaciones (suma, resta, multiplicación, división), la división está protegida por un `onlyAdmin`, y todas las operaciones actualizan la state var `resultado` además de emitir eventos.

## Features implementadas

- ✅ **Introducción a Foundry** — comandos básicos (`forge build`, `forge test`, `anvil`).
- ✅ **Proyecto con Foundry** — estructura `src/`/`test/`/`script/`/`lib/` con `foundry.toml`.
- ✅ **Calculadora 1 / 2 / 3** — suma, resta, multiplicación y división (gated por admin).
- ✅ **Unit testing 1 / 2 / 3 / 4** — 10 unit tests cubriendo happy paths, reverts por overflow, reverts por no-admin y división por cero.
- ✅ **Fuzzing testing** — 1 fuzz test (256 runs) sobre `division` con `vm.assume` para descartar el caso `b=0`.

**Estado final**: 11/11 tests pasando ✅

## Estructura del proyecto

```
05-foundry-calculadora/
├── foundry.toml                ← Solidity 0.8.24, EVM Cancun
├── remappings.txt              ← forge-std/=lib/forge-std/src/
├── src/
│   └── Calculadora.sol         ← contrato bajo prueba
├── test/
│   └── CalculadoraTest.t.sol   ← 11 tests (unit + fuzz)
├── script/                     ← vacío por ahora (sin scripts de deploy)
└── lib/
    └── forge-std/              ← submódulo (cheatcodes, asserts, etc.)
```

## Contratos y tests

- [`src/Calculadora.sol`](src/Calculadora.sol) — calculadora con 4 operaciones; `division` requiere admin y revierte si el divisor es 0.
- [`test/CalculadoraTest.t.sol`](test/CalculadoraTest.t.sol) — 10 unit tests + 1 fuzz test.

## Conceptos aplicados

### De Foundry

- **`foundry.toml`** — config del proyecto (compilador, EVM target, rutas).
- **`remappings.txt`** — para resolver `import "forge-std/..."` tanto en build como en el editor.
- **`forge build`** — compila y reporta errores.
- **`forge test`** — corre toda la suite.
- **`forge test -vvv`** — verbosidad para ver traces y logs.
- **`forge test --gas-report`** — gas usado por función.

### De `forge-std`

- **`import "forge-std/Test.sol"`** + heredar de `Test` para tener acceso a:
  - `vm.addr(uint256)` — genera una address determinística desde una "private key" (útil para roles fijos en tests).
  - `vm.startPrank(address)` / `vm.stopPrank()` — todas las llamadas entre medio se ejecutan como si las hiciera esa address.
  - `vm.expectRevert()` — la siguiente llamada DEBE revertir, si no falla el test.
  - `vm.assume(condition)` — en fuzz tests, descarta inputs que no cumplen la condición (sin contar como fallo).
  - `assert(...)` / `assertEq(...)` — asserts; `assertEq` es preferible porque imprime ambos valores cuando falla.

### Patrones de testing

- **`setUp()`** — se ejecuta antes de cada test, redeploya un contrato fresco → tests independientes.
- **Naming convention**: funciones que arrancan con `test...` son los tests; el resto son helpers.
- **Fuzzing con `vm.assume`**: filtra inputs inválidos (en lugar de hacer un `if` que silenciosamente saltea).
- **Asserts dentro del fuzz**: sin `assertEq`/`assert`, el test pasa siempre y no detecta nada — fuzzing sin assertion no testea nada.

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/05-foundry-calculadora`).

```bash
# Compilar
forge build

# Correr todos los tests
forge test

# Tests con traces detallados (ver llamadas, logs, reverts)
forge test -vvv

# Solo un test por nombre
forge test --match-test testCanNotDivideByZero

# Reporte de gas por función
forge test --gas-report

# Fuzz con más runs (default es 256)
forge test --fuzz-runs 10000
```

## Aprendizajes

- **Foundry rompe el paradigma de Remix**: ya no clickeás funciones a mano, escribís código que verifica el comportamiento de otro código. Una vez que te acostumbrás, no hay vuelta atrás.
- **Tests en Solidity, no en JS/TS**: contra Hardhat (que usa JavaScript), Foundry escribe los tests en el mismo lenguaje que el contrato. Menos contexto que cambiar, menos serialización entre dos lenguajes.
- **Cheatcodes (`vm.*`)**: son "magias" del entorno de testing que no existen en una blockchain real. `vm.prank` te deja simular ser cualquier address, `vm.expectRevert` valida reverts, `vm.warp` cambia el timestamp, etc. Esenciales para testing efectivo.
- **`vm.assume` vs `if return`**: en fuzz testing, `vm.assume(b_ != 0)` le dice al fuzzer "este input no me sirve, dame otro" y NO cuenta como ejecución. Si usás un `if (b_ == 0) return;`, el test "pasa" pero no verificó nada.
- **Asserts en fuzz**: un fuzz test sin `assertEq` es solo un "smoke test" — pasa porque no compara nada. La idea del fuzzing es **encontrar inputs que rompen un invariante** (ej. `a/b * b == a`).
- **Overflow/underflow nativo (Solidity ≥0.8)**: no hay que importar SafeMath. `5 - 15` revierte automáticamente. Eso quedó probado en `testCanNotMultiply2LargeNumbers`.
- **Inconsistencia contrato vs test**: el problema original (`division` devolvía 0, test esperaba revert) es exactamente el tipo de bug que un buen suite de tests detecta. El "fix" terminó siendo decidir cuál era el comportamiento correcto y alinear ambos.
- **`vm.addr(uint256)`** es preferible a hardcodear addresses en hex. Es determinístico y autodocumentado (`admin = vm.addr(1)` es claro que es la "primera cuenta de tests").

## Posibles mejoras

- **Custom errors en vez de `require` con string**: `error DivisionByZero();` + `if (b_ == 0) revert DivisionByZero();` es más barato en gas y permite `vm.expectRevert(Calculadora.DivisionByZero.selector)` para verificar revertimos por la razón correcta (no por una causa inesperada).
- **NatSpec docs** en las funciones `external` (`@notice`, `@param`, `@return`).
- **Cobertura**: correr `forge coverage` para ver qué líneas están cubiertas y qué no.
- **Más fuzz tests**: actualmente solo hay uno sobre `division`. Sería bueno fuzz tests para `addition`/`subtraction`/`multiplication` que verifiquen invariantes (ej. `addition(a, b) == addition(b, a)` o `subtraction(a, b) + b == a`).
- **Script de deploy**: agregar `script/Calculadora.s.sol` con un `DeployCalculadora` para poder deployar a testnet con `forge script ... --rpc-url ... --broadcast`.
- **Invariant testing** (próximo nivel): además de fuzz por test, definir invariantes globales del contrato (`assert(calculadora.admin() == admin_original_post_deploy)`) y dejar que Foundry los testee con secuencias random de llamadas.
- **Eventos verificados**: usar `vm.expectEmit` para chequear que cada operación emite el evento correcto con los argumentos correctos.
