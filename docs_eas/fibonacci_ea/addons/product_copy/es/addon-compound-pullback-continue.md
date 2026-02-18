# Addon - Structure Compound Context: Pullback Continue

## Producto
- Nombre: `Compound Mode - Pullback Continue`
- Tipo: `Addon`
- SKU: `addon_compound_pullback_continue`

## Descripcion
`Pullback Continue se enfoca en reentrada despues de una correccion temporal del precio. Es util para usuarios que quieren continuidad con timing de retroceso en vez de entrada inmediata por ruptura.`

`Para usuarios no traders: este modo espera un pequeno retroceso antes de continuar en la direccion original.`

## Modos Incluidos
- `COMPOUND_MODE_PULLBACK_CONTINUE_BUY`
- `COMPOUND_MODE_PULLBACK_CONTINUE_SELL`

Una compra incluye BUY y SELL.

## Inputs Explicados (Patron)
- `Base_Structure_Compound_Filter`: selecciona modo Pullback Continue buy/sell.
- `Base_Fresh_Structure_Time`: activa control de frescura de estructura.

## Como Se Construye Este Patron
1. El EA detecta un impulso claro en una direccion.
2. Marca una zona de retroceso que sigue siendo sana para continuidad.
3. Verifica que el retroceso no rompa la estructura principal.
4. Entra cuando el momentum vuelve a la direccion original.

## Secuencia Canonica de Estructura (Mas Antigua -> Mas Reciente)
Orden interno del matcher: `first -> fourth` (mas reciente -> mas antigua).

- Modo Buy (`COMPOUND_MODE_PULLBACK_CONTINUE_BUY`):
  `[4] Maximo Mas Bajo -> [3] Minimo Mas Bajo -> [2] Maximo Mas Alto -> [1] Minimo Mas Alto`
- Modo Sell (`COMPOUND_MODE_PULLBACK_CONTINUE_SELL`):
  `[4] Minimo Mas Alto -> [3] Maximo Mas Alto -> [2] Minimo Mas Bajo -> [1] Maximo Mas Bajo`

## Configuracion Recomendada Inicial
- `Base_Structure_Compound_Filter = COMPOUND_MODE_PULLBACK_CONTINUE_BUY` o `COMPOUND_MODE_PULLBACK_CONTINUE_SELL`
- `Base_Fresh_Structure_Time = false`

## Regla de Acceso
- Requiere entitlement al seleccionar modo Pullback Continue.

## Si Falta el Addon
- El EA bloquea inicio y muestra mensaje de addon faltante.
