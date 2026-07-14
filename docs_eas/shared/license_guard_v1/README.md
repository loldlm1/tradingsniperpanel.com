# Shared License Guard Service (v1)

Canonical reusable license service for MT5 EAs in this repository.

## Purpose
- Keep one implementation for verify/heartbeat lane guard, backend magic-number caching, and optional daily results reporting.
- Avoid duplicated web requests across charts for the same lane identity.
- Provide a deterministic migration target for old and new EAs.
- For upgraded EAs, separate license-lane authorization from per-chart runtime trade magic.

## Canonical Files
- `services/license_service_setup.mqh` (EA bootstrap wrapper; recommended integration point)
- `services/shared/license_guard_v1/license_guard_profile.mqh`
- `services/shared/license_guard_v1/license_service.mqh`
- `services/shared/license_guard_v1/license_guard_online.mqh`
- `services/shared/license_guard_v1/daily_results_online.mqh`
- `services/shared/license_guard_v1/core/addon_catalog.mqh`
- `services/shared/license_guard_v1/backend-entitlements-contract.md`
- `services/shared/license_guard_v1/backend-instance-magic-contract.md`
- `services/shared/license_guard_v1/license-shared-service-migration-plan.md`

## Shared Core Layout
- License-guard-owned helpers live under `services/shared/license_guard_v1/core/*`.
- `license_guard_online.mqh` resolves add-on keys from this local shared core, not from repo/EA-local `services/core/*`.
- Keep this folder synchronized across EA repos to preserve shared-service behavior parity.

## V1 Refactor Policy
- Legacy wrapper files were deprecated and removed in this repo refactor:
  - `services/SecurityLicense.mqh`
  - `services/SecurityLicenseOnline.mqh`
  - `services/BrokerAccountDailyResultsOnline.mqh`
- New and old EAs should integrate through `services/license_service_setup.mqh`.
- `license_service.mqh` stays the shared core module; include it directly only for custom/advanced wiring.

## Integration Contract (EA side)
1. Include `services/license_service_setup.mqh` in the EA entrypoint (`*.mq5`).
2. Define/update profile macros in `services/license_service_setup.mqh`.
3. Keep `services/license_service_setup.mqh` including `services/shared/license_guard_v1/license_service.mqh`.
4. Call `LicenseServiceInit()` in `OnInit` before trading initialization.
5. Wire `OnTimer` to `LicenseServiceOnTimer()`.
6. Wire `OnDeinit` to `LicenseServiceOnDeinit()`.
7. Legacy EAs use `LicenseGetCachedMagicNumber()` from successful `verify` as the runtime trading magic in live mode.
8. Upgraded EAs resolve or generate a stable chart `instance_id`, call `POST /licenses/instance_magic` after lane authorization is healthy, and use the returned instance magic as the runtime trading magic.
9. If the selected runtime magic is missing or invalid after startup, fail closed and remove EA.
10. If a rollout reassigns an oversized legacy lane value, trust the latest successful `verify` response as the new runtime magic source.

Advanced/custom option:
- Include `services/shared/license_guard_v1/license_service.mqh` directly only when a repo intentionally does not use `services/license_service_setup.mqh`.

## Profile Macros
Set per-EA values in `services/license_service_setup.mqh` (recommended) before the shared include.

- `LICENSE_SHARED_PROFILE_NAME` (chart/user message branding)
- `LICENSE_SHARED_SOURCE_KEY`
- `LICENSE_SHARED_BASE_EA_ID`
- `LICENSE_SHARED_API_BASE_URL`
- `LICENSE_SHARED_PRIMARY_CI_KEY`
- `LICENSE_SHARED_BASE_SECRET_KEY`
- `LICENSE_SHARED_ENFORCEMENT_ENABLED` (define to enable; undefine to disable)
- `LICENSE_SHARED_DAILY_RESULTS_ENABLED` (define to enable; undefine to disable)
- `LICENSE_SHARED_ENABLE_ADDON_ENTITLEMENTS` (define to use the shared addon catalog and friendly labels; otherwise normalized-key fallbacks are used)
- `LICENSE_SHARED_REQUIRED_ADDONS_CSV` (optional; always-required addon CSV, empty string if none)

Direct include option:
- If using `license_service.mqh` directly, define the same macros before that include.

## Optional Add-on Entitlements
- Add-ons are optional by profile.
- `LICENSE_SHARED_REQUIRED_ADDONS_CSV` is only for add-ons that must always be entitled for the EA to run.
- Input-driven add-ons must not be hardcoded into `LICENSE_SHARED_REQUIRED_ADDONS_CSV`, or every chart in the lane will request them on backend `verify`.
- For optional/chart-specific add-ons, define `LICENSE_SHARED_COLLECT_REQUESTED_ADDONS` to an EA-local collector function.
- The shared service resolves that collector at startup and reverify, then compares the currently requested addon keys against backend `granted_addons`.
- Missing optional add-ons are removed locally with friendly chart labels and addon-key logs, without poisoning the whole lane with backend `addons_required`.
- EAs that do not require add-ons should keep `LICENSE_SHARED_REQUIRED_ADDONS_CSV` empty and omit the collector hook.
- The add-on key catalog stays shared and centralized in `services/shared/license_guard_v1/core/addon_catalog.mqh`.

