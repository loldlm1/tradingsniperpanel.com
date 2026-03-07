# Plan: EA Entitlements Audit and Magic Number Drift

**Generated**: 2026-03-07
**Estimated Complexity**: Medium

## Goal
Audit the Rails entitlement API and the shared MT5 license-guard logic against `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md`, explain the current production symptoms, and produce an implementation-ready remediation plan for the `verify -> runtime -> daily_results` flow.

## Definition of Done
- We can explain whether the observed `GET /` requests are part of the EA/license flow, a WebRequest side effect, or unrelated site traffic.
- We can explain why `PagesController#home` returns `204 No Content` for those requests and why that path still performs multiple queries.
- We can trace the full `magic_number` lifecycle across Rails allocation, JSON response, MQL parsing/cache/shared lane state, runtime trading usage, and `daily_results` submission.
- The plan identifies the exact root-cause candidate(s) for `VALID EA LICENSE! ... magic=...` followed by `invalid_magic_number` on `daily_results`.
- The plan defines the required code, logging, and spec changes across Rails and the shared MQL service to close the gap.
- The plan includes an audit gate for code pattern/efficiency, behavior alignment, and tests context before implementation is considered done.

## Constraints
- Treat `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md` as the contract source of truth unless we intentionally revise it.
- Keep Rails controllers thin and push behavior into services/models as already established in this app.
- Keep scope centered on `POST /api/v1/licenses/verify`, `POST /api/v1/licenses/heartbeat`, `POST /api/v1/broker_accounts/daily_results`, and the shared license guard.
- This planning pass reviews MQL logic only; no EA compile/test is required in this step.
- Reuse prior entitlement work already archived under `docs/plans/_archive/`; focus on the remaining production mismatch instead of re-planning completed work.
- Prioritize fixing the shared license service and Rails together first; EA repo integration, compile, and manual QA will happen afterward.
- Keep the root `GET /` query-cost issue out of this feature unless evidence later proves it is part of the entitlement failure path.

## Overview
Current repo findings already confirmed:
- Rails API routes are `POST /api/v1/licenses/verify`, `POST /api/v1/licenses/heartbeat`, and `POST /api/v1/broker_accounts/daily_results`.
- Shared MQL constants also target `/api/v1/...`, so the observed `GET /` traffic is not the intended endpoint path from the canonical shared service.
- `GET /` currently lands in `PagesController#home`; because the request is `*/*`, Rails logs `No template found ... rendering head :no_content`, but controller callbacks and landing-pricing work still execute first, which explains the query count.
- Rails currently allocates random positive `magic_number` values up to `(2**63) - 1`.
- Shared MQL parses `magic_number` with `response.getNumber("magic_number")` and stores shared lane state with `GlobalVariableSet(...)`, both of which are `double`-backed operations.
- A signed 64-bit integer can exceed the exact integer range of an IEEE-754 double (`2^53 - 1`), so precision loss is the leading root-cause candidate for `verify` succeeding and `daily_results` later sending a different `magic_number`.
- Observed failing runtime value `5544576807936763904` is far above the exact-safe integer limit `9007199254740991`, which materially strengthens the precision-loss hypothesis.
- Official MQL5 docs also align with this: `long` is 64-bit, `ORDER_MAGIC` is typed as `long`, terminal global variables are written/read through `double`, and MetaQuotes explicitly documents that `long/ulong -> double` conversion can lose precision, so large lane values are especially risky when they cross JSON parsing and `GlobalVariableSet/Get`.

## Sprint 1: Reproduce and Pin the Failing Contract Boundary
**Goal**: Turn the current symptom report into a precise, evidence-backed failure map.
**Demo/Validation**:
- A written trace exists for the failing request sequence: startup verify, cached/shared magic state, and the first failing `daily_results` call.
- We can say whether `GET /` is causally related, merely correlated, or unrelated noise.

### Task 1.1: Capture Actual Runtime Request Evidence
- **Location**: production app logs, reverse-proxy/access logs if available, and Rails request logs around the failing timestamps
- **Description**: Collect one failing end-to-end sequence showing the actual HTTP method/path/status for entitlement requests, not only the homepage noise.
- **Dependencies**: none
- **Acceptance Criteria**:
  - One failing session includes `verify`, optional `heartbeat`, and `daily_results` evidence with timestamps.
  - The posted `magic_number` for the failing `daily_results` request is visible or otherwise reconstructable.
  - We know whether `GET /` came from the MT5 host, EA code, terminal WebRequest behavior, infrastructure probes, or other traffic.
- **Validation**:
  - Compare Rails logs with MT5 terminal logs for the same minute.

### Task 1.2: Profile the Root `GET /` Path
- **Location**: `config/routes.rb`, `app/controllers/application_controller.rb`, `app/controllers/pages_controller.rb`, `app/services/marketing/*`, `app/services/billing/pricing_catalog.rb`
- **Description**: Explain the `204` response and identify which before-actions/services account for the logged query count.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - We have a short query-source inventory for the root request path.
  - We know whether a separate perf/noise-hardening task is needed.
