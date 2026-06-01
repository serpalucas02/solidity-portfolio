# 01 — First Contract

> Primer Smart Contract del curso. Contrato de práctica (no un caso de uso real) para experimentar con los building blocks fundamentales de Solidity.

## Descripción

`Calculadora` es un contrato de ejercicio que expone operaciones aritméticas básicas (suma, resta, multiplicación) sobre `uint256` e `int256`. **No pretende ser una calculadora útil** — su única función es servir de campo de pruebas para entender cómo se estructura un contrato real:

- Cómo declarar y exponer variables de estado.
- Cómo emitir eventos para comunicar lo que pasa on-chain.
- Cómo proteger funciones con `modifier`.
- Cómo separar lógica reutilizable en funciones `internal`.
- Cómo elegir entre `external`/`public` y entre `uint`/`int`.

## Conceptos aplicados

- **Estructura básica**: licencia SPDX, `pragma`, declaración de contrato.
- **Variables de estado**: `uint256 public resultado` (genera automáticamente el getter).
- **Tipos numéricos**: `uint256` para valores sin signo, `int256` para permitir negativos en una resta que puede dar < 0.
- **Eventos**: `Addition` y `Subtraction` para emitir el resultado de cada operación a los logs.
- **Modifiers**: `checkNumber` con `revert()` como precondición de ejecución.
- **Visibilidad**: `external` para funciones llamadas solo desde afuera, `internal` para la lógica reutilizable.
- **State mutability**: `pure` para funciones que no leen ni modifican estado.
- **Convención de naming**: sufijo `_` en parámetros para evitar shadow con variables de estado.

## Contratos

- [`Calculadora.sol`](contracts/Calculadora.sol) — contrato de ejercicio con operaciones aritméticas, eventos y un modifier.

## Cómo probarlo

### En Remix
1. Abrir [Remix IDE](https://remix.ethereum.org/).
2. Crear un nuevo archivo y pegar el contenido de [`contracts/Calculadora.sol`](contracts/Calculadora.sol).
3. Compilar con Solidity `0.8.24`.
4. Desplegar en el entorno **Remix VM** (red local, EVM **Cancun**).
5. Probar las funciones:
   - `addition(3, 5)` → emite evento `Addition` con `resultado_ = 8`.
   - `subtraction(10, 4)` → emite evento `Subtraction` con `resultado_ = 6`.
   - `subtraction2(-5, 10)` → devuelve `-15` (función `pure`, sin evento).
   - `multiplier(2)` → multiplica la state var `resultado` por 2 y la guarda.
   - `multiplier2(10)` → solo permite multiplicar por 10 (modifier `checkNumber`). Cualquier otro valor → `revert`.

## Aprendizajes

- **Eventos y valores de retorno**: una función que emite un evento no puede ser `view` ni `pure`. Cuando se la llama como transacción, su `returns` no llega al frontend — el dato hay que comunicarlo vía evento.
- **Shadowing**: declarar un parámetro o variable local con el mismo nombre que una variable de estado genera warnings y bugs sutiles. La convención del curso (`num1_`, `num2_`, `resultado_`) elimina el problema.
- **`external` vs `public`**: si una función no se llama internamente, `external` es la opción correcta — ahorra algo de gas porque lee los argumentos directo de `calldata` en lugar de copiarlos a `memory`.
- **Order of functions (Style Guide)**: convención de Solidity es ordenar `constructor → receive → fallback → external → public → internal → private`.
- **Casing**: contracts y events en `PascalCase`; funciones, modifiers, variables y parámetros en `camelCase`. Evitar `snake_case`.
- **Falsos amigos del inglés**: "subtraction", no "substraction" (en español es "sustracción", de ahí el error frecuente).
- **EVM target**: `solc 0.8.24` apunta por defecto a **Cancun**. Conviene matchear el entorno de deploy (en Remix VM, dejar Cancun).

## Posibles mejoras

- **NatSpec**: documentar las funciones `external` con `@notice`, `@param`, `@return`.
- **Custom errors** (Solidity ≥0.8.4): reemplazar `revert()` por `error NumberMustBeTen(uint256 received)` para dar contexto y ahorrar gas.
- **Evento `Multiplication`**: agregarlo para que las multiplicaciones también queden trackeables en los logs, por consistencia con `Addition` / `Subtraction`.
- **`indexed`** en parámetros de evento que vayan a usarse como filtro (no aplica mucho a operaciones aritméticas, pero es un reflejo a incorporar).
- **Tests automatizados**: pasar de probar manualmente en Remix a un suite de tests con Hardhat o Foundry.
