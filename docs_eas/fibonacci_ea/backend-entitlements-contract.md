# Backend Entitlements Contract

This document defines the expected API contract for addon entitlements used by the EA.

## Endpoint
- Method: `POST`
- URL: `http://45.154.34.26/api/v1/licenses/verify`
- Content-Type: `application/json`

## Request payload
Required fields:
- `source` string
- `email` string
- `ea_id` string
- `license_key` string
- `broker_account` object

Optional field:
- `addons` string (CSV of currently requested addons from active inputs)

Broker account object fields:
- `name` string
- `company` string
- `account_number` number
- `account_type` string (`real`, `demo`, `testing`, or `unknown`)

Example request:
```json
{
  "source": "trading_sniper_floor",
  "email": "user@example.com",
  "ea_id": "sniper_advanced_panel",
  "license_key": "ENCRYPTED_KEY",
  "addons": "addon_session_time_filter,addon_compound_trend_ride",
  "broker_account": {
    "name": "John Doe",
    "company": "Broker Ltd",
    "account_number": 12345678,
    "account_type": "real"
  }
}
```

## Success response contract
Required fields on every success verify:
- `ok` boolean, must be `true`
- `expires_at` number (unix timestamp in seconds)
- `granted_addons` array of strings, always present (use `[]` when none)

Optional fields:
- `trial` boolean
- `plan_interval` string
- `broker_account` object mirror for sync status

Example success response:
```json
{
  "ok": true,
  "expires_at": 1769990400,
  "granted_addons": [
    "addon_session_time_filter",
    "addon_grid_strategy_config",
    "addon_compound_trend_ride"
  ],
  "trial": false,
  "plan_interval": "monthly",
  "broker_account": {
    "name": "John Doe",
    "company": "Broker Ltd",
    "account_number": 12345678,
    "account_type": "real"
  }
}
```

## Failure response contract
Recommended fields:
- `ok` boolean `false`
- `error` string code
- HTTP non-2xx status

Common error codes used by EA logic:
- `invalid_source`
- `invalid_key`
- `addons_required`
- `trial_disabled`
- `invalid_granted_addons`
- `invalid_expires_at`

Example failure response:
```json
{
  "ok": false,
  "error": "addons_required"
}
```

## Backend checklist
- Return `granted_addons` on every verify response.
- Normalize addon keys to lowercase snake-case before returning.
- Do not infer grants from request `addons`; always compute grants from server-side entitlements.
- Keep `expires_at` strictly greater than current unix time for valid licenses.
- Return a stable explicit list even if empty (`[]`) to avoid EA-side parse failure.
- Preserve 24h refresh compatibility: EA revalidates daily and removes itself on failure.

## Addon keys (server source of truth)
- `addon_session_time_filter`
- `addon_grid_strategy_config`
- `addon_candle_structure`
- `addon_compound_trend_ride`
- `addon_compound_pullback_continue`
- `addon_compound_reversal_early`
- `addon_compound_breakout_ready`
- `addon_compound_volatility_trap`

## Strategy Tester behavior
- Tester mode cannot rely on WebRequest in optimization flows.
- EA bypasses addon entitlement checks in tester mode.
- EA key decryption and key expiry checks still apply in tester mode.