- **Validation**:
  - Use controller/request profiling or log-level SQL inspection in a local/staging reproduction.

## Sprint 2: Audit the `magic_number` Contract End to End
**Goal**: Prove where `magic_number` drift can occur and decide the safest contract-preserving fix.
**Demo/Validation**:
- Each transition point is documented: allocation, serialization, parse, shared cache, runtime use, and backend validation.
- Precision/identity drift hypotheses are either confirmed or ruled out.

### Task 2.1: Audit Rails `magic_number` Generation and Validation Boundaries
- **Location**: `app/services/licenses/lane_magic_number_allocator.rb`, `app/services/broker_accounts/daily_result_recorder.rb`, `app/models/license_lane_magic_number.rb`, related request/service/model specs
- **Description**: Verify backend assumptions about lane identity, integer range, normalization, and validation rules.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - We constrain new lane `magic_number` allocation to simple signed-32-bit-safe positive integers unless implementation evidence requires a broader exact-safe range.
  - We confirm whether lane identity remains stable for the failing production payloads.
- **Validation**:
  - Add or outline focused specs around range boundaries and repeated verify/daily-results round-trips.

### Task 2.2: Audit Shared MQL Parsing and Shared-State Persistence
- **Location**: `docs_eas/shared/license_guard_v1/license_guard_online.mqh`, `docs_eas/shared/license_guard_v1/daily_results_online.mqh`, canonical shared service path if different
- **Description**: Review all numeric conversions and shared-state storage paths that touch `magic_number`, especially JSON parsing and terminal global variables.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Every place where `magic_number` is converted to/from `double`, `long`, string, or global shared state is inventoried.
  - The plan identifies whether the failure is caused by JSON parsing precision loss, `GlobalVariableSet` precision loss, runtime EA magic assignment drift, or a combination.
- **Validation**:
  - Static code trace plus one worked example using the production-sized `magic_number` seen in logs.

### Task 2.3: Choose the Compatibility Strategy
- **Location**: contract doc plus Rails and shared MQL implementation targets
- **Description**: Decide between the viable fixes, with backward-compatibility implications made explicit.
- **Dependencies**: Tasks 2.1 and 2.2
- **Acceptance Criteria**:
  - One strategy is chosen and justified:
    - constrain backend-generated `magic_number` to simple signed-32-bit-safe positive integers, or
    - carry `magic_number` as a string across the wire/shared cache and parse explicitly, or
    - a hybrid migration if existing rows/binaries require compatibility.
  - The chosen strategy includes rollback/compatibility notes for already-issued lane rows and existing EA binaries.
- **Validation**:
  - Decision record added to this plan before implementation begins.

## Sprint 3: Implementation-Ready Remediation Plan
**Goal**: Break the fix into committable work items with validation and audit criteria.
**Demo/Validation**:
- The next implementation pass can start without ambiguity.
- Required specs and observability changes are enumerated up front.

### Task 3.1: Rails Change Plan
- **Location**: API controllers/services/models/specs under `app/controllers/api/v1`, `app/services/licenses`, `app/services/broker_accounts`, `spec/requests`, `spec/services`, `spec/models`
- **Description**: Define the exact Rails changes needed for range safety, better logging, and request tracing.
- **Dependencies**: Task 2.3
- **Acceptance Criteria**:
  - The plan lists any schema/data follow-up needed for existing oversized `license_lane_magic_numbers`, defaulting to lazy remap on the next successful lane `verify` instead of mass backfill unless that proves insufficient.
  - The plan lists the request/service/model specs required for regression coverage.
- **Validation**:
  - Targeted RSpec set is identified before coding.

### Task 3.2: Shared MQL Change Plan
- **Location**: canonical shared license-guard repo/path plus mirrored docs under `docs_eas/shared/license_guard_v1`
- **Description**: Define the exact shared-service changes needed so verify cache, lane sharing, and daily-results submission preserve the same `magic_number`.
- **Dependencies**: Task 2.3
- **Acceptance Criteria**:
  - The plan covers response parsing, shared-lane state storage, startup/runtime logs, and any fallback/migration handling.
  - The plan makes clear whether older binaries remain compatible or must be redeployed.
  - The repo copy under `docs_eas/shared/license_guard_v1` is treated as the handoff artifact for manual downstream copy/paste, compile, and QA in the EA projects.
- **Validation**:
  - Static review checkpoints and post-change runtime log markers are defined.
  - Manual EA compile/QA handoff steps are defined for post-patch verification in the downstream EA repos.

### Task 3.3: Audit Gate Plan
- **Location**: final implementation checklist
- **Description**: Define the required PASS/FAIL audit before closing the future implementation.
- **Dependencies**: Tasks 3.1 and 3.2
- **Acceptance Criteria**:
  - Code pattern and efficiency checks are explicit.
  - Feature behavior and goal-alignment checks are explicit.
  - Tests context lists both required coverage and any acceptable remaining gaps.
- **Validation**:
  - Audit checklist is ready to run at the end of implementation.

