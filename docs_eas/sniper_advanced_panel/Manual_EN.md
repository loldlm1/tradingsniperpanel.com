# Sniper Advanced Panel – Trader Manual (EN)

## Contents
1. [Panel Overview](#1-panel-overview)
2. [Buttons and Hotkeys](#2-buttons-and-hotkeys)
3. [Sniper Scope Workflow](#3-sniper-scope-workflow)
4. [Keyboard-Only Shortcuts](#4-keyboard-only-shortcuts)
5. [Theme Options](#5-theme-options)
6. [Customizing Hotkeys and Button Colors](#6-customizing-hotkeys-and-button-colors)
7. [Input Parameters (EA Inputs)](#7-input-parameters-ea-inputs)
8. [Projection → Signal → Positions → Limits Cascade](#8-projection--signal--positions--limits-cascade)
9. [Persistence](#9-persistence)

## 1. Panel Overview

1.1 The panel anchors to the chart corner selected in the Expert Advisor (EA) inputs. Drag it by the header to reposition or use the size button to switch between compact, standard, or large layouts. The header remains draggable even when the panel is minimized, and the movement updates every 16 ms for smooth feedback.

1.2 The risk box (bottom of the grid) lets you define the position size context before launching a projection. It includes:

  - **Mode selector** (`Lot`, `%`, `$`) – cycles by clicking the selector; the suffix label updates automatically.
  - **Value field** – accepts numeric input only; invalid characters are filtered. Values are clamped to broker limits (minimum/maximum lot size, 0.01–100% risk, 0–1,000,000 USD) and normalized to two decimals.
  - **Validation feedback** – when the EA adjusts your entry (e.g., to the symbol lot step) the confirmation tooltip shows the reason.

1.3 The status strip above the grid highlights the active direction button, TP multiplier, split, grid depth, and any pending confirmation.

1.4 If the EA recompiles or reinitializes while the panel is collapsed, expanding it rebuilds all buttons and tooltips automatically.

1.5 The **Stochastic Structure mini panel** floats on the chart using the same smooth drag behaviour as the main panel. It displays, per timeframe:
  - Support (`▲`) and resistance (`▼`) touch highlights with live counts.
  - The %K stochastic value plus trend and K/D relationship dots (blue when %K > %D, amber otherwise).
  - Active zone and retest counters so you can quickly spot stacked levels.
You can drag the mini panel by any area; it auto-adapts to the current theme and can be extended with additional indicator rows in the future.

## 2. Buttons and Hotkeys
Pressing a button flashes it and triggers the same action as the default hotkey. When a confirmation tooltip appears, press **Enter** or click the same button again to execute, or press **Esc** to cancel.

**Responsive labels.** Button text adapts to panel width so medium and compact layouts remain clear. `{pct}` in the table below resolves to the configured partial-close percent (e.g., `33%`).

| Button ID | Full layout (Title / Subtitle) | Standard layout (Title / Subtitle) | Compact layout (Title / Subtitle) |
|-----------|--------------------------------|------------------------------------|-----------------------------------|
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

### Cycle navigator for management actions
- Applies to partial/full closes, Set BreakEven and Sniper Scope. The first press targets **All signals**; subsequent presses or hotkeys walk through each signal, then individual positions and pending limits.
- The tooltip shows the active cycle summary (e.g., `Cycle BUY 2/5 • P1/L0 • Signal #2`). Use it as a guide before confirming.
- Targeted tickets are marked on the chart with a neutral deep-blue HLINE so you can see exactly which entries will be closed or adjusted.
- Press **Enter** (or click, when the tooltip allows it) to confirm; press **Esc** to cancel. Changing to another action resets the previous cycle and highlight.

2.1 **Partial Close BUY** (`Q` default)
  - Closes only a percentage of BUY positions (panel input `panel_partial_close_percent`, default 33%).
  - First press opens a confirmation with projected volume and P/L; confirm to send the order.
  - Press again (or use the hotkey) to advance the BUY cycle: all signals → each signal → each position → each pending limit. The highlighted HLINE shows which entries will be trimmed.

2.2 **Partial Close SELL** (`W` default)
  - Same as 2.1 but for SELL positions.
  - The SELL cycle follows the same order and highlight, letting you target one SELL signal/leg at a time before looping back to ALL.

2.3 **Close BUY FULL** (`E` default)
  - Schedules a confirmation to close 100% of BUY exposure.
  - Cycle behaviour matches 2.1, so you can exit everything or step down to a single BUY ticket before confirming.

2.4 **Close SELL FULL** (`R` default)
  - Mirrors 2.3 for SELL positions.
  - Repeated presses walk through the SELL cycle; the tooltip keeps the current summary in sync.

2.5 **Split Positions** (`A` default)
  - Toggles multi-leg projections. When active, market entries split volume across TP1…TPx instead of one target.
  - Preference persists between projections; toggle off to revert to single-leg behaviour.

2.6 **TP X1** (`S` default)
  - Sets TP multiplier to 1R (baseline). Updates an active projection instantly.

2.7 **TP X2** (`D` default)
  - Applies 2R take-profit laddering.

2.8 **TP X3** (`F` default)
  - Applies 3R take-profit laddering.

2.9 **GRID L** (`Z` default)
  - Enables/disables grid mode. When on, at least two layers are prepared.

2.10 **GRID X2** (`X` default)
  - Forces grid depth to 2 layers and persists the choice.

2.11 **GRID X3** (`C` default)
  - Forces grid depth to 3 layers.

2.12 **OPEN BUY** (Arrow Up default)
  - Starts or cancels a BUY projection. If one is already active, pressing again cancels it.
  - Applies the selected TP multiplier, split preference, and grid plan.

2.13 **SET BE** (`Space` default)
  - Moves stop-losses of all managed positions to break-even when price allows.
  - Cycle through signals/legs exactly like the close buttons; only the highlighted tickets are protected when you confirm.

2.14 **SCOPE SELL** (`G` default)
  - Activates Sniper Scope with SELL focus. Use it to align SELL-side SL/TP levels with the crosshair.
  - Pressing the button/hotkey again advances the SELL scope cycle (signal → position → limit). The scope tooltip mirrors the cycle summary and the chart highlights the active tickets.

2.15 **SCOPE BUY** (`H` default)
  - Same as 2.14 for BUY positions.
  - BUY scope cycling behaves identically, and pressing another management action cancels scope and transfers the highlight to the new target.

2.16 **OPEN SELL** (Arrow Down default)
  - Starts or cancels a SELL projection with current TP/split/grid preferences.

## 3. Sniper Scope Workflow

3.1 Activate **SCOPE SELL** (2.14) or **SCOPE BUY** (2.15). A crosshair plus info card appears; focus limits adjustments to that side.

3.2 Move the mouse to pick the target price. The info card summarizes volume, weighted TP/SL distance, and projected profit.

3.3 Click the chart to lock the price. Press **Enter** to commit the new TP/SL, or **Esc** to exit without changes.

3.4 While scope is active the panel buttons stay disabled except the selected scope button, preventing accidental actions. Starting any other management action cancels scope automatically and reuses the shared cycle tooltip.

## 4. Keyboard-Only Shortcuts

4.1 **Enter** – confirms pending partial-close tooltips or commits an active projection / scope selection.

4.2 **Esc** – cancels confirmations, projections, or Sniper Scope.

4.3 **Theme toggle key** (default `U`) – switches between dark/light instantly.

## 5. Theme Options

5.1 The EA stores the last used theme per chart and reloads it on startup.

5.2 Toggle the theme with the key defined by the input `theme_toggle_key` (default `U`).

5.3 Hotkey theme persistence: `theme_dark` input sets the initial mode; per-chart choice is saved in the persistence file.

5.4 Canvas, panel, projection lines, and Sniper Scope recolor automatically when the theme changes.

## 6. Customizing Hotkeys and Button Colors

6.1 Attach the EA once so it creates the default configuration files under `File → Open Data Folder → MQL5 → Profiles → Templates…` then navigate to `Terminal\Common\Files\SniperAdvancedPanel\config`.

6.2 Locate the file named `<SYMBOL>_<ChartID>_panel.ini` (e.g., `EURUSD_123456_panel.ini`).

6.3 Under `[Hotkeys]`, assign tokens such as `Q`, `1`, `ArrowUp`, or `Space`. Arrow directions must be written as `ArrowUp/Down/Left/Right`.

6.4 Under `[Colors]`, each line accepts five hex values: `background, hover, active, border_default, border_active`. Example:
```
OPEN_BUY=#059669,#047857,#065F46,#1E293B,#0F172A
```

6.5 Save the file and reload the EA (switch timeframe or reattach) to apply the overrides.

6.6 If a key or color entry is missing, the EA falls back to its Tailwind-themed defaults.

## 7. Input Parameters (EA Inputs)

7.1 **Panel placement**
  - `panel_x`, `panel_y` – offset in pixels from the selected corner.
  - `panel_width`, `panel_height` – initial size; cycling size mode can override width.
  - `panel_corner` – anchor corner.
  - `panel_partial_close_percent` – percentage used by partial-close buttons (clamped 1–99%).

7.2 **Hotkeys & Theme**
  - `hk_prefer_numpad` – forces numeric keypad when autodetect is off.
  - `hk_auto_detect` – switches between top row/numpad based on the last key pressed.
  - `theme_dark` – default theme at startup.
  - `theme_toggle_key` – ASCII character used to toggle themes (default `'U'`).

7.3 **Projection**
  - `use_canvas_projection` – draws gradient canvas overlays.
  - `projection_use_native_labels` – use broker labels instead of custom ones.
  - `canvas_projection_width`, `canvas_position_mode`, `canvas_x_offset_px`, `canvas_margin_right_px` – control canvas placement.
  - `proj_ATR_Period`, `proj_ATR_Multiplier` – ATR-based SL seed for projections. Default multiplier is 2.0.
  - `proj_ATR_AppliedPrice` – applied price used to anchor ATR-based SL/TP: one of `PRICE_CLOSE`, `PRICE_OPEN`, `PRICE_HIGH`, `PRICE_LOW`, `PRICE_MEDIAN`, `PRICE_TYPICAL` (default), `PRICE_WEIGHTED`.
  - `proj_Gradient_Steps` – number of gradient bands in the canvas.
  - `proj_grid_enable_default` – enables grid by default on new projections.
  - `proj_grid_factor_l2`, `proj_grid_factor_l3` – volume multipliers for grid layers 2 and 3.

7.4 **Debug Canvas** (use only for diagnostics)
  - `dbg_canvas_logs` – verbose console logs for draw events.
  - `dbg_canvas_flat_colors` – disables gradient for troubleshooting.
  - `dbg_canvas_color_diagnostics` – draws RGB strips to validate channel integrity.
  - `dbg_canvas_overlap_scan` – reports overlapping chart objects.
  - `dbg_canvas_force_palette_test` – forces red/green palette for visual tests.
  - `dbg_canvas_auto_palette_dump` – dumps palette snapshot when drawing.

7.5 **Stochastic Structure S&R and Mini Panel**
  - `InpStoch_KPeriod`, `InpStoch_DPeriod`, `InpStoch_Slowing`, `InpStoch_PriceMode` – native stochastic parameters forwarded to the S/R micro-service.
  - `InpStoch_MinRetestsForZoneDraw` – minimum number of retests required before painting a zone on the chart (default `1`).
  - `InpStoch_MaxRetestsPerZone` – caps the number of retests counted for a zone; anything above the limit is ignored by the drawer and mini panel (default `6`).
  - `InpStoch_PanelTF1` … `InpStoch_PanelTF4` – timeframes tracked by the mini panel (defaults `M1`, `M5`, `M15`, `H1`). Metrics refresh once per minute and when the underlying structure updates. Support/resistance touches use candle highs/lows from the latest two bars to confirm zone interaction.

## 8. Projection → Signal → Positions → Limits Cascade

8.1 Starting a projection (2.12 or 2.16) builds a **signal** that captures direction, entry price, SL/TP targets, chosen TP multiplier, split flag, and grid depth.

8.2 The EA calculates required volume from the risk box (1.2) and broker limits, then allocates it per grid layer and TP leg.

8.3 For each market leg, the EA places an immediate order and links its ticket to the active signal. For additional grid layers it places pending orders and registers them as expected “limit legs”.

8.4 On every tick, the execution service rebuilds the list of broker positions/orders and tries to match them with signal legs (by ticket, grid layer, and TP step).

8.5 When a leg is filled or a pending order still exists, the signal marks it as matched. If all expected legs are satisfied the signal clears automatically.

8.6 If a signal loses all market positions but pending orders are still working (e.g., entry failed or was cancelled manually), the system flags `cascade_pending` and proceeds to cancel the leftover limits.

8.7 After cascade cleanup, the service refreshes its internal snapshots so the panel reflects the current exposure (volumes, scope summaries, break-even eligibility).

## 9. Persistence

9.1 The EA saves panel placement, size, theme, TP multiplier, grid preference, and scope settings per chart under `Common\Files\SniperAdvancedPanel\state`.

9.2 Risk input values persist so the next projection reuses the last valid entry.

9.3 Projection-specific persistence includes ATR points, ATR used points, and the ATR applied price (`ATRAppliedPrice`).

## Notes on ATR anchoring and timeframe changes
- ATR points are computed from `iATR` on the current timeframe; they are not rescaled by the applied price. The applied price is used as an anchor to position the initial SL/TP distances.
- On timeframe changes, SL/TP are re-seeded from current TF ATR only if the user has not moved SL/TP manually (custom flags). This preserves manual levels across TF switches.
- All levels respect broker stop levels when re-anchoring.
