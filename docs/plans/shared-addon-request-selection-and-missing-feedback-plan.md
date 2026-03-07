# Plan: Shared Addon Request Selection and Missing Feedback

**Generated**: 2026-03-07
**Estimated Complexity**: Medium

## Goal
Make the shared license service support dynamic, input-driven add-on entitlement validation for add-on EAs like Fibonacci/HFT Grid AI, so base EA usage does not request lane-wide add-ons, startup/reverify resolves the add-ons actually enabled by the current inputs, and missing add-ons are reported with friendly chart labels plus technical log keys.

## Definition of Done
- Base Fibonacci/HFT Grid AI usage sends no `addons` field when all add-on-driven inputs are disabled.
- Startup/reverify resolves the add-on keys implied by the currently enabled inputs and validates them against backend `granted_addons` in shared service.
- Backend `addons_required` responses remain available for always-required add-ons, with canonical missing-addon fields for shared-service parsing.
- Chart copy uses friendly add-on titles derived from the shared add-on catalog; terminal logs keep add-on keys for debugging.
- Rails API response shape is aligned and documented for shared-service consumption, with clear guidance on `missing_addons` as the canonical machine-readable field.
- Shared-service integration docs explain how future add-on EAs supply requested add-on keys without hardcoding all add-ons into `LICENSE_SHARED_REQUIRED_ADDONS_CSV`.
- Rails coverage is added for the response contract changes; downstream EA compile/manual QA remains a handoff step, not repo-local implementation.

## Constraints
- Do not modify any external MQL5 EA repo during this task; only patch the shared-service artifact and Rails app in this repo.
- Keep the implementation reusable in the shared service so future add-on EAs can adopt it with a thin EA-local mapping layer.
- Add-on enforcement should happen only at startup/reverify, not as a separate runtime entitlement removal loop beyond the existing license verify cadence.
- Preserve backward compatibility where practical for existing non-addon EAs and current Rails clients.
- Keep friendly titles in chart/UI copy and addon keys in logs.

## Overview
Current findings already confirmed:
- Rails `Licenses::AddonAccess` already supports arbitrary requested add-on keys and computes missing keys from one-time `MarketplacePurchase` ownership.
- The Rails `verify` failure payload currently returns `required_addons` and `missing_addons`, but the shared MQL license service only logs the error code and ignores those details.
- The shared service currently seeds `addons` from compile-time `LICENSE_SHARED_REQUIRED_ADDONS_CSV`, which is correct for “always required” add-ons but wrong for Fibonacci/HFT Grid AI because those add-ons are input-driven and optional.
- In the downstream HFT Grid AI repo, `license_service_setup.mqh` currently sets `LICENSE_SHARED_REQUIRED_ADDONS_CSV` to the full Fibonacci add-on list, which explains why startup `verify` always returns `addons_required`.
- The downstream HFT Grid AI repo already contains EA-local add-on request logic and friendly labeling in `services/trading_management/addon_runtime_policy.mqh`, which proves the business rules exist but are not yet exposed through the reusable shared license-service interface.
- Official MQL5 docs confirm that input changes trigger deinit/reinit (`OnDeinit` before reinitialization due to input changes), which is compatible with a startup/reverify-only addon enforcement design.
- Final implementation decision: optional/input-driven add-ons are validated locally in shared service against backend `granted_addons` after verify/reverify success, while the backend `addons` request field is reserved for always-required add-ons only. This avoids lane-wide hard-auth failures when different charts in the same lane enable different optional features.

## Prerequisites
- Shared-service artifact path in this repo: `docs_eas/shared/license_guard_v1/*`
- Rails entitlement API code under `app/controllers/api/v1` and `app/services/licenses`
- Downstream EA repos will manually copy the shared-service changes and perform compile/manual QA after repo-side work is done

## Sprint 1: Define the Shared Addon Contract
**Goal**: Replace the current compile-time “all addons” behavior with a reusable runtime-request contract.
**Demo/Validation**:
- A concrete shared-service contract exists for “which add-ons are requested right now?”
- Rails response expectations for `addons_required` are explicit and documented.