## Testing Strategy
- Rails request specs for `verify`, `heartbeat`, and `daily_results` must cover boundary-size `magic_number` handling, repeated verify reuse, and rejection of drifted values.
- Rails service/model specs should cover allocator range rules, lane reuse, and any migration/backfill logic.
- Shared MQL validation should at minimum use static trace review in this planning pass and runtime log verification after implementation.
- If root-path noise stays in scope, add a lightweight request/profile check to verify the query count either drops or is intentionally ignored as unrelated traffic.

## Potential Risks & Gotchas
- The canonical EA binary in production may not match the repo copy under `docs_eas/shared/license_guard_v1`; if so, local review alone can miss the real bug.
- Existing persisted `license_lane_magic_numbers` may already contain unsafe-large integers; a fix may need migration/backfill or tolerant validation for old rows.
- A Rails-only fix can still fail if MQL continues to round large integers when reading JSON or writing terminal globals.
- A MQL-only fix can still fail if Rails keeps issuing values above the EA-safe exact range.
- `GET /` may be unrelated background/probe traffic; folding that into the entitlement fix without proof risks unnecessary scope growth.

## Rollback Plan
- Keep the rollout reversible by isolating Rails range/logging changes from MQL shared-service changes.
- If a migration/backfill is needed, make it additive or reversible where possible.
- Deploy extra logging before behavior changes if production evidence is still incomplete.

## Open Questions
- None blocking for implementation planning.

## Execution Log
- [PASS] Read workflow/project instructions in `AGENTS.md`.
- [PASS] Reviewed requested skills: `planner` and `rails-expert`.
- [PASS] Located canonical contract at `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md`.
- [PASS] Reviewed Rails routing and entitlement endpoints in `config/routes.rb`.
- [PASS] Reviewed Rails controllers/services/models/specs for verify, heartbeat, daily results, and lane magic handling.
- [PASS] Reviewed shared MQL license-guard files for verify/heartbeat/daily-results flow and lane state sharing.
- [PASS] Reviewed archived entitlement plans to avoid duplicating completed work.
- [PASS] Identified leading root-cause candidate: 64-bit `magic_number` generation on Rails vs `double`-backed parsing/shared storage on the MQL side.
- [PASS] User decision: implementation should cover both Rails and shared MQL, with shared service fixed first and EA integration/manual QA afterward.
- [PASS] User decision: prefer simpler backend-generated lane `magic_number` values instead of huge 64-bit values.
- [PASS] User decision: root `GET /` cleanup should be handled in a separate task unless tied directly to the entitlement issue.
- [PASS] User-provided failing runtime value recorded for audit context: `5544576807936763904`.
- [PASS] User decision: default target range is simple signed-32-bit-safe positive integers.
- [PASS] User decision: existing oversized lane values can be handled with an efficient query/service path; default implementation approach is lazy remap on successful `verify`.
- [PASS] User decision: patch shared-service files in this repo as the handoff artifact for manual EA copy/paste, compile, and QA.
- [PASS] Verified external MQL5 contract assumptions from official docs: `long` is 64-bit, `ORDER_MAGIC` is `long`, terminal global variables are `double`-backed, and `long/ulong -> double` conversion can lose precision.
- [PASS] Added `Licenses::MagicNumberPolicy` and constrained new backend lane `magic_number` allocation/validation to signed-32-bit-safe positive integers.
- [PASS] Added lazy remap of oversized legacy `license_lane_magic_numbers` during successful `verify`, with allocator logging for reassigned lanes.
- [PASS] Updated `daily_results` parsing/validation to reject out-of-range `magic_number` values before lane lookup.
- [PASS] Updated shared MQL license guard to enforce the supported `magic_number` range for verify responses, cached runtime state, and shared terminal globals.
- [PASS] Updated shared-service and backend contract docs to reflect the supported range and rollout behavior for legacy oversized lane values.
- [PASS] Command: `bundle exec rspec spec/services/licenses/lane_magic_number_allocator_spec.rb spec/models/license_lane_magic_number_spec.rb spec/models/broker_account_daily_result_spec.rb spec/requests/api/licenses_verify_spec.rb spec/requests/api/broker_account_daily_results_spec.rb spec/requests/api/licenses_heartbeat_spec.rb`
- [PASS] Command: `git diff --check`
- [PASS] Decision: retry allocator `magic_number` collisions for both DB unique-index races and model-level uniqueness validation hits.
- [PASS] Command: targeted RSpec re-run after allocator collision retry hardening.
- [PASS] Command: final `git diff --check` re-run.
- [PASS] Audit Gate (rails-expert): code pattern and efficiency.
- [PASS] Audit Gate (rails-expert): feature behavior and goal alignment.
- [PASS] Audit Gate (rails-expert): tests context reviewed; targeted Rails coverage passes, while downstream EA compile/manual QA remains the required final validation for the copied shared-service artifact.
- [FAIL] Context7 lookup for official Rails library id did not return a canonical Rails docs entry.
- [FAIL] Direct fetch of the Rails API guide failed due tool transport closure.