Example hook contract:
```cpp
#define LICENSE_SHARED_COLLECT_REQUESTED_ADDONS CollectRequestedAddonsForCurrentInputs
#include "shared/license_guard_v1/license_service.mqh"

void CollectRequestedAddonsForCurrentInputs(string &addons_out[])
{
  ArrayResize(addons_out, 0);

  if(SessionAddonRequested())
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_SESSION_TIME_FILTER);

  if(CompoundModeNeedsAnyFamily())
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_COMPOUND_ANY_FAMILY);
}
```

Hook rules:
- Return only the add-ons implied by the current EA inputs for this chart.
- Use `LicenseAppendRequestedAddon()` for normalization and dedupe.
- If no optional add-ons are enabled, leave `addons_out` empty.
- Shared-service add-on enforcement runs only after startup/reverify success, not on every timer tick outside the existing verify cadence.

## Lane Identity and Request Sharing
The leader/follower lane key is derived from:
- `source + email + ea_id + company + account_number + account_type`

Runtime rules:
- One leader sends `verify/heartbeat` for a lane.
- Followers consume shared lane state and avoid duplicate requests.
- Followers can request leader reverify (`LicenseOnline_RequestLeaderReverify`).
- Upgraded charts may call `POST /licenses/instance_magic` for their own `instance_id` after the lane is authorized; this call must not make the chart a heartbeat leader.
- `instance_magic` requires an active lane session and may return retryable `lane_session_required` when the leader has not verified/refreshed recently enough.

## Instance-Scoped Trade Magic
Legacy EAs continue to trade with lane magic returned by `POST /licenses/verify`.
Upgraded EAs use the lane for entitlement, online seat, heartbeat, and request sharing, then resolve a per-chart trade magic:

1. Complete existing license verification/authorization.
2. Resolve or generate a local opaque `instance_id`.
3. Request `POST /licenses/instance_magic`.
4. Validate the returned signed-32-bit-safe positive `magic_number`.
5. Set `g_magic_number` and `CTrade.SetExpertMagicNumber()` from the instance magic.
6. Report daily results with the same instance magic.

`instance_id` rules:
- Max length: 64 ASCII characters.
- Allowed characters: `A-Z`, `a-z`, `0-9`, `_`, `-`.
- Stable across restart/recompile for the same chart instance.
- Unique enough that two charts do not intentionally share it.
- Must not contain account numbers, license tokens, API keys, broker credentials, emails, proprietary strategy settings, or other sensitive data.

Do not switch a chart to instance-scoped magic while it still has open positions under legacy lane magic. Safe default: block initialization with a clear migration status until positions are flat, or keep the previous EA version managing those positions until they close.

## Pandora Box Rollout Handoff
- Pandora Box (`ea_id=pandora_box`) is the first target for the upgraded shared guard.
- Backend support must be deployed first; old EAs remain compatible through `POST /licenses/verify` but keep the old same-lane magic overlap risk until upgraded.
- Shared guard calls `POST /licenses/instance_magic` only after lane authorization is healthy and the local instance magic cache is missing, invalid, or tied to a changed identity.
- `lane_session_required` is retryable: request leader verify/refresh, retry with backoff, and avoid parallel verify/heartbeat calls from followers.
- If legacy lane-magic open positions exist for the current chart symbol/account, block initialization with a migration status instead of switching magic while positions are open.
- Live trading must never use local/random fallback magic. Missing or invalid backend trade magic is fail-closed.
- Staging/demo validation should cover two Pandora Box charts on the same broker account getting different instance magic values, restart stability for the same chart, accepted daily results with instance magic, rejection of unallocated magic, and no request storm when the leader session is stale.
- Future EAs should adopt the same shared contract after Pandora Box validation.

## Daily Results Rules
- Legacy daily results use backend `magic_number` from verify cache.
- Upgraded daily results use instance magic returned by `POST /licenses/instance_magic`.
- Shared service expects a signed-32-bit-safe positive `magic_number` (`1..2147483647`).
- Local dedupe key includes `account + ea_id + magic_number`.
- Closed PnL aggregation filters by `DEAL_MAGIC == magic_number`.

## Migration Requirement
When adopting this module in an EA, remove or bypass legacy local license logic to prevent dual-auth flows.

## Versioned Token Compatibility

- Existing version 1 tokens decrypt as `email,ea_id,expires_at`.
- Version 2 and later tokens decrypt as `email,ea_id,expires_at,token_version`.
- The client validates and removes PKCS#7 cipher padding before parsing either
  payload format.
- The client accepts exactly those three- or four-field formats and requires a
  positive integer version in the fourth field.
- API JSON contracts remain unchanged; `license_key` is still the only token
  sent to the backend.
- Token contents and decrypted payloads must never be written to diagnostics.

Reference migration plan:
- `services/shared/license_guard_v1/license-shared-service-migration-plan.md`
