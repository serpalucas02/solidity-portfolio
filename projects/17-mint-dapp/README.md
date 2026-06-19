# 17 — Mint dApp (integración web ↔ smart contract)

> Frontend que conecta una wallet, se asegura de estar en **Arbitrum** y **mintea un token** llamando la función `mintBAC()` de un contrato. Es el puente entre el smart contract y el usuario: cómo una web ejecuta las funciones que escribimos en Solidity. Implementado **dos veces** — con **ethers v6** (crudo, didáctico) y con **wagmi + viem** (el stack moderno de React) — para tener las dos referencias.

> ⚠️ **No hay un contrato deployado**: `CONTRACT_ADDRESS` es un placeholder. El objetivo es el **patrón de integración**, no un mint real. Cuando deployes un contrato con `mintBAC()`, ponés su address y el ABI y funciona.

## Las dos versiones

| Carpeta | Stack | Para qué |
|---|---|---|
| [`ethers/`](ethers/) | **ethers v6** + `window.ethereum` | Ver **crudo** cómo el front habla con la cadena. Didáctico. |
| [`wagmi/`](wagmi/) | **wagmi + viem** + react-query | El stack **moderno** de React web3 (hooks, cache, reactividad). |

Hacen **lo mismo**; cambia *cómo*.

## Conceptos clave de integración web3 (lo importante)

### 1. La wallet es el puente

El navegador no tiene una private key. La **wallet** (MetaMask) inyecta un objeto `window.ethereum` que:
- expone las cuentas del usuario (`eth_requestAccounts`),
- **firma** transacciones (la web nunca ve la private key),
- maneja la red activa.

### 2. Provider vs Signer

- **Provider** = conexión de **solo lectura** a la cadena. Para *leer* estado (ej. `balanceOf`). **No cuesta gas.**
- **Signer** = la cuenta conectada, que puede **firmar y pagar**. Para *escribir* (ej. `mintBAC`). **Cuesta gas** y abre el popup de MetaMask.

> Regla mental: **leer → provider (gratis)**, **escribir → signer (transacción + gas)**.

### 3. El ABI es el "contrato" entre el front y el SC

El front no conoce las funciones del contrato; se las decís con el **ABI** (la lista de funciones con sus tipos). Con `address + ABI`, la librería sabe cómo **codificar** la llamada (`mintBAC()`) en la `calldata` que entiende la EVM. Solo necesitás el ABI de **las funciones que usás**, no el contrato entero.

### 4. El flujo, siempre el mismo

```
1. Conectar wallet        → eth_requestAccounts
2. Asegurar la red        → switch / add Arbitrum
3. Leer (opcional)        → balanceOf(address)        [provider, gratis]
4. Escribir               → mintBAC()                 [signer, tx + gas]
5. Esperar confirmación   → tx.wait() / receipt
```

## ethers vs wagmi — la diferencia

**ethers** (imperativo): vos manejás todo a mano.
```js
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const contract = new ethers.Contract(ADDRESS, ABI, signer);
const tx = await contract.mintBAC();
await tx.wait();
```

**wagmi** (declarativo, con hooks): describís *qué querés* y la librería maneja el estado, el cacheo y la reactividad.
```js
const { writeContract } = useWriteContract();
writeContract({ address: ADDRESS, abi: ABI, functionName: "mintBAC" });
```

| | **ethers** | **wagmi + viem** |
|---|---|---|
| Estilo | Imperativo (hacés cada paso) | Declarativo (hooks de React) |
| Estado (cuenta, red, loading) | Lo manejás vos con `useState` | Te lo dan los hooks (`useAccount`, etc.) |
| Lecturas | A mano | Cacheadas y reactivas (react-query) |
| Reconexión / eventos | Los cableás vos | Automáticos |
| Cuándo usarlo | Scripts, algo simple, aprender | Apps React de verdad |

> Resumen: **ethers** te muestra el mecanismo; **wagmi** te da la ergonomía para una app real. Saber los dos es lo ideal.

## Cómo correrlo

Cada versión es una app Next.js independiente. Desde su carpeta:

```bash
cd ethers   # o cd wagmi
npm install
npm run dev   # http://localhost:3000
```

Necesitás **MetaMask** en el navegador. Para un mint real: deployá un contrato con `mintBAC()`, poné su `CONTRACT_ADDRESS` y `CONTRACT_ABI` en `lib/contract.js`, y tené algo de ETH en Arbitrum para el gas.

## Aprendizajes

- El front **no toca private keys**: solo le **pide a la wallet** que firme. La seguridad vive en MetaMask.
- **Leer es gratis, escribir cuesta gas**: separar `view` de transacciones es la base de toda dApp.
- El **ABI** es el lenguaje común front ↔ contrato — sin él, la web no sabe cómo llamar las funciones.
- **ethers** y **wagmi** resuelven lo mismo a distinto nivel: uno crudo, otro ergonómico.
