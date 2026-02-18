# Addon - Structure Compound Context: Breakout Ready

## Product
- Name: `Compound Mode - Breakout Ready`
- Type: `Addon`
- SKU: `addon_compound_breakout_ready`

description
Breakout Ready is designed for users who prefer expansion moments instead of retracement entries. It helps align entries with potential range exits and directional acceleration.

For non-traders: this mode looks for situations where price may "break out" of a box and start moving faster.

## Included Modes
- `COMPOUND_MODE_BREAKOUT_READY_BUY`
- `COMPOUND_MODE_BREAKOUT_READY_SELL`

One purchase includes both BUY and SELL sides.

## Inputs Explained (Pattern)
- `Base_Structure_Compound_Filter`: selects Breakout Ready buy/sell mode.
- `Base_Fresh_Structure_Time`: applies stricter timing freshness when enabled.

## How This Pattern Is Built
1. The EA identifies a compressed range with clear upper and lower boundaries.
2. It tracks pressure buildup from repeated tests near one edge.
3. It validates breakout acceptance outside the range.
4. It enters in breakout direction while structure remains aligned.

## Canonical Structure Sequence (Oldest -> Newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_BREAKOUT_READY_BUY`):
  `[4] Higher Low -> [3] Lower High -> [2] Higher Low -> [1] Lower High`
- Sell mode (`COMPOUND_MODE_BREAKOUT_READY_SELL`):
  `[4] Lower High -> [3] Higher Low -> [2] Lower High -> [1] Higher Low`

## Recommended Starter Setup
- `Base_Structure_Compound_Filter = COMPOUND_MODE_BREAKOUT_READY_BUY` or `COMPOUND_MODE_BREAKOUT_READY_SELL`
- `Base_Fresh_Structure_Time = false`

## Access Rule
- Entitlement required when Breakout Ready mode is selected.

## If Addon Is Missing
- EA blocks startup with a missing-addon message.
