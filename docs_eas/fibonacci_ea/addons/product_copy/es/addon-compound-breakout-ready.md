# Addon - Structure Compound Context: Breakout Ready

## Producto
- Nombre: `Compound Mode - Breakout Ready`
- Tipo: `Addon`
- SKU: `addon_compound_breakout_ready`

## Descripcion
Breakout Ready esta orientado a usuarios que prefieren momentos de expansion de precio en lugar de entradas por retroceso. Ayuda a alinear entradas con posibles salidas de rango y aceleracion direccional.

Para usuarios no traders: este modo busca momentos donde el precio puede romper una zona y moverse mas rapido.

## Modos Incluidos
- `COMPOUND_MODE_BREAKOUT_READY_BUY`
- `COMPOUND_MODE_BREAKOUT_READY_SELL`

Una compra incluye BUY y SELL.

## Inputs Explicados (Patron)
- `Base_Structure_Compound_Filter`: selecciona modo Breakout Ready buy/sell.
- `Base_Fresh_Structure_Time`: agrega un filtro de frescura temporal mas estricto.

## Como Se Construye Este Patron
1. El EA identifica un rango comprimido con limites claros.
2. Mide acumulacion de presion con pruebas repetidas cerca de un borde.
3. Valida aceptacion de ruptura fuera del rango.
4. Entra en direccion de ruptura mientras la estructura sigue alineada.

## Secuencia Canonica de Estructura (Mas Antigua -> Mas Reciente)
Orden interno del matcher: `first -> fourth` (mas reciente -> mas antigua).

- Modo Buy (`COMPOUND_MODE_BREAKOUT_READY_BUY`):
  `[4] Minimo Mas Alto -> [3] Maximo Mas Bajo -> [2] Minimo Mas Alto -> [1] Maximo Mas Bajo`
- Modo Sell (`COMPOUND_MODE_BREAKOUT_READY_SELL`):
  `[4] Maximo Mas Bajo -> [3] Minimo Mas Alto -> [2] Maximo Mas Bajo -> [1] Minimo Mas Alto`

## Configuracion Recomendada Inicial
- `Base_Structure_Compound_Filter = COMPOUND_MODE_BREAKOUT_READY_BUY` o `COMPOUND_MODE_BREAKOUT_READY_SELL`
- `Base_Fresh_Structure_Time = false`

## Regla de Acceso
- Requiere entitlement al seleccionar modo Breakout Ready.

## Si Falta el Addon
- El EA bloquea inicio y muestra mensaje de addon faltante.
