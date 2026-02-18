# Addon - Time Filter Session Manager

## Product
- Name: `Time Filter Session Manager`
- Type: `Addon`
- SKU: `addon_session_time_filter`

## description
`This addon gives you scheduling control. You decide in which market sessions the EA can run and when it should stop opening positions. It is useful for users who want to avoid low-liquidity or high-noise hours.`

`For non-traders: this is like setting business hours for your bot. Outside those hours, it can pause or close positions depending on your selected mode.`

## Inputs Explained (Plain Language)
- `Session_Asia_Filter_Mode`: behavior for Asia session (`OFF`, `ALLOW_RUN`, or `FORCE_CLOSE`).
- `Session_Asia_Filter_Time_Range`: Asia time window in `HH:MM-HH:MM`.
- `Session_London_Filter_Mode`: behavior for London session.
- `Session_London_Filter_Time_Range`: London time window.
- `Session_NewYork_Filter_Mode`: behavior for New York session.
- `Session_NewYork_Filter_Time_Range`: New York time window.

## Recommended Starter Setup
- `Session_Asia_Filter_Mode = SESSION_FILTER_OFF`
- `Session_London_Filter_Mode = SESSION_FILTER_ALLOW_RUN`
- `Session_London_Filter_Time_Range = 07:00-12:00`
- `Session_NewYork_Filter_Mode = SESSION_FILTER_ALLOW_RUN`
- `Session_NewYork_Filter_Time_Range = 12:00-20:00`

## Access Rule
- Entitlement required if any session mode is different from `SESSION_FILTER_OFF`.

## If Addon Is Missing
- EA blocks startup and shows missing-addon details on chart.
