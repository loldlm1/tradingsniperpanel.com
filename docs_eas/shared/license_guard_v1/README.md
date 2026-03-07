# Shared License Guard Service (v1)

Canonical reusable license service for MT5 EAs in this repository.

## Purpose
- Keep one implementation for verify/heartbeat lane guard, backend magic-number caching, and optional daily results reporting.
- Avoid duplicated web requests across charts for the same lane identity.
- Provide a deterministic migration target for old and new EAs.

## Canonical Files
- `services/license_service_setup.mqh` (EA bootstrap wrapper; recommended integration point)
- `services/shared/license_guard_v1/license_guard_profile.mqh`
- `services/shared/license_guard_v1/license_service.mqh`
- `services/shared/license_guard_v1/license_guard_online.mqh`
- `services/shared/license_guard_v1/daily_results_online.mqh`
- `services/shared/license_guard_v1/core/addon_catalog.mqh`
- `services/shared/license_guard_v1/backend-entitlements-contract.md`
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
7. Use `LicenseGetCachedMagicNumber()` as the runtime trading magic in live mode.
8. If `LicenseGetCachedMagicNumber() <= 0` after startup verify, fail closed and remove EA.
9. If a rollout reassigns an oversized legacy lane value, trust the latest successful `verify` response as the new runtime magic source.

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

## Daily Results Rules
- Daily results use backend `magic_number` from verify cache only.
- Shared service expects a signed-32-bit-safe positive `magic_number` (`1..2147483647`).
- Local dedupe key includes `account + ea_id + magic_number`.
- Closed PnL aggregation filters by `DEAL_MAGIC == magic_number`.

## Migration Requirement
When adopting this module in an EA, remove or bypass legacy local license logic to prevent dual-auth flows.

Reference migration plan:
- `services/shared/license_guard_v1/license-shared-service-migration-plan.md`
