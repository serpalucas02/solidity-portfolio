# 19 — EIP-712 Signatures

> **Firmas estructuradas (typed data)** con EIP-712: un ERC-20 con **permit** (ERC-2612, approvals sin gas) y un **GaslessVault** que usa un **struct EIP-712 propio** (`WithdrawAuthorization`) para depósitos y retiros autorizados por firma. Es el "nivel pro" de las firmas off-chain que vimos en [`resources/signatures`](../../resources/signatures): legibles en la wallet y atadas al contrato. Construido sobre los building blocks de OpenZeppelin (`EIP712`, `ECDSA`, `Nonces`, `ERC20Permit`).

## Descripción

Las firmas off-chain crudas (un `keccak256` pelado) tienen dos problemas: la wallet te muestra un **hash ilegible** al firmar, y una firma podría reusarse en **otro contrato u otra cadena**. **EIP-712** resuelve ambos: define **datos tipados** (structs con nombres de campo) que la wallet muestra de forma legible, y un **domain separator** (nombre + versión + chainId + dirección del contrato) que **ata la firma a un contrato y una red específicos**.

Dos formas de usarlo, las dos en este proyecto:
- **ERC-2612 Permit** (`PermitToken`): el caso estándar — aprobar el gasto de tokens con una firma en vez de una tx de `approve`.
- **Struct EIP-712 custom** (`GaslessVault`): EIP-712 es de propósito general, así que definís **tu propio** tipo (`WithdrawAuthorization`) para autorizar lo que quieras por firma.

## Conceptos aplicados

- **EIP-712 typed data**: `digest = keccak256("\x19\x01" || domainSeparator || structHash)`. El `structHash` codifica un **typehash** (la firma canónica del struct) + los valores; el `domainSeparator` ata la firma al contrato.
- **ERC-2612 `permit`**: approvals gasless. El owner firma off-chain, **cualquiera** (un relayer) lo sube on-chain en **una** tx. Implementado con el `ERC20Permit` de OZ.
- **Type hash propio**: `WithdrawAuthorization(address owner,address to,uint256 amount,uint256 nonce,uint256 deadline)` — reglas estrictas (sin espacios, campos en orden, tipos Solidity).
- **Gasless deposit** (`depositWithPermit`): combina `permit` + `transferFrom` en una sola tx → el usuario deposita **sin tener ETH**.
- **Defensas de firma**: `nonce` (anti-replay, vía `Nonces` de OZ), `deadline` (expiración), **domain separator propio por contrato** (anti cross-contract / cross-chain replay), y `ECDSA.recover` de OZ (maneja malleability y `address(0)` solo).

## Análisis de seguridad

A diferencia de otros módulos, **el código está sólido**: usa las primitivas de OZ correctamente (no reinventa `ecrecover`), respeta CEI, y aplica las tres defensas de firma (nonce + deadline + domain). El código no presenta vulnerabilidades críticas. Mejoras anotadas:

- 🟡 **Permit front-running (DoS de bajo impacto)** en `depositWithPermit`: si alguien ve la firma del permit en el mempool y llama `token.permit(...)` directamente antes, el nonce se consume y el `depositWithPermit` revierte. No roba fondos (solo molesta; el usuario reenvía). El patrón estándar de OZ para mitigarlo es envolver el `permit` en un `try/catch`.
- 🟡 **`SafeERC20`**: el vault usa `token.transferFrom`/`transfer` directos. Funciona porque el token es un OZ ERC-20 conocido (revierte en fallo), pero para aceptar tokens arbitrarios convendría `SafeERC20`.

## Contratos y tests

- [`src/PermitToken.sol`](src/PermitToken.sol) — ERC-20 + **ERC-2612 Permit** (extiende `ERC20Permit` de OZ).
- [`src/GaslessVault.sol`](src/GaslessVault.sol) — vault con `deposit` / `depositWithPermit` (gasless) / `withdraw` / `withdrawBySig` (struct EIP-712 custom).
- [`test/unit/EIP712Test.t.sol`](test/unit/EIP712Test.t.sol) — **29 tests**: fundamentals del domain separator y los typehashes, el flujo completo de permit y withdrawBySig (firmando con `vm.sign`), seguridad (replay por nonce, cross-contract, withdraw-sig usado como permit), depósitos/retiros directos, y **fuzz tests** (ninguna PK random puede falsificar la firma de otro).

**Cobertura**: ambos contratos al **100%** (líneas, statements, branches y funciones).

## Cómo probarlo

> Desde **adentro de este directorio** (`cd projects/19-eip712-signatures`).

```bash
forge build
forge test
forge test --match-test test_signatureNotReplayableAcrossContracts -vvv  # el de seguridad
forge coverage
```

> En los tests, **`vm.sign(privateKey, digest)`** simula lo que hace MetaMask off-chain: arma el digest EIP-712 y lo firma. Los actores se crean desde private keys (`vm.addr`) para poder firmar.

## Aprendizajes

- **EIP-712 = firmas legibles + atadas al contrato.** El domain separator (nombre + chainId + **address del contrato**) es lo que evita que una firma sirva en otro contrato o cadena — el test `test_signatureNotReplayableAcrossContracts` lo demuestra con un token "clon" del mismo nombre que igual rechaza la firma.
- **EIP-712 es de propósito general.** `permit` es solo un caso; podés definir **tu propio struct** (como `WithdrawAuthorization`) y autorizar cualquier acción por firma.
- **Las 3 defensas de firma van siempre juntas**: nonce (replay), deadline (expiración) y domain (contexto). Faltando una, hay un agujero.
- **No reinventes `ecrecover`**: `ECDSA.recover` de OZ ya maneja malleability y el `address(0)`. (Lo vimos crudo en [`resources/signatures`](../../resources/signatures); acá se ve la forma production con OZ.)

## Posibles mejoras

- Envolver el `permit` de `depositWithPermit` en `try/catch` (mitiga el front-running DoS).
- Usar `SafeERC20` para soportar tokens no estándar.
- Agregar `withdrawBySig` con `to = address(0)` u otros bordes, y un script de deploy.
