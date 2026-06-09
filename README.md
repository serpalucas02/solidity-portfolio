# Solidity Portfolio

Portafolio personal de proyectos desarrollados durante mi formación en Solidity y desarrollo de smart contracts.

## Sobre mí

> _Completar con una breve descripción personal: quién soy, qué busco, dónde encontrarme (LinkedIn, GitHub, etc.)._

## Estructura del repositorio

```
solidity-portfolio/
├── projects/        # Cada proyecto del curso vive en su propia carpeta
│   └── 00-template/ # Plantilla base para arrancar un proyecto nuevo
├── notes/           # Apuntes del curso, conceptos, repaso
└── resources/       # Links útiles, documentación, referencias
```

## Proyectos

| # | Proyecto | Descripción | Tecnologías | Estado |
|---|----------|-------------|-------------|--------|
| 01 | [First Contract](projects/01-first-contract/) | Contrato de práctica para experimentar con estado, eventos, modifiers, visibilidad y separación de lógica. | Solidity 0.8.24, Remix | ✅ Completo |
| 02 | [First Token](projects/02-first-token/) | Primer token ERC-20 heredando de OpenZeppelin, con mint inicial de 1000 unidades al deployer. | Solidity 0.8.24, OpenZeppelin, Remix, MetaMask | ✅ Completo |
| 03 | [Smart Contract Systems](projects/03-smart-contract-systems/) | Cheat-sheet del módulo: `msg.sender`/`tx.origin`, llamadas entre contratos vía interfaz, manejo de errores (`require` vs custom errors), `payable` y patrón withdraw. | Solidity 0.8.24, Remix | ✅ Completo |
| 04 | [Cryptobank](projects/04-cryptobank/) | Banco descentralizado: depósito y retiro de ETH con balance per-user, tope máximo configurable por un admin, patrón CEI anti-reentrancy. | Solidity 0.8.24, Remix | ✅ Completo |
| 05 | [Foundry · Calculadora](projects/05-foundry-calculadora/) | Primer proyecto con Foundry: calculadora con 4 operaciones + 11 tests (unit + fuzz) verificando happy paths, reverts y división por cero. | Solidity 0.8.24, Foundry, forge-std | ✅ Completo |
| 06 | [Staking App](projects/06-staking-app/) | App de staking con dos contratos: ERC-20 propio + StakingApp que custodia depósitos y paga rewards en ETH. CEI pattern, SafeERC20, 14 tests con cheatcodes (`vm.warp`, `vm.deal`, `vm.prank`). | Solidity 0.8.24, Foundry, OpenZeppelin | ✅ Completo |
| 07 | [NFT Collection](projects/07-nft-collection/) | Colección ERC-721 con metadata off-chain en IPFS, mint público con tope de supply, deploy script para Arbitrum. | Solidity 0.8.24, Foundry, OpenZeppelin, IPFS, Arbitrum | ✅ Código completo |
| 08 | [NFT Marketplace](projects/08-nft-marketplace/) | Marketplace de NFTs sin custodia: listar, cancelar y comprar ERC-721 pagando en ETH. CEI + ReentrancyGuard, approve/safeTransferFrom, 9 tests. | Solidity 0.8.24, Foundry, OpenZeppelin | ✅ Completo |
| 09 | [Swapping App](projects/09-swapping-app/) | Wrapper de Uniswap V2 para swappear tokens ERC-20. Primer proyecto integrando con un protocolo DeFi real, testeado con **fork de Arbitrum** contra USDC y DAI reales. | Solidity 0.8.24, Foundry, OpenZeppelin, Uniswap V2 | ✅ Completo |
| 10 | [Liquidity Pools](projects/10-liquidity-pools/) | Extensión del wrapper de Uniswap V2 con **add / remove liquidity** y un combo atómico "swap + add". Fork de Arbitrum contra los pools reales de USDC/DAI. | Solidity 0.8.24, Foundry, OpenZeppelin, Uniswap V2 | ✅ Completo |
| 11 | [Presale](projects/11-presale/) | Preventa multi-fase con pago en USDC / DAI / ETH, integración con **Chainlink Price Feed** (ETH/USD), claim pattern, blacklist y emergency withdraws. Fork de Arbitrum, 24 tests. | Solidity 0.8.24, Foundry, OpenZeppelin, Chainlink | ✅ Completo |
| 12 | [Reentrancy Attack](projects/12-reentrancy-attack/) | Laboratorio de seguridad: un `SimpleBank` vulnerable por **CEI roto** y un `Attacker` que lo drena por completo vía reentrancy. Test que demuestra el robo de fondos ajenos + el fix (CEI / ReentrancyGuard). | Solidity 0.8.24, Foundry | ✅ Completo |

> A medida que vaya completando proyectos los voy listando acá con enlace a su carpeta.

## 📚 Material de estudio

En [`notes/`](notes/) hay material consolidado para preparación de entrevistas:

- **[`CONCEPTOS-CLAVE.md`](notes/CONCEPTOS-CLAVE.md)** — Guía temática con todos los conceptos cubiertos en los 11 proyectos (Solidity, DeFi, Foundry, gotchas).
- **[`EXAMEN.html`](notes/EXAMEN.html)** — Examen interactivo multiple-choice (65+ preguntas) con feedback inmediato, explicaciones y score. Self-contained, abrí el HTML en cualquier browser.

## Cómo usar este repositorio

1. Cada proyecto está en `projects/NN-nombre-proyecto/`.
2. Dentro de cada carpeta hay un `README.md` con la descripción, instrucciones de despliegue y aprendizajes.
3. Los contratos `.sol` están en `projects/NN-nombre-proyecto/contracts/`.

## Stack / Herramientas

- **Solidity** — lenguaje principal
- **Remix IDE** — entorno de desarrollo inicial
- _A futuro: posiblemente Hardhat o Foundry, frontend con Next.js, etc._

---

_Este portafolio se actualiza constantemente a medida que avanzo en el curso._
