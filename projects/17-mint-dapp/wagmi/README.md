# Mint dApp — versión wagmi + viem

Integración con el stack moderno de React web3: hooks de wagmi, viem por debajo y react-query para el cacheo. Ver el [README del proyecto](../README.md) para la explicación de los conceptos.

Necesitás MetaMask. La lógica (hooks) está en [`app/page.jsx`](app/page.jsx), la config de wagmi en [`lib/wagmi.js`](lib/wagmi.js) y los providers en [`app/providers.jsx`](app/providers.jsx). El address y el ABI en [`lib/contract.js`](lib/contract.js).
