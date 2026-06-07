# 📚 Notes — Material de Estudio

Material consolidado de los 11 proyectos del portfolio, organizado para preparación de entrevistas.

## 📄 Documentos

### [`CONCEPTOS-CLAVE.md`](CONCEPTOS-CLAVE.md)

**Guía de estudio temática**. Organizada por concepto (no por proyecto) para que sirva como referencia rápida. Cubre:

1. Fundamentos de Solidity (visibilidad, modifiers, events, errors)
2. Identidad y access control (`msg.sender` vs `tx.origin`, Ownable)
3. ETH y activos nativos (`payable`, `receive`, `fallback`, `.call`)
4. Tokens ERC-20 (estándar, approve + transferFrom, SafeERC20)
5. NFTs ERC-721 (_safeMint, tokenURI, IPFS)
6. Comunicación entre contratos (interfaces, composability)
7. Patrones de seguridad (CEI, ReentrancyGuard, claim pattern)
8. DeFi y composability (AMM, Uniswap V2, LP tokens, slippage)
9. Oracles Chainlink (price feeds, manipulación, stale checks)
10. Matemática de decimales (USDC vs DAI vs Chainlink)
11. State machines (transiciones, presales)
12. Foundry y testing (cheatcodes, fork testing, mocks)
13. Patrones comunes (pull over push, wrapper de protocolo)
14. Gotchas frecuentes (USDT approve, stack too deep, etc.)

**Uso recomendado**: lectura previa a entrevistas + referencia rápida cuando dudás de algo.

### [`EXAMEN.html`](EXAMEN.html)

**Examen interactivo multiple-choice** con 65+ preguntas cubriendo todos los temas. Funcionalidades:

- ✅ Click para responder, feedback inmediato (correcto / incorrecto)
- 📖 Explicación de cada respuesta
- 📊 Score y progreso en vivo
- 💾 Persistencia en localStorage (cerrás y volvés, las respuestas siguen)
- 🔄 Botón de reset
- 🎯 Mensaje final con feedback según el % obtenido

**Cómo abrirlo**:
- **Doble click** en el archivo → se abre en tu browser por default.
- O **arrastralo** sobre Chrome/Firefox.
- O desde VSCode con la extensión "Live Server".

No requiere internet ni dependencias — es 100% self-contained.

**Target**:
- **90%+** → listo para entrevistas mid-level.
- **80-89%** → junior dominado, listo para postular.
- **60-79%** → tenés la base, repasar y volver.
- **<60%** → volver a leer `CONCEPTOS-CLAVE.md` y proyectos individuales.

## 🎯 Workflow de estudio sugerido

1. **Leé `CONCEPTOS-CLAVE.md`** entero una vez (~2 horas).
2. **Hacé `EXAMEN.html`** sin mirar nada (~1 hora). Mirá el % final.
3. **Identificá tus puntos débiles** (las secciones donde más erraste).
4. **Repasá el README del proyecto** que cubre ese tema (ej. si erraste en oracles → proyecto 11, en Uniswap → proyecto 09).
5. **Volvé a hacer el examen** una semana después.
6. Iterá hasta sentir que el 90%+ es estable.

## 💡 Tip de estudio

Para cada proyecto del portfolio, intentá **recrear el contrato desde cero sin mirar el código** (puede ser en un Remix vacío o un nuevo Foundry project). Lo que no podés recrear sin ayuda es lo que falta consolidar.
