# Backend Entitlements + Daily Results Contract

This document is the source of truth for current EA-to-API integration.

## Base URL and endpoints
- Base URL: `http://45.154.34.26/api/v1`
- `POST /licenses/verify`
- `POST /licenses/heartbeat`
- `POST /broker_accounts/daily_results`
- Content-Type for all endpoints: `application/json`

## Shared request fields
Required for all endpoints:
- `source` string
- `email` string
- `ea_id` string
- `license_key` string
- `broker_account` object

`broker_account` fields:
- `company` string (required)
- `account_number` integer (required)
- `account_type` string (required, `real` or `demo`)
- `name` string (optional for `verify`/`heartbeat`, ignored by `daily_results`)

Example shared payload fragment:
```json
{
  "source": "trading_sniper_floor",
  "email": "user@example.com",
  "ea_id": "fibonacci_elite",
  "license_key": "ENCRYPTED_KEY",
  "broker_account": {
    "company": "Broker Ltd",
    "account_number": 12345678,
    "account_type": "real"
  }
}
```

## `POST /licenses/verify`
Purpose:
- Validate license.
- Validate required add-ons.
- Allocate/refresh online seat lease.
- Upsert broker account identity binding.

Additional request fields:
- `addons` string (optional CSV of requested add-on keys)

Success (`200 OK`) response:
- `ok` boolean (`true`)
- `expires_at` integer (unix seconds)
- `granted_addons` array (always present, can be `[]`)
- `trial` boolean
- `plan_interval` string or null
- `broker_account` object (echo of server-side account identity)

Example success:
```json
{
  "ok": true,
  "expires_at": 1769990400,
  "granted_addons": ["addon_session_time_filter"],
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

Known errors:
- `401`: `invalid_source`, `invalid_key`, `trial_disabled`, `addons_required`
- `404`: `user_not_found`, `ea_not_found`, `license_not_found`
- `422`: `invalid_payload`, `expired`
- `429`: `rate_limited`, `online_limit_reached`
- `500`: `internal_error`

## `POST /licenses/heartbeat`
Purpose:
- Refresh online seat lease only (no add-on validation).
- Keep session active using timer-driven pings.

Success (`200 OK`) response:
- `ok` boolean (`true`)
- `expires_at` integer (unix seconds)
- `trial` boolean
- `plan_interval` string or null
- `broker_account` object (if upsert/find succeeds)

Known errors:
- `401`: `invalid_source`, `invalid_key`, `trial_disabled`
- `404`: `user_not_found`, `ea_not_found`, `license_not_found`
- `422`: `invalid_payload`, `expired`
- `429`: `rate_limited`, `online_limit_reached`
- `500`: `internal_error`

## `POST /broker_accounts/daily_results`
Purpose:
- Persist one broker account daily result entry per UTC day.
- Independent from online seat allocation logic.

Additional required fields:
- `result_timestamp` integer unix seconds (`> 0`)
- `result_value` decimal string/number (max 2 decimals)

Rules:
- Broker account must already exist and belong to the verified license identity.
- Duplicate entries for the same broker account on the same UTC day are rejected.

Example request:
```json
{
  "source": "trading_sniper_floor",
  "email": "user@example.com",
  "ea_id": "fibonacci_elite",
  "license_key": "ENCRYPTED_KEY",
  "broker_account": {
    "company": "Broker Ltd",
    "account_number": 12345678,
    "account_type": "real"
  },
  "result_timestamp": 1736942400,
  "result_value": "10.50"
}
```

Success (`201 Created`) response:
- `ok` boolean (`true`)
- `broker_account_id` integer
- `result_on` string (UTC date `YYYY-MM-DD`)
- `result_value` string with 2 decimals

Example success:
```json
{
  "ok": true,
  "broker_account_id": 42,
  "result_on": "2025-01-15",
  "result_value": "10.50"
}
```

Known errors:
- `401`: `invalid_source`, `invalid_key`, `trial_disabled`
- `404`: `user_not_found`, `ea_not_found`, `license_not_found`, `broker_account_not_found`
- `409`: `already_recorded`
- `422`: `invalid_payload`, `expired`
- `500`: `internal_error`

## Online seat policy summary
- Lease TTL: 15 minutes.
- Recommended EA heartbeat cadence: every 3 minutes (`OnTimer`).
- Subscription seats: shared across all EAs for the user.
- One-time seats: independent per EA (`+8` cap when entitled).
- Identity dedupe key: `user + ea + company + account_number + account_type`.
- Same identity on multiple charts counts as one seat.

## EA Efficiency Guard Plan (Required)
Goal: avoid duplicated `verify` and `heartbeat` requests when the same license identity is attached on many charts.

Guard identity key:
- `source + email + ea_id + company + account_number + account_type`

Rules:
- Use a leader/follower model per guard identity key.
- Exactly one chart instance (leader) sends API requests.
- Followers never send `verify`/`heartbeat` while leader is healthy.
- Leader sends heartbeat every 3 minutes and full verify every 24 hours.
- If leader is stale for more than 6 minutes (2 heartbeat cycles), followers may elect a new leader.
- On identity change (`company`/`account_number`/`account_type`), reevaluate leadership before sending.
- Share latest auth state locally per identity: `last_success_at`, `last_error`, `expires_at`, `online_limit_reached`.
- Retries/backoff must remain single-sender; followers must not run parallel retries.

Acceptance criteria:
- With N charts using the same identity, outbound API traffic behaves like 1 chart.
- Seat counting remains stable (`+1` per identity), regardless of chart count.
- No request storms during reconnects or temporary network failures.

## Add-on keys (server source of truth)
- `addon_session_time_filter (299$)`
- `addon_grid_strategy_config (299$)`
- `addon_candle_structure (299$)`
- `addon_compound_trend_ride (299$)`
- `addon_compound_pullback_continue (199$)`
- `addon_compound_reversal_early (199$)`
- `addon_compound_breakout_ready (299$)`
- `addon_compound_volatility_trap (199$)`

## Strategy Tester behavior
- Tester mode cannot rely on WebRequest in optimization flows.
- EA bypasses add-on entitlement checks in tester mode.
- EA key decryption and key expiry checks still apply in tester mode.
