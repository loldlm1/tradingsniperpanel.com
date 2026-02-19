# Addon - Structure Compound Context: Volatility Trap

## Producto
- Nombre: `Compound Mode - Volatility Trap`
- Tipo: `Addon`
- SKU: `addon_compound_volatility_trap`

## Descripcion
Volatility Trap esta pensado para usuarios que necesitan un modo compound mas defensivo en mercados inestables. Busca reducir entradas de baja calidad cuando el precio se mueve de forma caotica.

Para usuarios no traders: este modo funciona como perfil de precaucion para momentos de mercado "desordenado".

## Modos Incluidos
- `COMPOUND_MODE_VOLATILITY_TRAP_BUY`
- `COMPOUND_MODE_VOLATILITY_TRAP_SELL`

Una compra incluye BUY y SELL.

## Inputs Explicados (Patron)
- `Base_Structure_Compound_Filter`: selecciona modo Volatility Trap buy/sell.
- `Base_Fresh_Structure_Time`: exige mas frescura temporal para validar contexto.

## Como Se Construye Este Patron
1. El EA detecta volatilidad anormal y posible falsa ruptura.
2. Verifica si el precio regresa rapido al rango estructural previo.
3. Confirma fallo de continuidad en el lado de la falsa ruptura.
4. Entra en direccion opuesta cuando la estructura vuelve a estabilizarse.

## Secuencia Canonica de Estructura (Mas Antigua -> Mas Reciente)
Orden interno del matcher: `fourth -> first` (Mas Antigua -> Mas Reciente).

- Modo Buy (`COMPOUND_MODE_VOLATILITY_TRAP_BUY`):
  `[4] Maximo Mas Alto -> [3] Minimo Mas Bajo -> [2] Maximo Mas Alto -> [1] Minimo Mas Bajo`
- Modo Sell (`COMPOUND_MODE_VOLATILITY_TRAP_SELL`):
  `[4] Minimo Mas Bajo -> [3] Maximo Mas Alto -> [2] Minimo Mas Bajo -> [1] Maximo Mas Alto`

## Configuracion Recomendada Inicial
- `Base_Structure_Compound_Filter = COMPOUND_MODE_VOLATILITY_TRAP_BUY` o `COMPOUND_MODE_VOLATILITY_TRAP_SELL`
- `Base_Fresh_Structure_Time = false`

## Regla de Acceso
- Requiere entitlement al seleccionar modo Volatility Trap.

## Si Falta el Addon
- El EA bloquea inicio y muestra mensaje de addon faltante.
