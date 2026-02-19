# Addon - Structure Compound Context: Trend Ride

## Producto
- Nombre: `Compound Mode - Trend Ride`
- Tipo: `Addon`
- SKU: `addon_compound_trend_ride`

## Descripcion
Trend Ride es un addon de contexto compound orientado a continuidad. Esta pensado para usuarios que quieren alinear entradas con la direccion dominante en vez de buscar giros tempranos.

Para usuarios no traders: este modo prefiere "seguir la corriente" del mercado.

## Modos Incluidos
- `COMPOUND_MODE_TREND_RIDE_BUY`
- `COMPOUND_MODE_TREND_RIDE_SELL`

Una compra incluye BUY y SELL.

## Inputs Explicados (Patron)
- `Base_Structure_Compound_Filter`: selecciona el modo Trend Ride buy/sell.
- `Base_Fresh_Structure_Time`: exige estructura mas reciente (filtro mas estricto).

## Como Se Construye Este Patron
1. El EA confirma una estructura direccional clara (secuencia alcista o bajista).
2. Espera un retroceso controlado que no rompa esa estructura.
3. Entra cuando el precio retoma la direccion principal.
4. Con frescura activada, solo se aceptan estructuras recientes.

## Secuencia Canonica de Estructura (Mas Antigua -> Mas Reciente)
Orden interno del matcher: `fourth -> first` (Mas Antigua -> Mas Reciente).

- Modo Buy (`COMPOUND_MODE_TREND_RIDE_BUY`):
  `[4] Maximo Mas Alto -> [3] Minimo Mas Alto -> [2] Maximo Mas Alto -> [1] Minimo Mas Alto`
- Modo Sell (`COMPOUND_MODE_TREND_RIDE_SELL`):
  `[4] Minimo Mas Bajo -> [3] Maximo Mas Bajo -> [2] Minimo Mas Bajo -> [1] Maximo Mas Bajo`

## Configuracion Recomendada Inicial
- `Base_Structure_Compound_Filter = COMPOUND_MODE_TREND_RIDE_BUY` o `COMPOUND_MODE_TREND_RIDE_SELL`
- `Base_Fresh_Structure_Time = false`

## Regla de Acceso
- Requiere entitlement al seleccionar modo Trend Ride.

## Si Falta el Addon
- El EA bloquea inicio y muestra mensaje de addon faltante.
