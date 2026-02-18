# Addon - Structure Compound Context: Trend Ride

## Product
- Name: `Compound Mode - Trend Ride`
- Type: `Addon`
- SKU: `addon_compound_trend_ride`

## description
Trend Ride is a compound context addon for continuation behavior. It is intended for users who want the EA to align with existing trend direction and avoid random counter-move entries.

For non-traders: this mode tells the EA to prefer "go with the moving flow" behavior instead of early reversal attempts.

## Included Modes
- `COMPOUND_MODE_TREND_RIDE_BUY`
- `COMPOUND_MODE_TREND_RIDE_SELL`

One purchase includes both BUY and SELL sides.

## Inputs Explained (Pattern)
- `Base_Structure_Compound_Filter`: selects the Trend Ride buy/sell mode.
- `Base_Fresh_Structure_Time`: requires fresher market structure timing (stricter entry quality).

## How This Pattern Is Built
1. The EA confirms a clear directional structure (up-sequence or down-sequence).
2. It waits for a controlled pullback that does not break that structure.
3. It enters when direction resumes, aiming to continue the existing move.
4. With freshness enabled, only recent structure transitions are accepted.

## Canonical Structure Sequence (Oldest -> Newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_TREND_RIDE_BUY`):
  `[4] Higher High -> [3] Higher Low -> [2] Higher High -> [1] Higher Low`
- Sell mode (`COMPOUND_MODE_TREND_RIDE_SELL`):
  `[4] Lower Low -> [3] Lower High -> [2] Lower Low -> [1] Lower High`

## Recommended Starter Setup
- `Base_Structure_Compound_Filter = COMPOUND_MODE_TREND_RIDE_BUY` or `COMPOUND_MODE_TREND_RIDE_SELL`
- `Base_Fresh_Structure_Time = false`

## Access Rule
- Entitlement required when Trend Ride mode is selected.

## If Addon Is Missing
- EA blocks startup with a missing-addon message.
