# Addon - Candle Structure Filter

## Product
- Name: `Candle Structure Filter`
- Type: `Addon`
- SKU: `addon_candle_structure`

## description
This addon adds a pre-entry validation layer based on candle structure behavior. It helps users filter signals so entries happen only when recent candle patterns match the selected condition.

For non-traders: this is a quality gate. The EA checks "does the recent candle behavior look like what we want?" If not, the trade is skipped.

## Inputs Explained (Plain Language)
- `Candle_Timeframe`: timeframe used for candle-pattern checks.
- `Candle_Strategy_Type`: selected candle filter mode (`OFF`, shrinked, expanded, bullish, bearish).
- `Candle_Strategy_Shift`: how many bars back to compare.
- `Candle_Strategy_Depth`: number of bars used for the check.

## Recommended Starter Setup
- `Candle_Timeframe = PERIOD_M15`
- `Candle_Strategy_Type = SHRINKED_CANDLE_STRUCTURE`
- `Candle_Strategy_Shift = 1`
- `Candle_Strategy_Depth = 1`

## Access Rule
- Entitlement required when `Candle_Strategy_Type != OFF_CANDLE_STRUCTURE`.

## If Addon Is Missing
- EA blocks startup when a non-OFF candle mode is selected.
