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

> A medida que vaya completando proyectos los voy listando acá con enlace a su carpeta.

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
