# 20 — Inline Assembly (Yul)

> **Inline assembly (Yul)** paso a paso: los opcodes fundamentales del EVM (storage, aritmética, bitwise, memoria), cómo funcionan los **reverts y los checks de overflow por debajo**, y patrones prácticos donde assembly da capacidades o gas que Solidity puro no alcanza (bit packing, hashing eficiente, `extcodesize`). Material **didáctico** para entender el EVM desde abajo.

## Descripción

Solidity compila a bytecode del EVM, pero a veces querés **control directo**. El bloque `assembly { ... }` te deja escribir **Yul** dentro de una función. Tres motivos para usarlo: **gas** (saltear los chequeos de Solidity cuando sabés que la operación es segura), **acceso a features del EVM** que Solidity no expone (slots de storage crudos, `extcodesize`, `coinbase`, etc.), y **entender** cómo funciona Solidity por dentro.

El proyecto son tres contratos, de menor a mayor:
- **`AssemblyBasics`** — storage (`sstore`/`sload`), aritmética (`add`/`sub`/`mul`/`div`/`mod`), bitwise (`and`/`or`/`xor`/`not`/`shl`/`shr`), comparaciones (`iszero`/`lt`/`gt`/`eq`) y memoria (`mstore`/`mload`).
- **`AssemblyErrors`** — cómo se arma un `Error(string)` byte por byte, el patrón `if iszero(cond) { revert(...) }` (que **es** el `require` por dentro), y `safeAdd`/`safeMul` con checks de overflow escritos a mano.
- **`AssemblyUtils`** — `balance`, `extcodesize`/`isContract`, `caller`/`origin`, `keccak256` directo en memoria, y **bit packing** (dos `uint128` en un solo slot → ahorra ~20k de gas).

## Conceptos aplicados

- **Las 3 ubicaciones de datos del EVM**: stack (cómputo), memory (temporal, byte array) y storage (persistente, key→value de 256 bits).
- **Orden de Yul al revés**: `shl(shift, value)` / `shr(shift, value)` — el shift va **primero**, opuesto a Solidity (`value << shift`).
- **Layout de memoria**: `0x00-0x3F` scratch (para hashing), `0x40` free memory pointer, `0x80+` memoria libre. Por eso el hashing usa el scratch space.
- **Cómo se ve un revert**: `revert(offset, size)` devuelve `size` bytes desde `offset`. Un `Error(string)` es `selector 0x08c379a0 + offset + length + string`; un custom error es **solo 4 bytes** (más barato).
- **Detección de overflow a mano**: en `add(a,b)`, si `result < a` hubo overflow; en `mul(a,b)`, si `a != 0 && result/a != b`.

## Seguridad: la lección clave del assembly

Estos contratos son **didácticos** (no manejan fondos, no son para producción), así que no hay vulnerabilidades explotables. Pero el tema **es** la seguridad, porque **assembly desactiva todas las redes de protección de Solidity**:

- 🔴 **`store(slot, value)` escribe a CUALQUIER slot sin control de acceso.** Acá es para enseñar `sstore`, pero en un contrato real este patrón es **catastrófico**: cualquiera podría sobreescribir el slot del `owner`, de un balance, etc. **Toda escritura de storage en assembly necesita su control de acceso.**
- 🔴 **La aritmética en assembly NO revierte en overflow** (a diferencia de Solidity 0.8+): `add`/`mul` wrappean en silencio, `div`/`mod` por cero devuelven 0. Por eso existen `safeAdd`/`safeMul` — y por eso reintroducir assembly aritmético te devuelve los bugs de overflow de la era pre-0.8.
- 🟡 **`extcodesize` / `isContract` no es confiable durante un constructor**: un contrato **en construcción** reporta `extcodesize == 0` (parece EOA). Usarlo como "anti-contrato" se puede bypassear llamando desde el constructor del atacante.

> El gran aprendizaje: **assembly es poder sin barandas.** Cada chequeo que Solidity te daba gratis (overflow, bounds, tipos) ahora lo tenés que poner vos.

## Contratos y tests

- [`src/AssemblyBasics.sol`](src/AssemblyBasics.sol) · [`src/AssemblyErrors.sol`](src/AssemblyErrors.sol) · [`src/AssemblyUtils.sol`](src/AssemblyUtils.sol)
- [`test/unit/AssemblyTest.t.sol`](test/unit/AssemblyTest.t.sol) — **23 tests**: cada opcode verificado contra su resultado esperado, los checks de overflow (`safeAdd`/`safeMul` revierten), el revert manual de `Error(string)`, `caller`/`origin` con `vm.prank`, y el round-trip de pack/unpack. Incluí los tests que faltaban (comparaciones, `readFromMemory`, `getCodeSize`, `getCallerAndOrigin`, `revertWithMessage`).

**Cobertura**: los tres contratos al **100%** (líneas, statements, branches y funciones).

## Cómo probarlo

> Desde **adentro de este directorio** (`cd projects/20-solidity-assembly`).

```bash
forge build
forge test
forge test --match-test test_safeAddOverflowReverts -vvv
forge coverage
```

## Aprendizajes

- **`require(cond)` es `if iszero(cond) { revert(...) }`** por dentro. Verlo en assembly desmitifica los reverts.
- **Bit packing** ahorra muchísimo gas: dos `uint128` en un slot en vez de dos. `packed = (a << 128) | b`, y se desempaca con shift + máscara.
- **El hashing eficiente** usa el scratch space (`0x00-0x3F`) para evitar copiar a memoria — `keccak256(0x00, 0x40)` hashea 64 bytes directos.
- **Assembly = potencia + responsabilidad**: todo lo que Solidity chequeaba por vos, ahora es tu trabajo.

## Posibles mejoras

- Agregar `tstore`/`tload` (transient storage, EIP-1153) como sección extra.
- Un ejemplo de `staticcall`/`delegatecall` crudo con manejo de `returndata`.
- Comparar el gas de `safeAdd` en assembly vs el `+` de Solidity 0.8 con un `gas-report`.
