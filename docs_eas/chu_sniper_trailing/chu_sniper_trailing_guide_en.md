# Chu Sniper Trailing

## Purpose

Chu Sniper Trailing is a chart-scoped MetaTrader 5 position manager for manual
and scalping workflows. It manages the symbol of the chart where it is
attached. Attach another instance to another symbol when that is intentional.
It is not a signal generator and it does not invent entries or strategy rules.

## Before you start

- Use one authoritative position manager per symbol.
- Confirm the broker, account type, stop-distance, freeze-level, and volume
  rules before using live funds.
- The EA adopts open positions for the attached symbol, including manual and
  positions opened by another EA. Do not attach competing managers to the same
  symbol unless their interaction is understood.
- The EA requires a valid subscription license. There is no trial for this
  product.

## Attach and license

1. Open the symbol chart to manage.
2. Attach `Chu_Sniper_Trailing`.
3. Enter the license key in `EA_License_Key`.
4. Wait for the status to show `ACTIVE`.
5. Configure the panel before opening or adopting a new position.

The license service verifies `chu_sniper_trailing` with the backend. It uses
the shared verify and heartbeat protocol, and the backend supplies the runtime
magic number. Daily-results reporting is not part of this product.

## Panel controls

- `SL / Trail (pts)`: initial stop distance and one risk unit (`1R`).
- `Risk (%)`: independent balance risk allocation for each source position.
- `TP Multiple (R)`: fixed take-profit distance; `0` means no broker TP.
- `Calculated Lot`: broker-aware preview; the order is recalculated before it
  is sent.
- `Market SELL` and `Market BUY`: immediate market actions after safety checks.
- `Trailing ON/OFF`: enables future staircase advancement. Turning it off does
  not remove an existing protective stop or loosen it.

## Protection and trailing

For a BUY, the initial stop is one `R` below the confirmed broker entry. For a
SELL, it is one `R` above. The fixed staircase is:

- `1R -> break even`
- `2R -> +1R`
- `3R -> +2R`, continuing without a level cap

Stops are monotonic. The EA reselects and verifies the exact position before a
broker modification and respects broker stop/freeze constraints. Temporary
broker conditions may retry in a bounded way; invalid risk, margin, license,
or permission failures remain blocked.

## Safe-use notes

This tool can modify positions created outside the EA on the current symbol.
It does not close all positions, create pending orders, reverse trades, or
manage another chart symbol. Use a demo account to confirm broker behavior,
volume steps, slippage, and protection distances before live deployment.
