# Solidity Portfolio — Lucas Nahuel Serpa

**🌐 Idioma:** Español · [English](README.en.md)

> **Blockchain Developer** · Senior Full Stack Developer
> Portfolio de desarrollo blockchain: 21 proyectos del programa + 3 proyectos propios fullstack, deployados y verificados.

---

## Sobre mí

Soy **Lucas Nahuel Serpa**, desarrollador full stack especializándome en **blockchain**. Vengo de varios años construyendo software de producción para el **sector financiero** (el área de inversiones de **Santander Río** y la aseguradora **Zurich Santander**) y aplicaciones empresariales (hoy **Senior Full Stack Developer** en TanGo Energy Argentina). Esa experiencia en sistemas críticos me dejó un foco fuerte en **seguridad, testing y código robusto** — que ahora aplico al desarrollo on-chain.

Completé un **Máster intensivo en desarrollo Blockchain** (Blockchain Accelerator, 100% práctico) construyendo +25 proyectos DeFi. Este portfolio reúne **24**: los 21 del programa (de fundamentos de Solidity a DeFi avanzado) y **3 proyectos propios fullstack**, deployados y verificados en testnet, cada uno con demo en vivo. Trabajo con **mentalidad de auditor**: tests exhaustivos (incluidos casos adversariales) y revisión de vulnerabilidades antes de cada deploy.

Busco sumarme a un equipo de **Web3 / Blockchain**. Abierto a trabajo remoto; me manejo en español e inglés (escrito).

📍 CABA, Buenos Aires, Argentina · [GitHub](https://github.com/serpalucas02) · [LinkedIn](https://www.linkedin.com/in/lucas-serpaa/) · serpalucas02@gmail.com

---

## 🚀 Proyectos destacados

Tres proyectos **propios y fullstack** (contrato + frontend), cada uno con contrato auditado, **testeado a fondo**, deployado y **verificado en Sepolia**, y demo en vivo.

| Proyecto | Qué es | Demo | Repo |
|----------|--------|------|------|
| 🌱 **On-Chain Garden** | NFT dinámico **100% on-chain**: una planta que crece al regarla; imagen (SVG) y metadata generadas por el propio contrato (sin IPFS). | [Live](https://onchain-garden.vercel.app) | [GitHub](https://github.com/serpalucas02/onchain-garden) |
| 💸 **StreamPay** | **Streaming de pagos** ERC-20 en tiempo real (sueldo "por segundo"): create / withdraw / cancel con **pull-settlement** anti-bloqueo. | [Live](https://streampay-phi.vercel.app) | [GitHub](https://github.com/serpalucas02/streampay) |
| 🔁 **MiniSwap** | **AMM** de producto constante (`x·y=k`) hecho desde cero: swap + add/remove liquidity con LP tokens y fee del 0.3%. | [Live](https://miniswap-delta.vercel.app) | [GitHub](https://github.com/serpalucas02/miniswap) |

Stack de los customs: Solidity · Foundry · OpenZeppelin · Next.js · wagmi · viem · TypeScript · Tailwind.

---

## 📚 Proyectos del programa (Blockchain Accelerator)

Recorrido de fundamentos de Solidity hasta DeFi avanzado. Cada uno vive en [`projects/`](projects/) con su propio README.

| # | Proyecto | Descripción | Estado |
|---|----------|-------------|--------|
| 01 | [First Contract](projects/01-first-contract/) | Práctica de estado, eventos, modifiers, visibilidad. | ✅ |
| 02 | [First Token](projects/02-first-token/) | Primer ERC-20 heredando de OpenZeppelin. | ✅ |
| 03 | [Smart Contract Systems](projects/03-smart-contract-systems/) | `msg.sender`/`tx.origin`, llamadas entre contratos, errores, `payable`, patrón withdraw. | ✅ |
| 04 | [Cryptobank](projects/04-cryptobank/) | Banco descentralizado: depósito/retiro de ETH, tope por admin, CEI anti-reentrancy. | ✅ |
| 05 | [Foundry · Calculadora](projects/05-foundry-calculadora/) | Primer Foundry: 11 tests (unit + fuzz). | ✅ |
| 06 | [Staking App](projects/06-staking-app/) | ERC-20 propio + staking con rewards en ETH. CEI, SafeERC20, 14 tests. | ✅ |
| 07 | [NFT Collection](projects/07-nft-collection/) | ERC-721 con metadata en IPFS, mint con tope, deploy a Arbitrum. | ✅ |
| 08 | [NFT Marketplace](projects/08-nft-marketplace/) | Marketplace de NFTs sin custodia (list/cancel/buy en ETH). CEI + ReentrancyGuard, 9 tests. | ✅ |
| 09 | [Swapping App](projects/09-swapping-app/) | Wrapper de Uniswap V2, testeado con **fork de Arbitrum** (USDC/DAI reales). | ✅ |
| 10 | [Liquidity Pools](projects/10-liquidity-pools/) | Add/remove liquidity + combo "swap + add". Fork de Arbitrum. | ✅ |
| 11 | [Presale](projects/11-presale/) | Preventa multi-fase (USDC/DAI/ETH) con **Chainlink Price Feed**, claim pattern, blacklist. 24 tests. | ✅ |
| 12 | [Reentrancy Attack](projects/12-reentrancy-attack/) | PoC de seguridad: banco vulnerable (CEI roto) + atacante que lo drena vía reentrancy + fix. | ✅ |
| 13 | [ABI Encoding](projects/13-abi-encoding/) | `abi.encode` vs `encodePacked`, colisiones y `keccak256`. 18 tests. | ✅ |
| 14 | [Yield Farming](projects/14-yield-farming/) | Staking con rewards (`rewardPerToken` + `rewardDebt`). 24 tests, 100% coverage. | ✅ |
| 15 | [DAO / Governance](projects/15-dao/) | Gobernanza on-chain hecha a mano (propose → vote → execute) + treasury separado. 83 tests. | ✅ |
| 16 | [Lending & Borrowing](projects/16-lending-borrowing/) | Préstamos con colateral estilo Aave/Compound + **oráculo Chainlink** + ECDSA. 2 bugs corregidos. 39 tests. | ✅ |
| 17 | [Mint dApp](projects/17-mint-dapp/) | **Frontend**: MetaMask + mint, integrado **dos veces** (ethers v6 y wagmi + viem). | ✅ |
| 18 | [Lottery (Chainlink VRF)](projects/18-lottery-vrf/) | Lotería random con **VRF 2.5**. **Bug crítico corregido**: push → pull pattern. 29 tests. | ✅ |
| 19 | [EIP-712 Signatures](projects/19-eip712-signatures/) | Firmas typed-data: ERC-2612 permit + `GaslessVault` con struct EIP-712 propio. 29 tests. | ✅ |
| 20 | [Inline Assembly (Yul)](projects/20-inline-assembly/) | Inline assembly paso a paso + la lección de seguridad. 23 tests, 100% coverage. | ✅ |
| 21 | [Uniswap V3 Interactions](projects/21-uniswap-v3-interactions/) | Swaps, posiciones de liquidez (NFTs) y flash loans. 14 tests con **fork de mainnet**. | ✅ |

---

## 🛠️ Stack

Solidity · Foundry · OpenZeppelin · Chainlink · Uniswap V2/V3 · Next.js · wagmi · viem · React / React Native · Node.js · Oracle / PL-SQL

## 📫 Contacto

[GitHub](https://github.com/serpalucas02) · [LinkedIn](https://www.linkedin.com/in/lucas-serpaa/) · serpalucas02@gmail.com
