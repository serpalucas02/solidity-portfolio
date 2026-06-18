# Firmas off-chain — referencia de seguridad

> Material de **consulta** (no es un proyecto): cómo verificar firmas off-chain en un contrato y, sobre todo, los **3 ataques clásicos** que hay que blindar. Viene del workshop de signatures del curso. Para usar cuando un contrato acepte autorizaciones firmadas (depósitos gasless, permits, meta-transacciones, allowlists).

Los contratos en [`src/`](src/) van en par vulnerable vs seguro, y los [`test/`](test/) **demuestran los ataques**.

| Archivo | Qué muestra |
|---|---|
| [`src/SignatureAttacks.sol`](src/SignatureAttacks.sol) | `VulnerableSignatureContract`: usa `ecrecover` **sin validar** → explotable. |
| [`src/SecureSignatureContract.sol`](src/SecureSignatureContract.sol) | Versión segura: valida `ecrecover`, anti-malleability, anti-replay. |
| [`test/SignatureAttacks.t.sol`](test/SignatureAttacks.t.sol) | Demuestra la explotación de la versión vulnerable. |
| [`test/SecureSignatureAttacks.t.sol`](test/SecureSignatureAttacks.t.sol) | Muestra que la versión segura rechaza los ataques. |

---

## Para qué sirven las firmas off-chain

Permiten **autorizar algo sin mandar una transacción** (sin pagar gas): vos firmás un mensaje **off-chain** (gratis), y otro lo presenta on-chain. El contrato verifica que la firma es tuya con `ecrecover` (o la librería `ECDSA`). Es lo que está detrás de los **depósitos gasless**, los **permits** de ERC-20, las **meta-transacciones** y las **allowlists firmadas**.

El flujo siempre es: **firmás un hash off-chain → el contrato recupera el firmante de la firma → compara contra quién esperaba.**

---

## Los 3 ataques que hay que blindar

### 1. `ecrecover` devuelve `address(0)` en firmas inválidas

`ecrecover` **no revierte** con una firma inválida: devuelve `address(0)`. Si no lo validás, un atacante manda `v=0, r=0, s=0` (basura), recuperás `address(0)`, y si tu lógica no lo chequea, **la firma "pasa"**.

```solidity
address signer = ecrecover(hash, v, r, s);
require(signer != address(0), "Invalid signature");   // 👈 SIN esto, sos vulnerable
```

> Es el bug central del workshop: el vulnerable se saltea este `require` y deja autorizar con firmas basura.

### 2. Replay attack — reusar la misma firma

Una firma válida se puede **presentar muchas veces**. Si firmaste "autorizá retirar $100", sin protección eso se reusa hasta vaciarte. Fix: que cada firma valga **una sola vez**.

```solidity
require(!usedHashes[hash], "Hash already used");   // tracking de hashes usados
usedHashes[hash] = true;
```

Las defensas típicas (una o varias):
- **Nonce** por usuario (un contador que sube en cada uso) — lo que usa tu `depositWithSignature` del proyecto 16.
- **Hash/firma usado** (`usedHashes`) — lo de este workshop.
- **Deadline** (timestamp de expiración) — para que la firma no sea eterna.
- **`address(this)` + `chainid`** en el hash — para que una firma no sirva en otro contrato u otra red (cross-contract / cross-chain replay).

### 3. Signature malleability — la firma "gemela"

Por las matemáticas de la curva (secp256k1), para **cada** firma válida `(r, s, v)` existe **otra** firma `(r, n-s, v')` que es **igual de válida** para el mismo mensaje. Si usás la *firma* (o su hash) como identificador único para anti-replay, un atacante toma tu firma, calcula la **gemela**, y **pasa el check de "ya usada"** porque para el contrato es otra firma → replay encubierto.

Fix: aceptar solo la mitad "baja" de `s` (canónica):

```solidity
if (uint256(s) > 0x7FFFFF...A0) {   // s > secp256k1n / 2
    revert("Invalid signature 's' value");
}
if (v != 27 && v != 28) {
    revert("Invalid signature 'v' value");
}
```

