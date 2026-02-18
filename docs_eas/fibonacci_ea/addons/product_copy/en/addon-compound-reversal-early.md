# Addon - Structure Compound Context: Reversal Early

## Product
- Name: `Compound Mode - Reversal Early`
- Type: `Addon`
- SKU: `addon_compound_reversal_early`

## description
Reversal Early is built for users who want to capture potential turning points before a full trend confirmation appears. It can unlock earlier entries, but usually needs tighter risk discipline.

For non-traders: this mode tries to catch "the turn" earlier, instead of waiting for full confirmation.

## Included Modes
- `COMPOUND_MODE_REVERSAL_EARLY_BUY`
- `COMPOUND_MODE_REVERSAL_EARLY_SELL`

One purchase includes both BUY and SELL sides.

## Inputs Explained (Pattern)
- `Base_Structure_Compound_Filter`: selects Reversal Early buy/sell mode.
- `Base_Fresh_Structure_Time`: increases strictness for signal freshness.

## How This Pattern Is Built
1. The EA detects signs of trend exhaustion.
2. It confirms a first meaningful structure break in the opposite direction.
3. It validates the first opposite swing sequence.
4. It triggers earlier than conservative reversal methods, so risk should be tighter.

## Canonical Structure Sequence (Oldest -> Newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_REVERSAL_EARLY_BUY`):
  `[4] Lower High -> [3] Lower Low -> [2] Lower High -> [1] Higher Low`
- Sell mode (`COMPOUND_MODE_REVERSAL_EARLY_SELL`):
  `[4] Higher Low -> [3] Higher High -> [2] Higher Low -> [1] Lower High`

## Recommended Starter Setup
- `Base_Structure_Compound_Filter = COMPOUND_MODE_REVERSAL_EARLY_BUY` or `COMPOUND_MODE_REVERSAL_EARLY_SELL`
- `Base_Fresh_Structure_Time = false`

## Access Rule
- Entitlement required when Reversal Early mode is selected.

## If Addon Is Missing
- EA blocks startup with a missing-addon message.