### Task 1.1: Define Requested-Addon Hook Semantics
- **Location**: `docs_eas/shared/license_guard_v1/license_service.mqh`, `docs_eas/shared/license_guard_v1/README.md`, `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md`
- **Description**: Define a shared-service extension point for EAs to provide the current requested add-on keys at startup/reverify, instead of relying solely on `LICENSE_SHARED_REQUIRED_ADDONS_CSV`.
- **Dependencies**: none
- **Acceptance Criteria**:
  - Non-addon EAs can keep sending no add-ons with no extra work.
  - Add-on EAs can supply a dynamic CSV or equivalent from EA-local input logic.
  - `LICENSE_SHARED_REQUIRED_ADDONS_CSV` is repositioned as “always-required add-ons” or compatibility fallback, not the only mechanism.
- **Validation**:
  - Shared-service docs clearly distinguish base/no-addon EAs from input-driven addon EAs.

### Task 1.2: Canonicalize Backend Error Metadata
- **Location**: `app/controllers/api/v1/licenses_controller.rb`, `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md`, `spec/requests/api/licenses_verify_spec.rb`
- **Description**: Make `addons_required` responses explicitly machine-readable for the shared service, with `missing_addons` as the primary field and backward-compatible handling for any existing fields.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Shared service has one canonical field to read for missing add-on keys.
  - Rails response contract is documented and covered by request specs.
  - Friendly display labels remain a shared MQL concern, not a backend-only string payload.
- **Validation**:
  - Request specs verify the shape and content of addon failure responses.

## Sprint 2: Shared-Service Addon Selection and Messaging
**Goal**: Move the reusable license/addon request and feedback path into the shared service.
**Demo/Validation**:
- Shared service can request only currently enabled add-ons.
- Shared service can report all missing add-ons with friendly chart copy and technical logs.

### Task 2.1: Add Shared Requested-Addon Resolution
- **Location**: `docs_eas/shared/license_guard_v1/license_service.mqh`, `docs_eas/shared/license_guard_v1/license_guard_online.mqh`, `docs_eas/shared/license_guard_v1/core/addon_catalog.mqh`
- **Description**: Add a shared-service mechanism that asks the EA for current requested add-ons before startup verify and periodic reverify, while defaulting cleanly for non-addon EAs.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Base usage sends no add-ons when no add-on features are enabled.
  - Startup/reverify resolves active add-on keys through a shared hook and validates them from `granted_addons` without forcing lane-wide backend addon requests.
  - Behavior is reusable for future add-on EAs with minimal EA-local glue.
- **Validation**:
  - Static shared-service review confirms payload construction path is dynamic rather than full-list macro-based.

### Task 2.2: Parse and Surface Missing Addons in Shared Service
- **Location**: `docs_eas/shared/license_guard_v1/license_guard_online.mqh`, `docs_eas/shared/license_guard_v1/license_service.mqh`, `docs_eas/shared/license_guard_v1/core/addon_catalog.mqh`
- **Description**: Parse `missing_addons` from the Rails error response and expose it for removal/chart/log messaging.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Logs include addon keys for all missing add-ons.
  - Chart/removal message includes friendly labels for all missing add-ons.
  - `addons_required` no longer appears as an opaque error with no addon detail.
- **Validation**:
  - Shared-service log/copy examples are documented for downstream QA.

### Task 2.3: Scope Startup/Reverify-Only Enforcement
- **Location**: `docs_eas/shared/license_guard_v1/README.md`, `docs_eas/shared/license_guard_v1/license-shared-service-migration-plan.md`
- **Description**: Document the intended enforcement boundary so downstream EAs do not keep a separate timer-loop entitlement removal policy outside shared verify/reverify behavior.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Docs explicitly state add-on checks are resolved at startup and reverify points.
  - Downstream adoption notes call out removal of redundant EA-local runtime mismatch loops where applicable.
- **Validation**:
  - Migration notes are concrete enough to hand-apply in downstream EA repos.

## Sprint 3: Downstream Adoption Guidance and Rails Coverage
**Goal**: Make the shared-service changes easy to adopt and safe to maintain.
**Demo/Validation**:
- Future add-on EAs have a clear recipe.
- Rails response behavior is regression-tested.

### Task 3.1: Add Future-EA Integration Instructions
- **Location**: `docs_eas/shared/license_guard_v1/README.md`, `docs_eas/shared/license_guard_v1/license-shared-service-migration-plan.md`, `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md`
- **Description**: Add explicit instructions for future add-on EAs to implement the requested-addon hook and wire friendly label behavior from the shared catalog.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Docs show how to add new add-on EAs without hardcoding the full addon matrix in `license_service_setup.mqh`.
  - Docs note that base EA features must remain usable without add-on entitlements.
