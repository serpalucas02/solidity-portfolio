# 03 — Smart Contract Systems

> Módulo del curso sobre interacción entre contratos, identidad on-chain (`msg.sender`, `tx.origin`), manejo de errores y de Ether. Carpeta tipo **cheat-sheet** con varios contratos cortos, uno por concepto.

## Estructura

```
contracts/
├── Sender.sol                          ← msg.sender en el constructor
├── SCConectados/
│   ├── Sumador.sol                     ← llama a Resultado vía interfaz
│   ├── Resultado.sol                   ← contrato consumido
│   └── interfaces/
│       └── IResultado.sol              ← interfaz para abstraer la llamada
├── Comprobadores/
│   └── RequireTest.sol                 ← if+revert, require, custom error
└── PayableFunctions/
    ├── PayableContract.sol             ← notas sobre send/transfer/call
    └── PayableContractV2.sol           ← withdraw con .call{value:}
```

## Temas del módulo

### 🪪 Identidad — `msg.sender` & `tx.origin`

**Contrato**: [`Sender.sol`](contracts/Sender.sol)

`msg.sender` es **quién llamó directamente** a la función (puede ser una EOA o un contrato). En el constructor, vale **quién deploya**.

```solidity
constructor() { owner = msg.sender; }
```

`tx.origin` es **quién originó la transacción end-to-end** (siempre una EOA, nunca un contrato).

**⚠️ Regla**: no usar `tx.origin` para autorización — un contrato intermedio puede colarse en checks contra `tx.origin` haciéndose pasar por la víctima (clásico ataque de "phishing contract").

### 🔗 Interacción entre contratos

**Contratos**: [`SCConectados/Sumador.sol`](contracts/SCConectados/Sumador.sol) · [`Resultado.sol`](contracts/SCConectados/Resultado.sol) · [`IResultado.sol`](contracts/SCConectados/interfaces/IResultado.sol)

`Sumador` calcula la suma de dos números y **delega el storage del resultado** a otro contrato (`Resultado`) vía interfaz.

```solidity
import "./interfaces/IResultado.sol";

contract Sumador {
    address public resultado;
    function addition(uint256 num1_, uint256 num2_) external {
        IResultado(resultado).setResultado(num1_ + num2_);
    }
}
```

**Concepto clave**: la interfaz declara solo las **firmas** de las funciones del contrato remoto, no su implementación. El cast `IResultado(address)` le dice al compilador "tratá esta dirección como un contrato con esta API". Esto desacopla: si mañana cambiás la implementación de `Resultado`, Sumador sigue funcionando mientras la firma `setResultado(uint256)` exista.

### ❗ Manejo de errores

**Contrato**: [`Comprobadores/RequireTest.sol`](contracts/Comprobadores/RequireTest.sol)

Tres formas de hacer un check de admin, de menos a más prolijo:

```solidity
// 1. if + revert pelado — barato pero ciego
if (msg.sender != admin) revert();

// 2. require con mensaje string — caro (el string vive en bytecode)
require(msg.sender == admin, "msg.sender is not admin");

// 3. if + custom error — barato Y con contexto (desde Solidity 0.8.4)
error SenderNotAdmin(address);
if (msg.sender != admin) revert SenderNotAdmin(msg.sender);
```

| Mecanismo | Gas | Contexto al usuario | Recomendado hoy? |
|---|---|---|---|
| `revert()` | 💚 más barato | ❌ ninguno | Solo para casos triviales |
| `require(cond, "...")` | 🔴 más caro | ✅ string | Legacy |
| Custom error | 💚 barato | ✅ args tipados | ✅ **Sí** |

### 💰 Manejo de Ether

**Contratos**: [`PayableFunctions/PayableContract.sol`](contracts/PayableFunctions/PayableContract.sol) · [`PayableContractV2.sol`](contracts/PayableFunctions/PayableContractV2.sol)

`PayableContract.sol` recopila las **notas conceptuales** del bloque:
- 1 ether = 10¹⁸ wei.
- `transfer()` y `send()` forwardean **solo 2300 gas** → revierten si el receptor tiene lógica costosa en `receive`/`fallback`.
- `send()` devuelve `bool`, `transfer()` lanza revert.
- `call()` reenvía todo el gas y no requiere interfaz.

`PayableContractV2.sol` implementa el **patrón withdraw** con `.call`:

```solidity
function sendEther() public payable {}                 // recibe ether

function withdrawEther(uint256 amount) public {
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transaction failed");
}
```

**Por qué `.call{value:}("")` es la opción recomendada hoy**:
- No tiene el límite arbitrario de 2300 gas — no rompe si el receptor es un contrato con lógica en `receive`/`fallback`.
- Devuelve `(bool success, bytes memory data)` → se puede chequear y revertir con razón.

## Cómo probarlo