---

## La recomendación que resuelve todo: `ECDSA` de OpenZeppelin

En vez de manejar `ecrecover` a mano (y acordarte de los 3 checks), usá **`ECDSA.recover`** de OpenZeppelin:

```solidity
using ECDSA for bytes32;
address signer = hash.toEthSignedMessageHash().recover(signature);
```

Esa librería **ya hace por vos**:
- **Revierte** en firma inválida (no devuelve `address(0)`).
- **Rechaza la malleability** (chequea el rango de `s`).
- Valida el `v`.

O sea, te cubre los puntos 1 y 3 automáticamente. **El replay (punto 2) sí lo tenés que manejar vos** con nonce / deadline / contexto — la librería no sabe de tu lógica de negocio.

### Cómo se ve end-to-end (el patrón completo)

```solidity
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Example {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    mapping(address => uint256) public nonces;

    function doWithSignature(
        address user_,
        uint256 amount_,
        uint256 deadline_,
        bytes calldata signature_
    ) external {
        require(block.timestamp <= deadline_, "expired");            // anti-replay (tiempo)

        // 1. Reconstruís el MISMO hash que se firmó off-chain.
        //    Metés nonce + deadline + address(this) + chainid para
        //    que la firma sirva una sola vez, acá y en esta red.
        bytes32 hash = keccak256(
            abi.encodePacked(
                user_, amount_, nonces[user_], deadline_, address(this), block.chainid
            )
        );

        // 2. Recuperás el firmante. ECDSA revierte solo si la firma es
        //    inválida o maleable (no hace falta chequear address(0)).
        address signer = hash.toEthSignedMessageHash().recover(signature_);

        // 3. Validás que sea quien esperabas.
        require(signer == user_, "bad signer");

        nonces[user_]++;                                             // anti-replay (nonce)

        // ... tu lógica autorizada acá ...
    }
}
```

Los 3 pasos siempre son los mismos: **reconstruir el hash → recuperar el firmante con `ECDSA` → comparar contra quién esperabas.** La librería te tapa el `address(0)` y la malleability; vos ponés el hash (con nonce/deadline/contexto) y la comparación final.

> Y para mensajes estructurados, sumá **EIP-712** (`toTypedDataHash` en vez de `toEthSignedMessageHash`): firmas **legibles en la wallet** (MetaMask te muestra los campos en vez de un hash) y dominio (nombre, versión, chainId, contrato) atado, que mata el cross-contract replay de raíz.

---

## Conexión con tu proyecto 16

Tu `depositWithSignature` del `LendingProtocol` **ya está bien blindado**:
- Usa `ECDSA.recover` (cubre el `address(0)` y la malleability). ✅
- Tiene **nonce** + **deadline** (anti-replay). ✅

Lo único que le faltaría para ser de manual es atar el `chainid`/`address(this)` en el hash (o pasar a EIP-712) para el cross-chain replay — pero para el alcance del curso está sólido.

---

## Checklist rápido (para pegar en cualquier verificación de firma)

- [ ] Usar **`ECDSA.recover`** (no `ecrecover` pelado); si usás `ecrecover`, validar **`signer != address(0)`**
- [ ] Anti-**malleability**: `s` en la mitad baja + `v` ∈ {27, 28} (gratis si usás `ECDSA`)
- [ ] Anti-**replay**: **nonce** y/o **deadline** y/o hash usado
- [ ] Atar el contexto: **`address(this)` + `chainid`** en el hash (o **EIP-712**)
- [ ] Comparar el firmante recuperado contra **quién esperabas** (`== msg.sender` / un signer autorizado)

---

## Links

- [OpenZeppelin ECDSA](https://docs.openzeppelin.com/contracts/utils#ECDSA) · [EIP-712](https://eips.ethereum.org/EIPS/eip-712)
- [Solidity — `ecrecover` y malleability](https://docs.soliditylang.org/en/latest/units-and-global-variables.html#mathematical-and-cryptographic-functions)
