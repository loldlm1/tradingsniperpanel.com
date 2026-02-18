# Addon - Structure Compound Context: Pullback Continue

## Product
- Name: `Compound Mode - Pullback Continue`
- Type: `Addon`
- SKU: `addon_compound_pullback_continue`

## description
Pullback Continue focuses on re-entry after a temporary correction in price movement. It is useful for users who want continuation behavior with pullback timing rather than immediate breakout entries.

For non-traders: this mode waits for a short "step back" before trying to continue in the original direction.

## Included Modes
- `COMPOUND_MODE_PULLBACK_CONTINUE_BUY`
- `COMPOUND_MODE_PULLBACK_CONTINUE_SELL`

One purchase includes both BUY and SELL sides.

## Inputs Explained (Pattern)
- `Base_Structure_Compound_Filter`: selects Pullback Continue buy/sell mode.
- `Base_Fresh_Structure_Time`: enables stricter freshness timing for structure context.

## How This Pattern Is Built
1. The EA identifies an impulse move in one direction.
2. It marks a pullback area where retracement is still healthy.
3. It checks that structure is not broken during the pullback.
4. It enters when momentum rotates back to continuation.

## Canonical Structure Sequence (Oldest -> Newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_PULLBACK_CONTINUE_BUY`):
  `[4] Lower High -> [3] Lower Low -> [2] Higher High -> [1] Higher Low`
- Sell mode (`COMPOUND_MODE_PULLBACK_CONTINUE_SELL`):
  `[4] Higher Low -> [3] Higher High -> [2] Lower Low -> [1] Lower High`

## Recommended Starter Setup
- `Base_Structure_Compound_Filter = COMPOUND_MODE_PULLBACK_CONTINUE_BUY` or `COMPOUND_MODE_PULLBACK_CONTINUE_SELL`
- `Base_Fresh_Structure_Time = false`

## Access Rule
- Entitlement required when Pullback Continue mode is selected.

## If Addon Is Missing
- EA blocks startup with a missing-addon message.
