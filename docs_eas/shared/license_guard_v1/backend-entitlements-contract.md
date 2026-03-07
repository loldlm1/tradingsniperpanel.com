# Backend Entitlements + Daily Results Contract

This document is the source of truth for current EA-to-API integration.

## Base URL and endpoints
- Base URL: `https://tradingsniperpanel.com/api/v1`
- `POST /licenses/verify`
- `POST /licenses/heartbeat`
- `POST /broker_accounts/daily_results`
- Content-Type for all endpoints: `application/json`

## Canonical shared service reference
- Canonical EA implementation: `services/shared/license_guard_v1/*`
- Canonical EA entry include:
  - `services/shared/license_guard_v1/license_service.mqh`
- Canonical shared add-on catalog:
  - `services/shared/license_guard_v1/core/addon_catalog.mqh`
- Legacy wrapper files were deprecated and removed during the V1 refactor to avoid duplicated auth paths.
- Cross-repo migrations should reuse this shared service profile pattern and remove legacy local license logic to avoid double-auth behavior.

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
  "ea_id": "pandora_box",
  "license_key": "ENCRYPTED_KEY",
  "broker_account": {
    "company": "Broker Ltd",
    "account_number": 12345678,
    "account_type": "real"
  }
}
```

## Identity model
License guard lane key:
- `source + email + ea_id + company + account_number + account_type`

Notes:
- `ea_id` is mandatory in the lane key because entitlements are EA-specific (`ea_not_found`, add-ons, per-EA one-time seat policy).
- `company/account_number/account_type` are still part of the lane identity and trigger reevaluation when they change.
- Different `ea_id` values in the same MT5 terminal create different lanes and can have different leaders concurrently.

## `POST /licenses/verify`
Purpose:
- Validate license.
- Validate required add-ons.
- Allocate/refresh online seat lease.
- Upsert broker account identity binding.
- Issue or confirm the lane `magic_number` used by trading + daily results.

Additional request fields:
- `addons` string (optional CSV of always-required add-on keys)
- If an EA does not have always-required add-ons, omit `addons` or send empty value.
- Input-driven optional add-ons should be resolved in the EA/shared-service layer and validated against `granted_addons` after successful `verify`; do not send the whole optional addon set in `addons` for multi-chart lanes.
- Always-required add-ons are configured per EA profile (`services/license_service_setup.mqh`), while key normalization/catalog stays shared in `services/shared/license_guard_v1/core/*`.

Success (`200 OK`) response:
- `ok` boolean (`true`)
- `expires_at` integer (unix seconds)
- `granted_addons` array (always present, can be `[]`; shared service uses this for optional/input-driven addon validation after verify)
- `magic_number` integer (`long`, signed-32-bit-safe positive integer, `1..2147483647`, required on every successful verify)
- `trial` boolean
- `plan_interval` string or null
- `broker_account` object (echo of server-side account identity)

Known errors:
- `401`: `invalid_source`, `invalid_key`, `trial_disabled`, `addons_required`
- `404`: `user_not_found`, `ea_not_found`, `license_not_found`
- `422`: `invalid_payload`, `expired`, `missing_magic_number`, `invalid_magic_number`
- `429`: `rate_limited`, `online_limit_reached`
- `500`: `internal_error`

`addons_required` response metadata:
- `required_addons` CSV of all backend-requested always-required add-on keys
- `missing_addons` CSV of the missing subset
- `required_addon_keys` array of all backend-requested always-required add-on keys
- `missing_addon_keys` array of the missing subset
- `missing_addons` / `missing_addon_keys` are the canonical machine-readable fields for shared-service parsing

## `POST /licenses/heartbeat`
Purpose:
- Refresh online seat lease only (no add-on validation).
- Keep session active using timer-driven pings.
- Must not rotate or reissue `magic_number` (EA reuses the latest verified local cache).

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
- Persist one strategy-scoped daily result entry per UTC day.
- Independent from online seat allocation logic.

Additional required fields:
- `magic_number` integer (`long`, signed-32-bit-safe positive integer, `1..2147483647`) from the latest successful `verify` cache
- `result_timestamp` integer unix seconds (`> 0`)
- `result_value` decimal string/number (max 2 decimals)

Rules:
- Broker account must already exist and belong to the verified license identity.
- `magic_number` is required immediately (no compatibility fallback).
- First successful `verify` is allowed to create/assign a new `magic_number`.
- Every later `verify` for the same lane must return the same active `magic_number`.
- If a legacy lane still holds an oversized pre-upgrade value, the first successful `verify` after rollout may reassign that lane to a new supported `magic_number`; EA runtime must always trust the latest successful `verify` response.
- If `verify` fails or returns no valid `magic_number`, EA must fail/remove (no local/random fallback).
- Duplicate entries are rejected for the same uniqueness key:
  - `broker_account + ea_id + magic_number + UTC day`

Example request:
```json
{
  "source": "trading_sniper_floor",
  "email": "user@example.com",
  "ea_id": "pandora_box",
  "license_key": "ENCRYPTED_KEY",
  "broker_account": {
    "company": "Broker Ltd",
    "account_number": 12345678,
    "account_type": "real"
  },
  "magic_number": 490123456,
  "result_timestamp": 1736942400,
  "result_value": "10.50"
}
```

Success (`201 Created`) response:
- `ok` boolean (`true`)
- `broker_account_id` integer
- `result_on` string (UTC date `YYYY-MM-DD`)
- `result_value` string with 2 decimals

Known errors:
- `401`: `invalid_source`, `invalid_key`, `trial_disabled`
- `404`: `user_not_found`, `ea_not_found`, `license_not_found`, `broker_account_not_found`
- `409`: `already_recorded`
- `422`: `invalid_payload`, `expired`, `missing_magic_number`, `invalid_magic_number`
- `500`: `internal_error`

## Online seat policy summary
- Lease TTL: 15 minutes.
- Recommended heartbeat cadence: every 3 minutes (`OnTimer`).
- Recommended full verify cadence: every 24 hours.
- Subscription seats: shared across all EAs for the user.
- One-time seats: independent per EA (`+8` cap when entitled).
- Same lane on multiple charts counts as one seat.
- Fixed guard timing for current EA implementations:
  - Heartbeat interval: `180s`
  - Leader stale timeout: `360s`
  - Full verify interval: `86400s`

## EA license guard protocol (required)
Goal:
- Avoid duplicated `verify` and `heartbeat` requests when multiple charts run the same lane identity.

Rules:
- Use a leader/follower model per lane key.
- Exactly one chart instance (leader) sends `verify`/`heartbeat`.
- Followers never send `verify`/`heartbeat` while leader is healthy.
- Leader updates local shared auth state per lane:
  - `last_success_at`
  - `last_error`
  - `expires_at`
  - `online_limit_reached`
- If leader is stale for more than 6 minutes (2 heartbeat cycles), followers may elect a new leader.
- On identity change (`company`/`account_number`/`account_type`), reevaluate lane key and leadership before sending.
- Retries/backoff must remain single-sender; followers must not run parallel retries.
- `daily_results` reverify requests (`broker_account_not_found`) must be executed by leader only; followers queue a shared reverify request and never call verify directly.

Leader transfer behavior:
- If a leader chart is manually removed, crashes, or stops updating lease heartbeat, another chart in the same lane may take over.
- Takeover happens only inside the same lane key (including same `ea_id`).
- Different lanes (different `ea_id`) run independent leaders and independent heartbeat streams.

## Failure classification policy
Hard auth errors:
- `invalid_source`
- `invalid_key`
- `addons_required`
- `trial_disabled`
- `expired`
- `user_not_found`
- `ea_not_found`
- `license_not_found`
- `missing_magic_number`
- `invalid_magic_number`

Retryable errors:
- `request_failed`
- `rate_limited`
- `online_limit_reached`
- `internal_error`
- temporary `5xx` and network failures

Rules:
- Hard auth errors must not create endless leader-rotation storms.
- Retryable errors use backoff and stay single-sender.
- Missing/invalid `magic_number` is hard-auth and requires EA removal (no fallback).

## Seat conflict policy (`online_limit_reached`)
Startup verify behavior:
- If `POST /licenses/verify` at startup returns `online_limit_reached`, remove only that requester chart.
- Keep other already-online charts/EAs running normally.
- Show a non-technical EN chart message and log the technical error code.

Runtime heartbeat behavior:
- If leader heartbeat returns `online_limit_reached`, do not remove immediately.
- Leader must run immediate `verify` confirmation in the same timer cycle.
- Runtime removal requires 2 consecutive confirmations (`heartbeat + immediate verify`) returning `online_limit_reached`.
- On confirmed runtime conflict, evict the newest claimant for that lane (ordered by successful startup verify time), preserving older active sessions.

Message policy:
- User-facing chart copy remains EN-only for simplicity.
- Recommended chart message:
  - `No license seat is currently available for this EA. Please close another active session or try again shortly.`

## Acceptance criteria
- With N charts on the same lane, outbound license traffic behaves like 1 chart.
- With multiple `ea_id` lanes in the same terminal, each lane keeps one independent leader.
- Leader transfer preserves continuity without forcing all followers to remove.
- No request storms during reconnects or temporary backend failures.
- Daily results remain independent per `ea_id + magic_number`.
- Runtime trading magic is sourced from successful `verify` responses only (no random/local fallback in live mode).
- Runtime trading magic stays within the signed-32-bit-safe positive range expected by the shared service.

## Add-on keys (server source of truth)
- `addon_session_time_filter (299$)`
- `addon_grid_strategy_config (299$)`
- `addon_candle_structure (299$)`
- `addon_compound_trend_ride (299$)`
- `addon_compound_pullback_continue (199$)`
- `addon_compound_reversal_early (199$)`
- `addon_compound_breakout_ready (299$)`
- `addon_compound_volatility_trap (199$)`

## EA add-on entitlement matrix (current)
Fibonacci EA (`ea_id=fibonacci_elite`) current add-on keys:
- `addon_session_time_filter`
- `addon_grid_strategy_config`
- `addon_candle_structure`
- `addon_compound_trend_ride`
- `addon_compound_pullback_continue`
- `addon_compound_reversal_early`
- `addon_compound_breakout_ready`
- `addon_compound_volatility_trap`

Fibonacci/HFT Grid AI integration note:
- These keys are optional/input-driven features, not lane-wide always-required add-ons.
- The EA should keep `LICENSE_SHARED_REQUIRED_ADDONS_CSV=""` unless a future feature becomes universally required.
- The EA should expose the currently active addon keys through `LICENSE_SHARED_COLLECT_REQUESTED_ADDONS`.
- The shared service then compares those requested keys against `granted_addons` after startup/reverify and removes only charts using unowned features.

Pandora Box EA (`ea_id=pandora_box`) current add-on keys:
- None (`LICENSE_SHARED_REQUIRED_ADDONS_CSV=""` in `services/license_service_setup.mqh`)

Sniper Panel EA (`ea_id=sniper_advanced_panel`) current add-on keys:
- None (`LICENSE_SHARED_REQUIRED_ADDONS_CSV=""` in `services/license_service_setup.mqh`)

## Strategy Tester behavior
- Tester mode cannot rely on `WebRequest` in optimization flows.
- EA bypasses add-on entitlement checks in tester mode.
- EA key decryption and key expiry checks still apply in tester mode.
