# Addon - Structure Compound Context: Volatility Trap

## Product
- Name: `Compound Mode - Volatility Trap`
- Type: `Addon`
- SKU: `addon_compound_volatility_trap`

## description
`Volatility Trap is for users who want a defensive compound mode in unstable or noisy conditions. It is intended to reduce low-quality entries when price behavior is erratic.`

`For non-traders: this mode is a caution profile for "chaotic" market moments.`

## Included Modes
- `COMPOUND_MODE_VOLATILITY_TRAP_BUY`
- `COMPOUND_MODE_VOLATILITY_TRAP_SELL`

One purchase includes both BUY and SELL sides.

## Inputs Explained (Pattern)
- `Base_Structure_Compound_Filter`: selects Volatility Trap buy/sell mode.
- `Base_Fresh_Structure_Time`: enables stricter timing freshness.

## How This Pattern Is Built
1. The EA detects abnormal volatility and possible false breakout behavior.
2. It checks if price quickly returns to prior structure range.
3. It confirms failure of the false-break side.
4. It enters opposite to the failed move once structure stabilizes.

## Canonical Structure Sequence (Oldest -> Newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_VOLATILITY_TRAP_BUY`):
  `[4] Higher High -> [3] Lower Low -> [2] Higher High -> [1] Lower Low`
- Sell mode (`COMPOUND_MODE_VOLATILITY_TRAP_SELL`):
  `[4] Lower Low -> [3] Higher High -> [2] Lower Low -> [1] Higher High`

## Recommended Starter Setup
- `Base_Structure_Compound_Filter = COMPOUND_MODE_VOLATILITY_TRAP_BUY` or `COMPOUND_MODE_VOLATILITY_TRAP_SELL`
- `Base_Fresh_Structure_Time = false`

## Access Rule
- Entitlement required when Volatility Trap mode is selected.

## If Addon Is Missing
- EA blocks startup with a missing-addon message.
