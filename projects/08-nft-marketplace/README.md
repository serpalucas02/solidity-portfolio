# 08 — NFT Marketplace

> Marketplace descentralizado de NFTs estilo OpenSea simplificado: los usuarios listan sus NFTs a un precio en ERC-20 (o ETH), otros usuarios los compran, y el contrato hace de intermediario confiable sin custodia.

## Descripción

_Por completar a medida que avance el proyecto._

## Features del módulo

- [ ] **NFT Marketplace** — overview y diseño del sistema (marketplace ≠ custodia).
- [ ] **Arquitectura de Smart Contract** — qué contratos componen el sistema y cómo se hablan.
- [ ] **Listing** — estructura de datos que representa "este NFT está a la venta a este precio".
- [ ] **List function** — usuario publica su NFT en el marketplace.
- [ ] **Cancel listing** — usuario retira su NFT de la venta.
- [ ] **Buy NFT** — comprador paga y recibe el NFT, vendedor recibe el monto.
- [ ] **Mock tokens** — contratos auxiliares (ERC-721, ERC-20) para que los tests tengan algo con qué jugar.
- [ ] **Testing setup** — `setUp()` que deploya marketplace + mocks + da balances iniciales.
- [ ] **Test listing** — happy path + reverts del list.
- [ ] **Test cancel listing** — solo el seller puede cancelar; el listing desaparece.
- [ ] **Test buy 1 / 2 / 3** — happy path, balances correctos, edge cases (NFT ya vendido, sin allowance, etc.).

## Conceptos clave (preview)

- **Marketplace ≠ custodia**: el contrato **NO** se queda los NFTs. El usuario solo le da `approve` y el contrato transfiere directo desde la wallet del seller a la del buyer cuando se concreta la venta.
- **Listings on-chain**: el "estoy vendiendo el NFT X a precio Y" vive en un `mapping(address => mapping(uint256 => Listing))` (por contrato NFT + tokenId).
- **Mock contracts** para testing: en lugar de testear contra el ERC-721 real o un USDC real, se hacen versiones "tontas" con mint público para tests reproducibles.
- **Composición de contratos**: este proyecto es la primera vez que el marketplace **interactúa con contratos externos no controlados** (cualquier ERC-721 / ERC-20 que el seller le pase). Buena oportunidad para hablar de qué chequear y qué confiar.

## Estructura del proyecto

```
08-nft-marketplace/
├── foundry.toml                ← Solidity 0.8.24, EVM Cancun
├── remappings.txt              ← @openzeppelin/contracts/, forge-std/
├── src/                        ← contratos: Marketplace, mocks (NFT/Token)
├── test/                       ← tests Solidity (.t.sol)
├── script/                     ← scripts de deploy (.s.sol)
└── lib/
    ├── forge-std/              ← cheatcodes y asserts
    └── openzeppelin-contracts/ ← ERC721, ERC20, IERC721, IERC20
```

## Contratos

_Se irán listando a medida que se creen._

## Cómo probarlo

> Todos los comandos se corren desde **adentro de este directorio** (`cd projects/08-nft-marketplace`).

```bash
# Compilar
forge build

# Correr tests
forge test

# Tests con traces detallados
forge test -vvv

# Test específico
forge test --match-test testBuyNFT

# Reporte de gas
forge test --gas-report
```

## Aprendizajes

- _Qué aprendí, qué me costó, qué haría distinto._

## Posibles mejoras

- _Ideas para extender el proyecto._