- **Validation**:
  - Instructions are specific enough for manual downstream copy/paste.

### Task 3.2: Extend Rails Addon Specs
- **Location**: `spec/requests/api/licenses_verify_spec.rb`, optional service specs under `spec/services/licenses`
- **Description**: Add regression coverage for base/no-addon requests and partial-missing addon sets.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Specs cover no-addon success path.
  - Specs cover multi-addon request where only a subset is missing.
  - Specs verify canonical addon failure payload.
- **Validation**:
  - Focused Rails RSpec run passes.

## Testing Strategy
- Rails request specs should verify:
  - `verify` succeeds when no add-ons are requested.
  - `verify` returns canonical missing-addon metadata when some requested add-ons are not owned.
  - payload shape remains compatible for the shared-service parser.
- Shared-service verification in this repo is static/documentation-level unless a local compile context is introduced.
- Downstream EA validation is manual handoff:
  - copy shared-service artifact,
  - compile the EA,
  - attach with all add-on inputs off,
  - attach with one owned addon on,
  - attach with multiple unowned add-ons on,
  - verify friendly chart copy and key-based logs.

## Potential Risks & Gotchas
- Shared service cannot infer arbitrary EA inputs by itself; every add-on EA still needs a thin EA-local requested-addon mapping function.
- If Rails response shape changes too aggressively, existing shared-service consumers may break; backward compatibility matters.
- Downstream HFT Grid AI currently has an EA-local timer-based entitlement mismatch check in `OnTimer`; shared-service improvements alone will not remove that behavior until the downstream repo adopts the new guidance.
- `required_addons` and `missing_addons` are currently redundant only when none of the requested add-ons are owned; partial-ownership cases still make the distinction meaningful.
- Because external EA repos are out of scope here, final functional validation depends on manual downstream compile and chart QA.

## Rollback Plan
- Keep Rails addon response changes additive/backward-compatible where possible.
- Keep shared-service changes behind clear defaults so non-addon EAs continue working without modification.
- If downstream adoption hits issues, fall back to the previous shared-service artifact and EA-local add-on policy until the hook contract is adjusted.

## Open Questions
- None blocking for planning. Assumption: keep Rails backward-compatible and treat `missing_addons` as the canonical field for new shared-service parsing while preserving existing addon error fields during migration.

## Execution Log
- [PASS] Reviewed requested skills: `planner`, `rails-expert`, and `mql5-functional`.
- [PASS] Reviewed `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md` add-on contract and Fibonacci addon matrix.
- [PASS] Reviewed downstream EA setup at `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/license_service_setup.mqh`.
- [PASS] Reviewed Rails addon entitlement service at `app/services/licenses/addon_access.rb`.
- [PASS] Reviewed shared-service request construction and error parsing in `docs_eas/shared/license_guard_v1/license_guard_online.mqh`.
- [PASS] Reviewed downstream HFT Grid AI addon/runtime policy and startup/timer hooks for current behavior.
- [PASS] Verified with official MQL5 docs via Context7 that input changes trigger deinit/reinit, which supports startup/reverify-only addon enforcement.
- [PASS] Confirmed current root cause: downstream Fibonacci setup hardcodes all add-ons into `LICENSE_SHARED_REQUIRED_ADDONS_CSV`, so startup verify always requests all add-ons.
- [PASS] Implemented additive Rails `addons_required` response arrays (`required_addon_keys`, `missing_addon_keys`) while preserving existing CSV fields.
- [PASS] Implemented shared-service requested-addon hook, local post-verify optional-addon validation, and backend addon failure parsing/messaging in `docs_eas/shared/license_guard_v1/*`.
- [PASS] Updated shared-service README, backend contract, and migration guide for the new optional-addon hook contract and lane-safe validation flow.
- [PASS] Verification command: `bundle exec rspec spec/requests/api/licenses_verify_spec.rb`
- [PASS] Verification command: `bundle exec rspec spec/services/licenses/addon_access_spec.rb spec/services/licenses/granted_addons_spec.rb`
- [PASS] Verification command: `git diff --check`
- [PASS] Audit Gate: code pattern/efficiency, behavior/goal alignment, and tests context reviewed with `rails-expert` and `mql5-functional`; status PASS.
