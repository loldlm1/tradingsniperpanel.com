# License Shared Service Migration Plan

This plan defines how to migrate EAs to the canonical shared service without ambiguity.

## Scope
- Replace legacy EA-local license code with the shared module under `services/shared/license_guard_v1/`.
- Keep backend contract parity with `services/shared/license_guard_v1/backend-entitlements-contract.md`.
- Support both add-on and non-add-on EAs.

## Success Criteria
- One lane leader per `source + email + ea_id + company + account_number + account_type`.
- Followers do not send duplicate verify/heartbeat requests while leader is healthy.
- Runtime magic is always sourced from successful `verify` response.
- Runtime magic stays inside the shared-service supported signed-32-bit-safe positive range.
- Missing/invalid `magic_number` is fail-closed.
- Daily results keying and deal aggregation are scoped by `magic_number`.

## Implementation Steps
1. Prepare profile values for target EA.
- Configure these macros in `services/license_service_setup.mqh`:
- `LICENSE_SHARED_PROFILE_NAME`
- `LICENSE_SHARED_BASE_EA_ID`
- `LICENSE_SHARED_SOURCE_KEY`
- `LICENSE_SHARED_ENABLE_ADDON_ENTITLEMENTS` (define to use the shared addon catalog and friendly labels; otherwise normalized-key fallbacks are used)
- `LICENSE_SHARED_REQUIRED_ADDONS_CSV` (always-required add-ons only; empty when none)
- `LICENSE_SHARED_COLLECT_REQUESTED_ADDONS` (optional macro alias to the EA-local requested-addon collector)
- Keep license shared core files under `services/shared/license_guard_v1/core/*` (do not depend on EA-local `services/core/*` for add-on catalog keys).

2. Wire shared service hooks in EA entrypoint.
- Include `services/license_service_setup.mqh` in the EA entrypoint (`*.mq5`).
- Ensure `services/license_service_setup.mqh` includes `services/shared/license_guard_v1/license_service.mqh`.
- `OnInit`: call `LicenseServiceInit()` before trading setup.
- `OnTimer`: call `LicenseServiceOnTimer()`.
- `OnDeinit`: call `LicenseServiceOnDeinit()`.

3. Replace runtime magic assignment.
- Live mode: use `LicenseGetCachedMagicNumber()` only.
- Tester mode behavior can stay EA-specific.
- If cached magic is invalid after startup verify, return `INIT_FAILED` and remove EA.
- After upgrading from older oversized lane values, accept the latest successful `verify` response as authoritative for the lane's new runtime magic.

4. Remove legacy code paths.
- Remove old decrypt-only/offline gate logic for production flow.
- Remove direct verify/heartbeat code that bypasses lane guard.
- Remove ad-hoc daily-results submission implementations.

5. Configure add-ons correctly.
- EAs with no always-required add-ons: keep `LICENSE_SHARED_REQUIRED_ADDONS_CSV=""`.
- EAs with truly always-required add-ons: define them in `LICENSE_SHARED_REQUIRED_ADDONS_CSV` so backend `verify` can fail with `addons_required`.
- EAs with input-driven optional add-ons: keep `LICENSE_SHARED_REQUIRED_ADDONS_CSV=""` and implement `LICENSE_SHARED_COLLECT_REQUESTED_ADDONS` to return only the active addon keys for the current chart.
- Shared service will compare requested addon keys against backend `granted_addons` after startup/reverify success and remove only the chart that is using unowned options.
- Use `LicenseAppendRequestedAddon()` in the collector to normalize and dedupe addon keys.
- Keep per-EA input-to-addon mapping in that EA's `services/license_service_setup.mqh` or a nearby EA-local helper include, not in the shared core.

Example optional-addon wiring:
```cpp
#define LICENSE_SHARED_COLLECT_REQUESTED_ADDONS CollectRequestedAddonsForCurrentInputs
#include "shared/license_guard_v1/license_service.mqh"

void CollectRequestedAddonsForCurrentInputs(string &addons_out[])
{
  ArrayResize(addons_out, 0);

  if(UseSessionFilter)
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_SESSION_TIME_FILTER);

  if(NeedsAnyCompoundFamily)
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_COMPOUND_ANY_FAMILY);
}
```

6. Validate compile.
- Run headless compile for the target EA entrypoint.
- No test harness is required by this migration plan unless requested.

7. Validate rollout behavior.
- Restart/re-attach the EA so startup `verify` can refresh any legacy oversized lane magic.
- Confirm logs show a successful verify with a supported signed-32-bit-safe `magic_number`.
- Confirm trading and `daily_results` reuse that refreshed value.

## Code Review Checklist
- No duplicated license network callers remain outside shared service.
- EA entrypoint includes `services/license_service_setup.mqh` (or documented custom equivalent).
- EA does not generate random/local live magic values.
- Daily results logic references cached backend magic.
- `LicenseOnline_RequestLeaderReverify()` is used for missing broker account retries.
- User-facing removal messages are profile-branded but behavior stays shared.
- Optional add-on EAs do not hardcode the full addon catalog into `LICENSE_SHARED_REQUIRED_ADDONS_CSV`.

## Rollout Strategy for Multiple Repos
1. Migrate one EA per repo to completion.
2. Validate compile and lane behavior under multi-chart scenario.
3. Roll out remaining EAs with same checklist and profile mapping.
4. Keep contract file synchronized 1:1 across repos.

## Canonical References
- Bootstrap wrapper: `services/license_service_setup.mqh`
- Shared service: `services/shared/license_guard_v1/README.md`
- Shared add-on catalog core: `services/shared/license_guard_v1/core/*`
- Backend contract: `services/shared/license_guard_v1/backend-entitlements-contract.md`
- Agent rules: `AGENTS.md`
