# Upgradeability — patrones de contratos actualizables

> Material de **referencia con código funcional**: cómo hacer un smart contract actualizable sin perder su estado, los **patrones** (Transparent, UUPS, Beacon, Diamond) y los **gotchas de seguridad**. Cada patrón está implementado y testeado con OpenZeppelin Upgradeable. Para entrevistas y para cuando un proyecto necesite poder evolucionar su lógica.

A diferencia de `oracles/` y `signatures/` (solo lectura), esto **compila y corre**: `forge test` desde esta carpeta levanta los 3 patrones (9 tests).

---

## El problema: los contratos son inmutables

Una vez deployado, el bytecode de un contrato **no se puede cambiar**. Si encontrás un bug o querés agregar una feature, no podés "editar" el contrato. La solución es separar **dónde vive el estado** de **dónde vive la lógica**, usando un **proxy**.

## El mecanismo: proxy + `delegatecall`

```
Usuario → [ PROXY ]  --delegatecall-->  [ IMPLEMENTATION ]
           (storage)                      (lógica, sin estado propio)
```

- El **proxy** es la dirección "pública" estable y guarda **todo el storage**.
- La **implementation** tiene la **lógica**.
- El proxy reenvía cada llamada con **`delegatecall`**: ejecuta el código de la implementation **pero en el contexto (storage) del proxy**.
- **Upgradear** = apuntar el proxy a una nueva implementation. La dirección y el estado **no cambian**; solo el código.

> Por eso un usuario siempre habla con la **misma address** (el proxy), aunque la lógica detrás cambie de V1 a V2.

---

## Los gotchas de seguridad (esto es lo que preguntan)

### 1. Nada de `constructor` → usar `initialize`

Un `constructor` corre **una sola vez, en el deploy de la implementation**, y escribe en el storage **de la implementation**, no del proxy. Resultado: el proxy quedaría sin inicializar. Por eso se usa una función **`initialize`** (con el modifier `initializer`, que garantiza que corra una sola vez) llamada **a través del proxy**.

### 2. `_disableInitializers()` en la implementation

La implementation queda "suelta" en su propia address. Si alguien la inicializa directo y toma su ownership, podría usar funciones peligrosas (sobre todo en UUPS, llevar a un `selfdestruct`/upgrade malicioso). Por eso, en el `constructor` de la implementation se llama **`_disableInitializers()`**: la deja inutilizable de forma directa.

### 3. Storage layout / storage collision

Como el storage vive en el proxy y la lógica en la implementation, **el orden de las variables tiene que ser compatible entre versiones**:

- V2 debe **mantener** las variables de V1 en el **mismo orden y slot**.
- Las variables nuevas van **al final**, nunca antes ni en el medio (si no, pisás estado existente → corrupción).
- No cambiar el tipo ni reordenar variables existentes.

> OZ v5 mitiga las colisiones entre el proxy y los módulos (Ownable, etc.) con **namespaced storage (ERC-7201)**: cada módulo guarda su estado en un slot calculado, no en los slots 0,1,2... Por eso en estos ejemplos `value` queda limpio en el slot 0.

### 4. Quién puede upgradear

El upgrade es la función **más peligrosa** del sistema (cambia toda la lógica). Siempre va **gateada por control de acceso** (`onlyOwner`, un `ProxyAdmin`, un multisig/timelock en producción).

---

## Los patrones

### Transparent — la lógica de upgrade vive en el PROXY

```
Usuario  ──→ [ Proxy ] --delegatecall--> [ Implementation V1 ]
                 ▲
Admin ──upgrade──┘   (vía un ProxyAdmin aparte)
```

- Un **`ProxyAdmin`** (contrato aparte) maneja los upgrades.
- **Regla clave**: el admin **no puede** llamar funciones de la implementation, y los usuarios **no pueden** upgradear. Esto evita el *selector clashing* (que una función de la lógica choque con una del proxy).
- **Contra**: cada llamada paga un chequeo extra de "¿sos admin?" → un poco más de gas. En OZ v5 el `TransparentUpgradeableProxy` crea su propio `ProxyAdmin`.
- Código: [`src/BoxV1.sol`](src/BoxV1.sol) · test: [`test/Transparent.t.sol`](test/Transparent.t.sol)

### UUPS — la lógica de upgrade vive en la IMPLEMENTATION

```
Usuario → [ ERC1967Proxy (mínimo) ] --delegatecall--> [ Implementation V1 ]
                                                        (incluye upgradeToAndCall
                                                         + _authorizeUpgrade)
```

