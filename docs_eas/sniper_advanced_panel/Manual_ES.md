# Sniper Advanced Panel – Manual para Traders (ES)

## Contenidos
1. [Vista general del panel](#1-vista-general-del-panel)
2. [Botones y hotkeys](#2-botones-y-hotkeys)
3. [Flujo de Sniper Scope](#3-flujo-de-sniper-scope)
4. [Atajos solo teclado](#4-atajos-solo-teclado)
5. [Opciones de tema](#5-opciones-de-tema)
6. [Personalización de hotkeys y colores](#6-personalización-de-hotkeys-y-colores)
7. [Parámetros de entrada (inputs del EA)](#7-parámetros-de-entrada-inputs-del-ea)
8. [Cascada Proyección → Señal → Posiciones → Límites](#8-cascada-proyección--señal--posiciones--límites)
9. [Persistencia](#9-persistencia)

## 1. Vista general del panel

1.1 El panel se ancla en la esquina del gráfico definida en los inputs del Asesor Experto (EA). Arrastra el encabezado para reposicionarlo o usa el botón de tamaño para alternar entre modo compacto, estándar o grande. El encabezado sigue siendo arrastrable aun cuando el panel está minimizado y el movimiento se actualiza cada 16 ms para que la interacción sea fluida.

1.2 El cuadro de riesgo (parte inferior de la rejilla) define el contexto de tamaño antes de lanzar una proyección. Incluye:

  - **Selector de modo** (`Lot`, `%`, `$`) – cambia de modo haciendo clic sobre el selector; la etiqueta de sufijo se ajusta sola.
  - **Campo de valor** – acepta únicamente números; se filtran caracteres inválidos. Los valores se limitan a las reglas del bróker (mínimo/máximo de lotes, 0.01–100% de riesgo, 0–1,000,000 USD) y se normalizan a dos decimales.
  - **Mensajes de validación** – cuando el EA ajusta tu entrada (por ejemplo, al step del símbolo) el tooltip de confirmación explica el motivo.

1.3 La franja de estado sobre la rejilla resalta el botón de dirección activo, el multiplicador de TP, la opción de split, la profundidad del grid y cualquier confirmación pendiente.

1.4 Si el EA se recompila o reinicia con el panel plegado, al expandirlo se reconstruyen automáticamente los botones y tooltips.

1.5 El **mini panel de Stochastic Structure** flota sobre el gráfico con el mismo arrastre suave que el panel principal. Muestra, por timeframe:
  - Indicadores de soporte (`▲`) y resistencia (`▼`) con conteos en vivo.
  - El valor %K del estocástico más puntos de tendencia y la relación K/D (azul cuando %K > %D, ámbar en caso contrario).
  - Contadores de zonas activas y retestes para detectar rápidamente niveles apilados.
Puedes arrastrarlo desde cualquier área; se adapta al tema claro/oscuro y está preparado para añadir más filas de indicadores en el futuro.

## 2. Botones y hotkeys
Cada botón parpadea al presionarlo y ejecuta lo mismo que su hotkey por defecto. Si aparece un tooltip de confirmación, pulsa **Enter** o vuelve a hacer clic en el mismo botón para confirmar, o presiona **Esc** para cancelar.

**Etiquetas responsivas.** El texto de cada botón se adapta al ancho del panel para que los modos estándar y compacto sigan siendo claros. `{pct}` en la tabla siguiente se reemplaza por el porcentaje configurado para cierres parciales (por ejemplo `33%`).

| ID de botón | Layout completo (Título / Subtítulo) | Layout estándar (Título / Subtítulo) | Layout compacto (Título / Subtítulo) |
|-------------|--------------------------------------|--------------------------------------|--------------------------------------|
| PCLOSE_BUY_PARTIAL | `Buy {pct}` / `Partial Close` | `Buy {pct}` / `Partial` | `B {pct}` / `Part` |
| PCLOSE_SELL_PARTIAL | `Sell {pct}` / `Partial Close` | `Sell {pct}` / `Partial` | `S {pct}` / `Part` |
| PCLOSE_BUY_FULL | `Buy Exit` / `Full Close` | `Buy Exit` / `Full` | `B Exit` / `Full` |
| PCLOSE_SELL_FULL | `Sell Exit` / `Full Close` | `Sell Exit` / `Full` | `S Exit` / `Full` |
| SPLIT_POSITIONS | `Split Trade` / `Scale Out` | `Split` / `Scale` | `Split` / `Out` |
| TP_X1 | `TP x1` / `Primary` | `TPx1` / `Primary` | `x1` / `TP1` |
| TP_X2 | `TP x2` / `Secondary` | `TPx2` / `Second` | `x2` / `TP2` |
| TP_X3 | `TP x3` / `Extended` | `TPx3` / `Extend` | `x3` / `TP3` |
| GRID_L | `Grid Base` / `Risk Layer` | `Grid L` / `Layer` | `G L` / `Risk` |
| GRID_X2 | `Grid x2` / `Layer Two` | `Gridx2` / `Layer2` | `Gx2` / `L2` |
| GRID_X3 | `Grid x3` / `Layer Three` | `Gridx3` / `Layer3` | `Gx3` / `L3` |
| OPEN_BUY | `Buy Market` / `Execute` | `Buy MKT` / `Exec` | `BUY` / `MKT` |
| SET_BE | `Set BreakEven` / `Protect` | `Set BE` / `Protect` | `BE` / `Safe` |
| SCOPE_SELL | `Sell Scope` / `Adjust TP/SL` | `SellScope` / `TP/SL` | `Sell` / `Scope` |
| SCOPE_BUY | `Buy Scope` / `Adjust TP/SL` | `BuyScope` / `TP/SL` | `Buy` / `Scope` |
| OPEN_SELL | `Sell Market` / `Execute` | `Sell MKT` / `Exec` | `SELL` / `MKT` |

### Navegador de ciclos para acciones de gestión
- Aplica a los cierres parciales/completos, Set BreakEven y Sniper Scope. El primer clic apunta a **Todas las señales**; los clics u hotkeys siguientes recorren cada señal, luego cada posición y finalmente cada orden límite pendiente.
- El tooltip muestra el resumen del ciclo activo (ej.: `Cycle BUY 2/5 • P1/L0 • Señal #2`) para validar el objetivo antes de confirmar.
- Los tickets afectados se marcan en el gráfico con una HLINE azul neutra y gruesa para identificar qué entradas se cerrarán o ajustarán.
- Pulsa **Enter** (o haz clic cuando el tooltip lo permita) para confirmar; usa **Esc** para cancelar. Cambiar a otra acción reinicia el ciclo anterior y borra el highlight.

2.1 **Partial Close BUY** (`Q` por defecto)
  - Cierra solo un porcentaje de las posiciones BUY (input `panel_partial_close_percent`, 33% por defecto).
  - El primer clic abre una confirmación con volumen y P/L estimados; confirma para enviar la orden.
  - Vuelve a pulsar (o usa la hotkey) para avanzar el ciclo BUY: todas las señales → cada señal → cada posición → cada límite pendiente. La HLINE resaltada indica qué entradas se recortarán.

2.2 **Partial Close SELL** (`W` por defecto)
  - Igual que 2.1 pero para posiciones SELL.
  - El ciclo SELL sigue el mismo orden y highlight, permitiendo apuntar a una señal/leg SELL por vez antes de volver a TODAS.

2.3 **Close BUY FULL** (`E` por defecto)
  - Muestra una confirmación para cerrar el 100% de la exposición BUY.
  - El comportamiento del ciclo es igual al de 2.1, así puedes salir de todo o bajar hasta un único ticket BUY antes de confirmar.

2.4 **Close SELL FULL** (`R` por defecto)
  - Refleja 2.3 para posiciones SELL.
  - Pulsaciones repetidas recorren el ciclo SELL; el tooltip mantiene el resumen actual sincronizado.

2.5 **Split Positions** (`A` por defecto)
  - Activa/desactiva la proyección en múltiples legs. Si está activo, la entrada de mercado reparte el volumen entre TP1…TPx.
  - La preferencia queda guardada entre proyecciones; desactiva para volver al modo de un solo TP.

2.6 **TP X1** (`S` por defecto)
  - Fija el multiplicador TP en 1R (base) y actualiza inmediatamente una proyección activa.

2.7 **TP X2** (`D` por defecto)
  - Aplica un laddering de TP a 2R.

2.8 **TP X3** (`F` por defecto)
  - Aplica un laddering de TP a 3R.

2.9 **GRID L** (`Z` por defecto)
  - Activa/desactiva el modo grid. Al activarlo se preparan al menos dos capas.

2.10 **GRID X2** (`X` por defecto)
  - Fuerza la profundidad del grid a 2 capas y guarda la elección.

2.11 **GRID X3** (`C` por defecto)
  - Fuerza la profundidad del grid a 3 capas.

2.12 **OPEN BUY** (Flecha arriba por defecto)
  - Inicia o cancela una proyección BUY. Si ya hay una activa, vuelve a pulsar para cancelarla.
  - Aplica el TP multiplier seleccionado, la preferencia de split y el plan de grid.

2.13 **SET BE** (`Espacio` por defecto)
  - Mueve los stop-loss de todas las posiciones gestionadas a break-even cuando el precio lo permite.
  - Recorre señales/legs igual que los botones de cierre; solo los tickets resaltados quedan protegidos al confirmar.

2.14 **SCOPE SELL** (`G` por defecto)
  - Activa Sniper Scope con foco SELL. Sirve para alinear SL/TP del lado vendedor usando la mira.
  - Al pulsar de nuevo avanzas el ciclo SELL del scope (señal → posición → límite). El tooltip refleja el ciclo y las HLINE muestran los tickets activos.

2.15 **SCOPE BUY** (`H` por defecto)
  - Igual que 2.14 pero para el lado BUY.
  - El ciclo BUY funciona igual y al iniciar otra acción de gestión se cancela el scope y el highlight pasa al nuevo objetivo.

2.16 **OPEN SELL** (Flecha abajo por defecto)
  - Inicia o cancela una proyección SELL con los ajustes vigentes de TP/split/grid.

## 3. Flujo de Sniper Scope

3.1 Activa **SCOPE SELL** (2.14) o **SCOPE BUY** (2.15). Aparecen una mira y una tarjeta informativa; el foco limita los ajustes a ese lado.

3.2 Mueve el ratón para elegir el precio objetivo. La tarjeta resume volumen, distancia ponderada de TP/SL y beneficio estimado.

3.3 Haz clic en el gráfico para fijar el precio. Pulsa **Enter** para aplicar los nuevos TP/SL o **Esc** para salir sin cambios.

3.4 Mientras Scope está activo los botones quedan bloqueados excepto el botón de scope seleccionado, evitando acciones accidentales. Si inicias otra acción de gestión el scope se cancela automáticamente y reutiliza el tooltip compartido.

## 4. Atajos solo teclado

4.1 **Enter** – confirma tooltips de cierre parcial o compromete una proyección / selección del scope.

4.2 **Esc** – cancela confirmaciones, proyecciones o Sniper Scope.

4.3 **Tecla de tema** (por defecto `U`) – alterna inmediatamente entre modo claro/oscuro.

## 5. Opciones de tema

5.1 El EA recuerda el último tema usado por gráfico y lo recarga al iniciar.

5.2 Cambia el tema con la tecla definida en `theme_toggle_key` (por defecto `U`).

5.3 Persistencia de tema: el input `theme_dark` define el modo inicial; la elección por gráfico se guarda en el archivo de estado.

5.4 Canvas, panel, líneas de proyección y Sniper Scope se recolorean automáticamente al cambiar de tema.

## 6. Personalización de hotkeys y colores

6.1 Adjunta el EA una vez para que cree los archivos por defecto en `Archivo → Abrir carpeta de datos → Terminal\Common\Files\SniperAdvancedPanel\config`.

6.2 Localiza el archivo `<SÍMBOLO>_<ChartID>_panel.ini` (ejemplo: `EURUSD_123456_panel.ini`).

6.3 En `[Hotkeys]` asigna tokens como `Q`, `1`, `ArrowUp` o `Space`. Las flechas deben escribirse `ArrowUp/Down/Left/Right`.

6.4 En `[Colors]` cada línea recibe cinco valores hex: `background, hover, active, border_default, border_active`. Ejemplo:
```
OPEN_BUY=#059669,#047857,#065F46,#1E293B,#0F172A
```

6.5 Guarda el archivo y recarga el EA (cambia de timeframe o vuelve a adjuntarlo) para aplicar los cambios.

6.6 Si falta alguna clave o color, el EA usa los valores Tailwind por defecto.

## 7. Parámetros de entrada (inputs del EA)

7.1 **Ubicación del panel**
  - `panel_x`, `panel_y` – desplazamiento en píxeles desde la esquina elegida.
  - `panel_width`, `panel_height` – tamaño inicial; cambiar el modo de tamaño puede modificar el ancho.
  - `panel_corner` – esquina de anclaje.
  - `panel_partial_close_percent` – porcentaje usado por los botones de cierre parcial (limitado a 1–99%).

7.2 **Hotkeys y tema**
  - `hk_prefer_numpad` – obliga al teclado numérico cuando el autodetect está desactivado.
  - `hk_auto_detect` – alterna entre fila superior/numpad según la última tecla pulsada.
  - `theme_dark` – tema por defecto al iniciar.
  - `theme_toggle_key` – carácter ASCII para alternar temas (por defecto `'U'`).

7.3 **Proyección**
  - `use_canvas_projection` – dibuja overlays de gradiente.
  - `projection_use_native_labels` – usa etiquetas del broker en lugar de personalizadas.
  - `canvas_projection_width`, `canvas_position_mode`, `canvas_x_offset_px`, `canvas_margin_right_px` – controlan la colocación del canvas.
  - `proj_ATR_Period`, `proj_ATR_Multiplier` – semilla de SL basada en ATR para la proyección. El multiplicador por defecto es 2.0.
  - `proj_ATR_AppliedPrice` – precio aplicado para anclar SL/TP basados en ATR: `PRICE_CLOSE`, `PRICE_OPEN`, `PRICE_HIGH`, `PRICE_LOW`, `PRICE_MEDIAN`, `PRICE_TYPICAL` (por defecto), `PRICE_WEIGHTED`.
  - `proj_Gradient_Steps` – cantidad de bandas de gradiente.
  - `proj_grid_enable_default` – activa grid por defecto en nuevas proyecciones.
  - `proj_grid_factor_l2`, `proj_grid_factor_l3` – multiplicadores de volumen para las capas 2 y 3.

7.4 **Debug del canvas** (solo diagnóstico)
  - `dbg_canvas_logs` – logs detallados de dibujo.
  - `dbg_canvas_flat_colors` – desactiva el gradiente para depurar.
  - `dbg_canvas_color_diagnostics` – dibuja franjas RGB para validar canales.
  - `dbg_canvas_overlap_scan` – informa objetos superpuestos.
  - `dbg_canvas_force_palette_test` – fuerza paleta rojo/verde para pruebas visuales.
  - `dbg_canvas_auto_palette_dump` – guarda un volcado de paleta al dibujar.

7.5 **Stochastic Structure S&R y mini panel**
  - `InpStoch_KPeriod`, `InpStoch_DPeriod`, `InpStoch_Slowing`, `InpStoch_PriceMode` – parámetros nativos del estocástico usados por el micro-servicio de zonas S/R.
  - `InpStoch_MinRetestsForZoneDraw` – número mínimo de retestes necesario antes de pintar una zona en el gráfico (por defecto `1`).
  - `InpStoch_MaxRetestsPerZone` – limita la cantidad de retestes que se contabilizan por zona; cualquier valor por encima del límite se ignora tanto en el dibujo como en el mini panel (por defecto `6`).
  - `InpStoch_PanelTF1` … `InpStoch_PanelTF4` – timeframes que sigue el mini panel (por defecto `M1`, `M5`, `M15`, `H1`). Las métricas se refrescan cada minuto y cuando se actualiza la estructura de fondo. Los toques de soporte/resistencia se confirman usando los máximos y mínimos de las dos últimas velas.

## 8. Cascada Proyección → Señal → Posiciones → Límites

8.1 Al iniciar una proyección (2.12 o 2.16) se crea una **señal** con dirección, precio de entrada, SL/TP objetivo, multiplicador TP, bandera de split y profundidad de grid.

8.2 El EA calcula el volumen requerido a partir del cuadro de riesgo (1.2) y de los límites del bróker, distribuyéndolo por capa de grid y por leg de TP.

8.3 Cada leg de mercado se envía inmediatamente y su ticket queda vinculado a la señal activa. Las capas adicionales generan órdenes pendientes registradas como “legs límite” esperados.

8.4 En cada tick, el servicio de ejecución reconstruye posiciones y órdenes del bróker y trata de emparejarlas con los legs de la señal (por ticket, capa de grid y paso de TP).

8.5 Cuando un leg se ejecuta o la orden pendiente sigue vigente, la señal lo marca como cumplido. Si todos los legs esperados se completan, la señal se limpia sola.

8.6 Si una señal se queda sin posiciones de mercado pero todavía existen órdenes pendientes (por ejemplo, la entrada falló o se canceló manualmente), el sistema marca `cascade_pending` y procede a cancelar esos límites.

8.7 Tras limpiar la cascada, el servicio actualiza sus snapshots internos para que el panel refleje la exposición real (volúmenes, resúmenes del scope, elegibilidad de break-even).

## 9. Persistencia

9.1 El EA guarda por gráfico: posición del panel, tamaño, tema, multiplicador TP, preferencia de grid y estado del scope, en `Common\Files\SniperAdvancedPanel\state`.

9.2 Los valores de riesgo persisten para reutilizarlos en la siguiente proyección.

9.3 La persistencia de proyección incluye: puntos ATR, puntos ATR usados y el precio aplicado de ATR (`ATRAppliedPrice`).

## Notas sobre anclaje ATR y cambios de timeframe
- Los puntos ATR se calculan con `iATR` en el timeframe actual; no se reescalan por el precio aplicado. El precio aplicado se usa como ancla para posicionar las distancias iniciales de SL/TP.
- Al cambiar de timeframe, el SL/TP se re‑siembra desde el ATR del TF actual solo si el usuario no los movió manualmente (flags custom). Así se preservan niveles manuales al cambiar de TF.
- Todos los niveles respetan los mínimos de distancia del broker al re‑anclar.
