# Addon - Structure Compound Context: Reversal Early

## Producto
- Nombre: `Compound Mode - Reversal Early`
- Tipo: `Addon`
- SKU: `addon_compound_reversal_early`

## Descripcion
Reversal Early esta pensado para usuarios que buscan capturar posibles giros antes de tener una confirmacion completa de tendencia. Puede abrir entradas mas tempranas, pero requiere mayor control de riesgo.

Para usuarios no traders: este modo intenta detectar "el giro" antes que otros modos.

## Nota

El Fibonacci Elite EA se actualiza automaticamente con el add-ons comprado.

## Modos Incluidos
- `COMPOUND_MODE_REVERSAL_EARLY_BUY`
- `COMPOUND_MODE_REVERSAL_EARLY_SELL`

Una compra incluye BUY y SELL.

## Inputs Explicados (Patron)
- `Base_Structure_Compound_Filter`: selecciona modo Reversal Early buy/sell.
- `Base_Fresh_Structure_Time`: hace mas estricto el filtro de tiempo estructural.

## Como Se Construye Este Patron
1. El EA detecta agotamiento de la tendencia activa.
2. Confirma una primera ruptura estructural en direccion opuesta.
3. Valida la primera secuencia de swing contraria.
4. Entra temprano frente a modelos conservadores, por eso requiere mas control de riesgo.

## Secuencia Canonica de Estructura (Mas Antigua -> Mas Reciente)
Orden interno del matcher: `fourth -> first` (Mas Antigua -> Mas Reciente).

- Modo Buy (`COMPOUND_MODE_REVERSAL_EARLY_BUY`):
  `[4] Maximo Mas Bajo -> [3] Minimo Mas Bajo -> [2] Maximo Mas Bajo -> [1] Minimo Mas Alto`
- Modo Sell (`COMPOUND_MODE_REVERSAL_EARLY_SELL`):
  `[4] Minimo Mas Alto -> [3] Maximo Mas Alto -> [2] Minimo Mas Alto -> [1] Maximo Mas Bajo`

## Configuracion Recomendada Inicial
- `Base_Structure_Compound_Filter = COMPOUND_MODE_REVERSAL_EARLY_BUY` o `COMPOUND_MODE_REVERSAL_EARLY_SELL`
- `Base_Fresh_Structure_Time = false`

## Regla de Acceso
- Requiere entitlement al seleccionar modo Reversal Early.

## Si Falta el Addon
- El EA bloquea inicio y muestra mensaje de addon faltante.
