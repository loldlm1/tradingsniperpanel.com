# Addon - Grid Strategy Settings

## Producto
- Nombre: `Grid Strategy Settings`
- Tipo: `Addon`
- SKU: `addon_grid_strategy_config`

## Descripcion
Este addon desbloquea la capa avanzada de configuracion grid. Esta pensado para usuarios que quieren definir que tan agresiva sera la expansion del grid y hasta que profundidad puede llegar.

Para usuarios no traders: este addon controla que tan "profundo" y "amplio" puede escalar entradas la estrategia. Mas profundidad puede dar flexibilidad, pero aumenta exposicion.

## Nota

El Fibonacci Elite EA se actualiza automaticamente con el add-ons comprado.

## Inputs Explicados (Lenguaje Simple)
- `Grid_Exponential_Multiplier`: velocidad de crecimiento de distancia entre niveles.
- `Grid_Level_Position_Start`: nivel inicial usado por la logica de ejecucion.
- `Grid_Level_Stop_Limit`: profundidad maxima de niveles grid.

## Configuracion Recomendada Inicial
- `Grid_Exponential_Multiplier = 1.20`
- `Grid_Level_Position_Start = 0`
- `Grid_Level_Stop_Limit = 3`

## Regla de Acceso
- Requiere entitlement cuando cualquiera de estos difiere de su valor por defecto:
- `Grid_Exponential_Multiplier = 1.0`
- `Grid_Level_Position_Start = 0`
- `Grid_Level_Stop_Limit = 1`

## Si Falta el Addon
- Se bloquea el inicio si se solicitan valores avanzados.
- En runtime se fuerza `Grid_Level_Stop_Limit = 1` como proteccion.

## Nota
- `Base_Strategy_Type` y `Points_Range_Setup` siguen permitidos en Base EA.
