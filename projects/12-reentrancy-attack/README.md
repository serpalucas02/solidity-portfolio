# 12 · Reentrancy Attack

Laboratorio de seguridad para entender de primera mano el ataque que **vació el DAO en 2016** (~60M USD de la época). Tenemos un banco vulnerable y un contrato atacante que lo drena por completo, con tests que prueban el robo.

## ¿Qué hay acá?

- [`src/SimpleBank.sol`](src/SimpleBank.sol) — un banco **vulnerable a propósito**. Cualquiera deposita ETH y retira lo suyo... salvo que el `withdraw()` tiene el orden de operaciones mal.
- [`src/Attacker.sol`](src/Attacker.sol) — el contrato que explota ese bug y se lleva **todo** el ETH del banco, no solo lo que depositó.
- [`test/Reentrancy.t.sol`](test/Reentrancy.t.sol) — dos tests: el flujo honesto y el ataque drenando el banco.

## El concepto: ¿qué es reentrancy?

Imaginate un cajero automático que te da la plata **antes** de descontarla de tu cuenta. Si pudieras congelar el tiempo justo después de recibir los billetes y pedir un nuevo retiro, el cajero te volvería a pagar porque tu saldo todavía figura intacto. Repetís hasta vaciarlo. Eso es un **reentrancy attack**.

En Solidity ese "congelar el tiempo" existe de verdad: cuando un contrato te manda ETH con `.call{value: ...}("")`, **le cede el control a tu código**. Si sos un contrato, eso dispara tu función `receive()`, y desde ahí podés volver a llamar al banco **antes de que el banco haya terminado de actualizar tu saldo**.

### El bug en `SimpleBank.withdraw()`

```solidity
function withdraw() public {
    require(userBalance[msg.sender] >= 1 ether, "User has not enough balance");
    require(address(this).balance > 0, "Bank is rekt");

    (bool success, ) = msg.sender.call{value: userBalance[msg.sender]}(""); // 👈 INTERACTION
    require(success, "fail");

    userBalance[msg.sender] = 0;  // 👈 EFFECT (llega TARDE)
}
```

El problema es el **orden**. Manda el ETH (interaction) **antes** de poner el saldo en cero (effect). Mientras corre el `.call`, `userBalance[msg.sender]` **todavía vale 1 ETH**, así que el `require` de arriba sigue pasando si volvemos a entrar.

### Cómo lo explota `Attacker`

```solidity
function attack() external payable {
    simpleBank.deposit{value: msg.value}();  // deposita 1 ETH (para tener saldo válido)
    simpleBank.withdraw();                    // arranca la cadena
}

receive() external payable {
    if (address(simpleBank).balance >= 1 ether) {
        simpleBank.withdraw();                // 👈 re-entra mientras quede plata
    }
}
```

La secuencia (con el banco arrancando con 10 ETH ajenos + 1 del attacker = 11 ETH):

1. `attack()` deposita 1 ETH y llama `withdraw()`.
2. El banco hace `call` → manda 1 ETH al Attacker → se dispara `receive()`.
3. `receive()` ve que el banco todavía tiene ≥ 1 ETH → llama `withdraw()` **de nuevo**.
4. El `require(userBalance[...] >= 1 ether)` **pasa**, porque el saldo nunca se puso en cero.
5. Se repite el paso 2–4 hasta que el banco queda seco.
6. Recién ahí se desenrolla la pila y se ejecutan los `userBalance = 0` (ya es tarde).

Resultado: **11 ETH terminan en el Attacker**. Las dos víctimas honestas perdieron sus 10 ETH.

## Cómo probarlo

```bash
forge test -vv
```

Salida esperada:

```
[PASS] test_HonestWithdrawReturnsOwnDeposit()
[PASS] test_ReentrancyDrainsTheBank()
```

El segundo test arma el escenario completo: Alice y Bob depositan 5 ETH cada uno, Eve despliega el `Attacker` con 1 ETH y al terminar `bank.totalBalance() == 0` y `address(attacker).balance == 11 ether`.

## Cómo se arregla

Hay dos defensas (idealmente se usan **las dos juntas**):

### 1. CEI — Checks · Effects · Interactions

Reordenar para que el estado se actualice **antes** de la llamada externa:

```solidity
function withdraw() public {
    uint256 amount = userBalance[msg.sender];   // Check
    require(amount >= 1 ether, "...");

    userBalance[msg.sender] = 0;                 // Effect  ✅ ANTES

    (bool success, ) = msg.sender.call{value: amount}("");  // Interaction
    require(success, "fail");
}
```

Ahora cuando el `receive()` re-entra, su saldo ya es 0 y el `require` lo rebota. El patrón se llama **Checks-Effects-Interactions** y es la regla de oro: *nunca* hagas una llamada externa con estado a medio actualizar.

### 2. `ReentrancyGuard`

El modifier `nonReentrant` de OpenZeppelin pone un candado: si la ejecución intenta re-entrar a una función protegida, revierte. Es el cinturón de seguridad por si se te escapa el orden CEI en algún lado.

```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SafeBank is ReentrancyGuard {
    function withdraw() public nonReentrant { ... }
}
```

## Aprendizajes

- Una llamada externa con ETH (`.call`, `transfer`, `send` a un contrato) **cede el control**. Tratá ese punto como una frontera peligrosa.
- El bug no es "usar `.call`" — `.call` es lo recomendado para mandar ETH. El bug es **el orden**: estado sin actualizar + llamada externa = reentrancy.
- CEI es gratis y previene la mayoría de los casos; `ReentrancyGuard` es la red de seguridad.
- Pensar siempre: *"¿qué pasa si el receptor, en vez de una wallet, es un contrato que me vuelve a llamar?"*

## Posibles mejoras / extensiones

- Agregar un `src/SafeBank.sol` con el fix aplicado y un test que pruebe que el mismo `Attacker` **falla** contra él (assert de que el banco conserva sus fondos).
- Variante de reentrancy **cross-function** (drenar vía una segunda función que comparte estado).
- Variante **read-only reentrancy** (leer un estado inconsistente durante el `call`).
