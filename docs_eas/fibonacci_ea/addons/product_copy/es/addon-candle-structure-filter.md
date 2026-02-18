# Addon - Candle Structure Filter

## Producto
- Nombre: `Candle Structure Filter`
- Tipo: `Addon`
- SKU: `addon_candle_structure`

## Descripcion
Este addon agrega una validacion previa basada en comportamiento de velas. Ayuda a filtrar entradas para que solo se ejecuten cuando el patron reciente coincide con la condicion seleccionada.

Para usuarios no traders: es una puerta de control de calidad. Si el patron reciente no cumple el criterio, la entrada se cancela.

## Inputs Explicados (Lenguaje Simple)
- `Candle_Timeframe`: marco temporal para revisar el patron de velas.
- `Candle_Strategy_Type`: modo de filtro (`OFF`, shrinked, expanded, bullish, bearish).
- `Candle_Strategy_Shift`: cuantas velas atras se compara.
- `Candle_Strategy_Depth`: cantidad de velas usadas en la validacion.

## Configuracion Recomendada Inicial
- `Candle_Timeframe = PERIOD_M15`
- `Candle_Strategy_Type = SHRINKED_CANDLE_STRUCTURE`
- `Candle_Strategy_Shift = 1`
- `Candle_Strategy_Depth = 1`

## Regla de Acceso
- Requiere entitlement cuando `Candle_Strategy_Type != OFF_CANDLE_STRUCTURE`.

## Si Falta el Addon
- El EA bloquea inicio cuando se selecciona un modo distinto de OFF.