- El proxy es **mínimo y barato** (`ERC1967Proxy`); la función de upgrade la trae la implementation al heredar `UUPSUpgradeable`.
- Vos implementás **`_authorizeUpgrade`** con el control de acceso (acá `onlyOwner`).
- **Riesgo característico**: si una versión futura **se olvida** de incluir la lógica de upgrade (`_authorizeUpgrade` / heredar `UUPSUpgradeable`), el proxy queda **congelado para siempre** (ya no se puede volver a actualizar).
- Es el patrón **recomendado por OpenZeppelin** hoy (más barato que Transparent).
- Código: [`src/uups/BoxUUPSV1.sol`](src/uups/BoxUUPSV1.sol) · test: [`test/UUPS.t.sol`](test/UUPS.t.sol)

### Beacon — muchos proxies, un solo punto de upgrade

```
[ BeaconProxy 1 ] ─┐
[ BeaconProxy 2 ] ─┼─→ [ Beacon ] ──→ [ Implementation V1 ]
[ BeaconProxy 3 ] ─┘        ▲
                       upgrade (1 vez)  → todos pasan a V2 a la vez
```

- Muchos proxies apuntan a **un beacon** que guarda la implementation.
- Actualizás el **beacon una sola vez** y **todos** los proxies pasan a la nueva versión de golpe.
- Ideal para **fábricas** de muchas instancias iguales (ej. un token o vault por usuario).
- Código: [`src/BoxV1.sol`](src/BoxV1.sol) (misma impl que Transparent) · test: [`test/Beacon.t.sol`](test/Beacon.t.sol)

### Diamond (EIP-2535) — solo mención

- Un proxy con **múltiples implementations** ("facets"), ruteando cada función al facet que la implementa. Permite contratos modulares y saltar el límite de 24KB de tamaño.
- Es **bastante más complejo** (storage por facets, `diamondCut`) — por eso no lo implementamos acá. Saber que **existe** y para qué sirve alcanza para una entrevista.

---

## Comparación rápida

| | **Transparent** | **UUPS** | **Beacon** |
|---|---|---|---|
| ¿Dónde está el upgrade? | En el proxy (ProxyAdmin) | En la implementation | En el beacon |
| Costo de gas por llamada | Mayor (chequeo admin) | Menor (proxy mínimo) | Bajo |
| ¿Cuántos contratos actualiza? | Uno | Uno | **Muchos a la vez** |
| Riesgo propio | Más caro | Olvidar la lógica → congela | El beacon es un punto único |
| Cuándo usarlo | Legacy / simple | **Default moderno (OZ)** | Fábricas de N instancias |

---

## Implementación con OpenZeppelin

Dos paquetes que trabajan juntos:
- **`@openzeppelin/contracts-upgradeable`** — las versiones de los contratos sin constructor (`Initializable`, `OwnableUpgradeable`, `UUPSUpgradeable`...). Las usás en tus **implementations**.
- **`@openzeppelin/contracts`** — los **proxies** (`ERC1967Proxy`, `TransparentUpgradeableProxy`, `ProxyAdmin`, `UpgradeableBeacon`, `BeaconProxy`).

> En producción conviene además el plugin **`openzeppelin-foundry-upgrades`**, que **valida automáticamente** el storage layout y los gotchas (constructor, `_disableInitializers`, etc.) en cada upgrade. Acá lo hicimos a mano para que se vea el mecanismo crudo.

## Cómo probarlo

> Desde **adentro de esta carpeta** (`cd resources/upgradeability`).

```bash
forge test            # los 3 patrones (9 tests)
forge test --match-contract UUPSTest -vv
```

Cada suite prueba lo mismo, que es lo que importa de upgradeability:
1. El estado inicial vive en el proxy.
2. Tras el upgrade, **el estado sobrevive** (`value` sigue ahí).
3. Tras el upgrade, **la lógica cambió** (aparece `increment`, `version()` devuelve "V2").
4. Solo quien tiene permiso puede upgradear.

---

## Checklist para un contrato upgradeable

- [ ] Heredar de los contratos **`-upgradeable`** (no los normales)
- [ ] **Sin `constructor`** con lógica → usar **`initialize`** con el modifier `initializer`
- [ ] `constructor() { _disableInitializers(); }` en la implementation
- [ ] **Storage layout estable**: variables nuevas **al final**, nunca reordenar
- [ ] Upgrade **gateado** (`onlyOwner` / ProxyAdmin / multisig + timelock en prod)
- [ ] En **UUPS**: no olvidar `_authorizeUpgrade` en **cada** versión
- [ ] (Prod) validar el upgrade con el plugin de OZ

## Links

- [OpenZeppelin — Proxy Upgrade Pattern](https://docs.openzeppelin.com/contracts/api/proxy)
- [OpenZeppelin Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/) · [EIP-1967 (storage slots)](https://eips.ethereum.org/EIPS/eip-1967) · [EIP-2535 (Diamond)](https://eips.ethereum.org/EIPS/eip-2535)