### En Remix
1. Abrir [Remix IDE](https://remix.ethereum.org/).
2. Crear cada `.sol` y pegar su contenido.
3. Compilar con Solidity `0.8.24` (EVM target: **Cancun**).
4. Desplegar en **Remix VM** con los argumentos de constructor que correspondan.

### Argumentos de deploy

| Contrato | Constructor |
|---|---|
| `Sender` | _(sin args)_ |
| `Resultado` | _(sin args)_ |
| `Sumador` | `address resultado_`, `address admin_` |
| `RequireTest` | `address admin_` |
| `PayableContract` | _(sin args)_ |
| `PayableContractV2` | _(sin args)_ |

### Flujos sugeridos

- **Conectar contratos**: deployar `Resultado`, copiar su address, deployar `Sumador` pasándole esa address y un admin. Llamar `addition(3, 5)` en Sumador → leer `resultado()` en Resultado → debería devolver `8`.
- **Errores**: en `RequireTest`, deployar con wallet A como admin. Llamar las 3 funciones desde wallet A (todas pasan) y desde wallet B (todas revierten, pero el reporte de Remix muestra distinta info según el mecanismo).
- **Withdraw**: en `PayableContractV2`, llamar `sendEther` desde wallet A con un `value > 0`. Después llamar `withdrawEther(amount)` y verificar que el ETH vuelve.

## Aprendizajes

- **`msg.sender` vs `tx.origin`**: `msg.sender` cambia con cada salto entre contratos; `tx.origin` siempre es la EOA que firmó la tx original. Usar `tx.origin` para autorización abre la puerta a ataques con contratos intermedios.
- **Interfaces para llamar a otros contratos**: el patrón `IFoo(address).funcion()` es la forma estándar — no requiere importar el contrato entero, solo declarar su firma.
- **Tres mecanismos de error**:
  - `revert()` — minimalista, sin contexto.
  - `require` con string — costoso en gas (string en bytecode).
  - Custom errors (Sol ≥0.8.4) — baratos y con argumentos tipados. **Es el estándar actual.**
- **`payable` no es opcional**: una función necesita el modificador para aceptar ETH. Sin él, `msg.value > 0` revierte.
- **Send/Transfer/Call**:
  - `transfer` y `send` quedaron deprecados de facto por el límite de 2300 gas (introducido en tiempos pre-EIP-1559 para "prevenir reentrancy", hoy obsoleto).
  - `call{value:}("")` es la recomendación moderna.
- **Patrón withdraw (pull over push)**: en vez de que el contrato pushee ETH a los usuarios, los usuarios lo retiran. Mejor superficie de ataque (menos lugares donde un receptor malicioso puede romper el flujo).

## Posibles mejoras

### 🔒 Hardening de seguridad

Estos no son bugs del curso, pero son cosas reales que en producción explotarían — útil tener el reflejo desde ahora.

- **`Resultado.setResultado` no tiene access control**: cualquier dirección puede llamarla y sobreescribir el valor. Lo correcto sería guardar la address del Sumador autorizado en el constructor y validar `require(msg.sender == sumadorAutorizado)`.
- **`PayableContractV2.withdrawEther` permite a cualquiera retirar cualquier monto**: hoy, una vez que cualquiera deposita ETH en el contrato, **cualquier wallet** puede llamar `withdrawEther` y drenarlo. El patrón correcto es trackear balances por usuario:
  ```solidity
  mapping(address => uint256) public balances;
  function sendEther() public payable { balances[msg.sender] += msg.value; }
  function withdrawEther(uint256 amount_) public {
      require(balances[msg.sender] >= amount_, "Insufficient balance");
      balances[msg.sender] -= amount_;
      (bool success, ) = msg.sender.call{value: amount_}("");
      require(success, "Transaction failed");
  }
  ```
- **`Sumador.setFee` usa `revert()` pelado**: ya conocés custom errors — migrarlo a un `error NotAdmin(address sender)` da contexto sin costar más.
- **Reentrancy**: `withdrawEther` no protege contra reentrancy. Cuando lo veas en el módulo de seguridad, revisitarlo con CEI (Checks-Effects-Interactions) o `ReentrancyGuard` de OpenZeppelin.

### 🧹 Convención

- **Sufijo `_` en parámetros**: `PayableContractV2.withdrawEther(uint256 amount)` no lo usa — debería ser `amount_` para alinear con el resto del portfolio.
- **NatSpec**: documentar funciones `external` con `@notice`, `@param`, `@return`.

### 🧪 Ejercicios extra (refuerzan los temas)

- **Práctico de `tx.origin` con Atacante**: agregar un `Atacante.sol` en `SCConectados/` que llame a Sumador desde dentro de un contrato. Sumador tendría dos versiones de `setFee`: `setFeeMsgSender` (seguro) y `setFeeTxOrigin` (vulnerable). Demostrar que el atacante puede colar la segunda llamada y no la primera.
- **`receive` y `fallback`**: agregar las dos funciones a `PayableContract` y experimentar enviando ETH sin datos (dispara `receive`) vs con datos a una función inexistente (dispara `fallback`).
