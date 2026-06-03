# Plan: MQL5 License Instance Magic Contract

**Generated**: 2026-06-03
**Status**: Completed and archived
**Completed**: 2026-06-03
**Estimated Complexity**: High

## Overview
Audit the current Rails license API contract, then add an efficient additive contract for chart-instance-scoped trade magic only where the audit confirms it is needed. The current production `/api/v1/licenses/verify` lane magic remains backward compatible for legacy EAs, while new Pandora Box builds and future shared-guard EAs opt into a separate `POST /api/v1/licenses/instance_magic` endpoint.

The central change is to keep the existing license lane for entitlement, online seat, heartbeat, and request sharing, but stop treating lane magic as the live per-chart trade identity for upgraded EAs. Upgraded EAs generate and persist an opaque `instance_id`, request a backend-issued trade magic for that instance, and fail closed if the response is missing or invalid.

## Current Findings
- `POST /api/v1/licenses/verify` currently validates license/add-ons, allocates or refreshes an online seat, upserts `BrokerAccount`, and returns a stable lane `magic_number`.
- `POST /api/v1/licenses/heartbeat` refreshes the online lease and intentionally does not rotate or reissue magic.
- `POST /api/v1/broker_accounts/daily_results` currently accepts only a valid lane magic stored in `license_lane_magic_numbers`.
- The new MQL5 contract at `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/shared/license_guard_v1/backend-instance-magic-contract-update.md` identifies a real bug class: multiple charts or multiple EAs on the same MT5 account can overlap if they trade with the same numeric magic.
- The efficient fix is additive: add instance magic allocation and daily-results compatibility, not a rewrite of the existing license verifier.

## Decisions
- Add `POST /api/v1/licenses/instance_magic`.
- Preserve legacy `/licenses/verify`, `/licenses/heartbeat`, and `/broker_accounts/daily_results` request/response shapes.
- Legacy EAs remain compatible but can still have the old same-lane trade-magic overlap until upgraded.
- New EA builds opt in by sending an EA-generated opaque `instance_id`.
- `instance_id` is generated and persisted by the EA, not the backend.
- Backend treats `instance_id` as opaque text with strict length/charset validation.
- New instance magic is unique by broker account across chart instances, and the allocator should also avoid colliding with existing legacy lane magic on that broker account.
- Daily results accept both legacy lane magic and new instance magic during rollout.
- Pandora Box is the first target; the contract is shared for future EA migrations.
- Do not implement live-position migration in Rails. The backend cannot reliably know MT5 open positions. The safe migration rule belongs in the EA/shared guard: block upgrade when legacy lane-magic positions are open, unless a separate tested migration mode is later designed.
- `instance_magic` requires a read-only active `LicenseOnlineSession` check for the same user + EA + broker identity. It must not create, refresh, or consume an online seat.
- Support logs should not include raw `instance_id`; log stable internal IDs plus a truncated or hashed `instance_id` value.

## Prerequisites
- Rails 8.0.4 local app, RSpec, PostgreSQL.
- Current contract docs:
  - `docs/database_model_reference.md`
  - `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md`
  - `docs_eas/shared/license_guard_v1/README.md`
- Proposed MQL5 contract:
  - `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/shared/license_guard_v1/backend-instance-magic-contract-update.md`
- No new gems, Node packages, queue backend changes, or payment/provider changes.
- External docs checked: Rails 8.0.4 Active Record migration/API controller primitives via Context7.

## Sprint 1: Contract Audit And Freeze
**Goal**: Confirm the minimal API contract and avoid unnecessary changes to existing production endpoints.

**Demo/Validation**:
- A short audit note exists in this plan or a follow-up implementation PR describing whether each current endpoint changes or stays unchanged.
- Existing specs still characterize legacy behavior before new behavior is added.

### Task 1.1: Audit Existing License API Contract
- **Location**: `app/controllers/api/v1/licenses_controller.rb`, `app/controllers/api/v1/broker_account_daily_results_controller.rb`, `app/services/licenses/license_verifier.rb`, `app/services/licenses/lane_magic_number_allocator.rb`, `app/services/broker_accounts/daily_result_recorder.rb`
- **Description**: Trace current verify, heartbeat, daily-results, rate-limit, broker-account, lane-magic, and error-shape behavior.
- **Dependencies**: none
- **Acceptance Criteria**:
  - `/licenses/verify` remains the lane entitlement and online-seat endpoint.
  - `/licenses/heartbeat` remains magic-free.
  - `/broker_accounts/daily_results` keeps the same payload and response shape.
  - The audit identifies only the required compatibility change: accepting instance magic in addition to lane magic.
- **Validation**:
  - Run targeted characterization specs before implementation:
    - `bundle exec rspec spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb spec/requests/api/broker_account_daily_results_spec.rb`

### Task 1.2: Freeze Instance Magic API Contract
- **Location**: `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md`, `docs/database_model_reference.md`
- **Description**: Define the new endpoint and exact request/response/error contract before coding.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Endpoint: `POST /api/v1/licenses/instance_magic`.
  - Required fields: `source`, `email`, `ea_id`, `license_key`, `broker_account`, `instance_id`.
  - Success body:
    ```json
    {
      "ok": true,
      "instance_id": "pandora_box_7W8S2K5NQ4H9",
      "magic_number": 490123456,
      "trade_identity_scope": "instance"
    }
    ```
  - Supported errors include `invalid_source`, `invalid_key`, `trial_disabled`, `user_not_found`, `ea_not_found`, `license_not_found`, `broker_account_not_found`, `invalid_payload`, `missing_instance_id`, `invalid_instance_id`, `rate_limited`, and `internal_error`.
  - `magic_number` range stays signed-32-bit-safe positive integer: `1..2147483647`.
- **Validation**:
  - Contract review against the external MQL5 proposal file.

### Task 1.3: Specify Lightweight Authorization Guard For Instance Magic
- **Location**: `app/services/licenses/online_seat_allocator.rb`, `app/models/license_online_session.rb`, future `Licenses::InstanceMagicNumberAllocator`
- **Description**: Require an existing active lane session without refreshing or allocating a seat.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Verify the license identity and require the existing `BrokerAccount`.
  - Check for an active `LicenseOnlineSession` for the same user + EA + broker identity.
  - Do not create, refresh, or consume an online seat from `instance_magic`.
  - Use indexed lookups and the existing 15-minute online-session TTL semantics so this endpoint stays lightweight.
  - Any new error code for missing/stale lane session is documented and classified as retryable in the EA shared guard.
- **Validation**:
  - Request specs cover bypass prevention, stale session behavior, and no online-session mutation.

## Sprint 2: Persistence And Allocation
**Goal**: Add durable backend state for stable per-chart instance magic with production-safe uniqueness.

**Demo/Validation**:
- Repeated allocation for the same broker account + EA + `instance_id` returns the same magic.
- Different `instance_id` values on the same broker account receive different magic values.
- Different EAs on the same broker account do not collide numerically.

### Task 2.1: Add Instance Magic Persistence
- **Location**: `db/migrate/*_create_license_instance_magic_numbers.rb`, `db/schema.rb`
- **Description**: Add a new table for instance-scoped magic mappings.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Table name: `license_instance_magic_numbers` unless implementation review finds a stronger local naming fit.
  - Columns:
    - `license_id` foreign key, null false
    - `broker_account_id` foreign key, null false
    - `expert_advisor_id` foreign key, null false
    - `source` string, null false
    - `email` string, null false
    - `instance_id` string, null false
    - `magic_number` bigint, null false
    - `first_seen_at` datetime, null false
    - `last_seen_at` datetime, null false
    - timestamps
  - Unique index on `broker_account_id + expert_advisor_id + instance_id`.
  - Unique index on `broker_account_id + magic_number`.
  - Check constraint for `magic_number > 0`.
  - Optional check constraint or model validation for `instance_id` length/format.
  - No backfill required.
- **Validation**:
  - `bin/rails db:migrate`
  - Schema review for indexes, constraints, and rollback safety.

### Task 2.2: Add Model And Factory
- **Location**: `app/models/license_instance_magic_number.rb`, `spec/factories/license_instance_magic_numbers.rb`, `spec/models/license_instance_magic_number_spec.rb`
- **Description**: Add validations, associations, normalization, and tests for instance identity.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Belongs to `license`, `broker_account`, and `expert_advisor`.
  - Normalizes `source` and `email` to lowercase.
  - Validates `instance_id` as ASCII, max 64, charset `A-Z`, `a-z`, `0-9`, `_`, `-`.
  - Validates magic range through `Licenses::MagicNumberPolicy`.
  - Rejects duplicate instance identity for the same broker account and EA.
  - Rejects duplicate magic on the same broker account.
- **Validation**:
  - `bundle exec rspec spec/models/license_instance_magic_number_spec.rb`

### Task 2.3: Implement Collision-Safe Allocator
- **Location**: `app/services/licenses/instance_magic_number_allocator.rb`, `spec/services/licenses/instance_magic_number_allocator_spec.rb`
- **Description**: Add a service that validates inputs, finds/reuses existing mappings, and allocates a new signed-32-bit-safe magic with bounded collision retries.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Same broker account + EA + `instance_id` returns the same magic.
  - Different `instance_id` on the same broker account returns a different magic.
  - Different EA IDs on the same broker account cannot collide numerically.
  - Generated values do not collide with active/new instance rows on the broker account.
  - Generated values also avoid existing legacy `license_lane_magic_numbers` for the same broker identity to prevent old/new ambiguity during rollout.
  - Logs stable support identifiers without logging license keys, raw secrets, or raw `instance_id`; use a truncated/hash `instance_id` value.
- **Validation**:
  - `bundle exec rspec spec/services/licenses/instance_magic_number_allocator_spec.rb`

## Sprint 3: API Endpoint And Daily-Results Compatibility
**Goal**: Expose instance magic through a new endpoint and allow reporting by either legacy lane magic or new instance magic.

**Demo/Validation**:
- New endpoint works without changing legacy verify/heartbeat behavior.
- Daily results accept instance-scoped magic after allocation.
- Invalid or unallocated magic still fails closed.

### Task 3.1: Add `instance_magic` Route And Controller Action
- **Location**: `config/routes.rb`, `app/controllers/api/v1/licenses_controller.rb`, `spec/requests/api/licenses_instance_magic_spec.rb`
- **Description**: Add `POST /api/v1/licenses/instance_magic` to the existing API namespace.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Uses `Licenses::LicenseVerifier`.
  - Validates broker-account payload with the same normalization expectations as existing verify/daily-results flows.
  - Finds the existing `BrokerAccount` for the verified license and broker identity.
  - Does not allocate or refresh online seats.
  - Does not alter `/licenses/verify` or `/licenses/heartbeat` response shapes.
  - Returns `ok`, `instance_id`, `magic_number`, and `trade_identity_scope`.
  - Applies a reasonable per-email rate limit, preferably separate from verify so instance lookups do not starve verify/heartbeat traffic.
- **Validation**:
  - Request specs for success, repeated stability, invalid license, missing broker account, missing/invalid `instance_id`, rate limit, and no `LicenseOnlineSession` mutation.

### Task 3.2: Add Instance Magic Validation To Daily Results
- **Location**: `app/services/broker_accounts/daily_result_recorder.rb`, `spec/requests/api/broker_account_daily_results_spec.rb`, optional `app/services/licenses/magic_number_authorizer.rb`
- **Description**: Extend daily-results authorization so rollout clients can submit either legacy lane magic or allocated instance magic.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Existing lane-magic requests continue passing.
  - Instance-magic requests pass when `magic_number` belongs to the verified license + broker account + EA.
  - Unallocated magic still returns `invalid_magic_number`.
  - Existing uniqueness remains `broker_account + expert_advisor + magic_number + UTC day`.
  - If helper extraction is needed, keep it small and focused; do not rewrite the recorder.
- **Validation**:
  - `bundle exec rspec spec/requests/api/broker_account_daily_results_spec.rb`
  - Add a service spec if validation is extracted.

### Task 3.3: Preserve Existing Legacy Contract Tests
- **Location**: `spec/requests/api/licenses_verify_spec.rb`, `spec/requests/api/licenses_heartbeat_spec.rb`, `spec/services/licenses/lane_magic_number_allocator_spec.rb`
- **Description**: Add regression assertions that legacy lane behavior did not drift.
- **Dependencies**: Tasks 3.1 and 3.2
- **Acceptance Criteria**:
  - Verify still returns lane `magic_number`.
  - Heartbeat still does not return or rotate magic.
  - Lane allocator behavior and daily-results lane validation remain covered.
- **Validation**:
  - `bundle exec rspec spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb spec/services/licenses/lane_magic_number_allocator_spec.rb`

## Sprint 4: Docs, EA Shared Contract, And Pandora Rollout
**Goal**: Update contract docs and define simple client rules for Pandora Box first, then future EAs.

**Demo/Validation**:
- A developer can update an EA shared guard from the docs without guessing endpoint order, error behavior, or migration safety rules.

### Task 4.1: Update Rails API Documentation
- **Location**: `docs/database_model_reference.md`
- **Description**: Document `license_instance_magic_numbers`, `POST /api/v1/licenses/instance_magic`, and daily-results dual magic validation.
- **Dependencies**: Sprint 3
- **Acceptance Criteria**:
  - Database model map includes the new table and indexes.
  - API surface includes the new endpoint, request fields, response, and errors.
  - Daily-results docs state that `magic_number` may be legacy lane magic or instance magic during rollout.
- **Validation**:
  - Documentation review against request specs.

### Task 4.2: Update EA Shared Contract Docs
- **Location**: `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md`, `docs_eas/shared/license_guard_v1/README.md`, optional new `docs_eas/shared/license_guard_v1/backend-instance-magic-contract.md`
- **Description**: Move the proposed external MQL5 contract into the Rails repo's canonical shared EA docs.
- **Dependencies**: Sprint 3
- **Acceptance Criteria**:
  - Existing verify/heartbeat lane docs remain intact for legacy EAs.
  - New docs explain `instance_id`, `POST /licenses/instance_magic`, and `trade_identity_scope: "instance"`.
  - Docs state that upgraded EAs use instance magic for `CTrade.SetExpertMagicNumber()` and daily-results filtering.
  - Docs state that old EAs remain compatible but keep the old trade-magic overlap risk until upgraded.
  - Docs forbid local/random live trade magic fallback.
- **Validation**:
  - Compare against `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/shared/license_guard_v1/backend-instance-magic-contract-update.md`.

### Task 4.3: Define EA Startup And Migration Rules
- **Location**: `docs_eas/shared/license_guard_v1/README.md`, downstream Pandora Box shared-guard handoff notes
- **Description**: Specify the client sequence and production-safe upgrade behavior.
- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - Startup order:
    1. Run existing verify/authorization through the lane leader.
    2. Resolve or generate local chart `instance_id`.
    3. Call `POST /licenses/instance_magic`.
    4. Validate signed-32-bit-safe `magic_number`.
    5. Set `g_magic_number` and `CTrade.SetExpertMagicNumber()` from instance magic.
    6. Report daily results with instance magic.
  - Followers may call `instance_magic` for their own `instance_id` after lane authorization is healthy, without becoming heartbeat leaders.
  - If legacy lane-magic open positions exist for the chart symbol/account, the upgraded EA should refuse to initialize and show a clear migration-blocked status.
  - Support guidance: upgrade charts only when flat, or keep the previous EA version managing legacy-magic positions until they close.
- **Validation**:
  - Static review with the MQL5 shared-guard owner before Pandora Box rollout.

## Sprint 5: Verification, Audit Gate, And Rollout
**Goal**: Validate the change set, document production rollout, and avoid unsafe EA upgrades.

**Demo/Validation**:
- Rails specs pass.
- Docs are aligned.
- Rollout can proceed backend-first with legacy compatibility.

### Task 5.1: Targeted Rails Verification
- **Location**: test suite and local database
- **Description**: Run focused Rails checks for the changed API/data contract.
- **Dependencies**: Sprints 2 and 3
- **Acceptance Criteria**:
  - Migrations apply locally.
  - New and existing request/model/service specs pass.
  - No browser QA required because this is backend/API/docs work.
- **Validation**:
  - `bin/rails db:migrate`
  - `bundle exec rspec spec/models/license_instance_magic_number_spec.rb spec/services/licenses/instance_magic_number_allocator_spec.rb spec/requests/api/licenses_instance_magic_spec.rb spec/requests/api/broker_account_daily_results_spec.rb spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb spec/services/licenses/lane_magic_number_allocator_spec.rb`
  - `git diff --check`

### Task 5.2: Rails Review Gate
- **Location**: final implementation diff
- **Description**: Run the required Rails production-engineering audit gate.
- **Dependencies**: Task 5.1
- **Acceptance Criteria**:
  - Code patterns and efficiency: PASS.
  - Behavior and goal alignment: PASS.
  - Tests context: PASS or explicit gaps.
  - Database/data safety: PASS.
  - Security/privacy: PASS.
  - Browser QA: Not applicable.
- **Validation**:
  - Review changed files and `git status --short`.

### Task 5.3: Production Rollout Checklist
- **Location**: deployment notes or PR description
- **Description**: Define deploy order and client-facing support rules.
- **Dependencies**: Task 5.2
- **Acceptance Criteria**:
  - Deploy backend first.
  - Verify old EAs still use `/licenses/verify` lane magic successfully.
  - Verify new test payloads:
    - same `instance_id` returns same magic;
    - different `instance_id` on same broker account returns different magic;
    - different EA IDs on same broker account do not collide;
    - daily-results accepts instance magic;
    - unallocated magic fails closed.
  - Release Pandora Box shared-guard update to staging/demo accounts.
  - Only upgrade production charts when flat, unless a separate migration mode is implemented and tested.
  - Roll out other EAs later by adopting the same shared contract.
- **Validation**:
  - Manual staging API payload checks.
  - Downstream MQL5 compile/test in the EA repo before production EA release.

## Testing Strategy
- Request specs:
  - `licenses_instance_magic_spec.rb` for endpoint success/failure/stability/rate-limit/no-seat-mutation.
  - Existing verify and heartbeat specs to lock legacy compatibility.
  - Daily-results specs for both lane magic and instance magic.
- Model specs:
  - New instance mapping validations, normalization, uniqueness, and range.
- Service specs:
  - Collision-safe allocator behavior and legacy-lane collision avoidance by broker identity.
- Migration review:
  - Additive table only, no backfill, no destructive changes.
- MQL5 validation:
  - Static shared-guard review from docs first.
  - Downstream compile/test in the Pandora Box EA repo before release.
  - Manual MT5 staging test with two charts on the same broker account verifying different runtime trade magic values.

## Potential Risks & Gotchas
- Legacy EAs remain compatible but still have the old lane-magic overlap risk until upgraded.
- The backend cannot detect MT5 open positions, so migration safety must be enforced by the EA and support process.
- If `instance_id` is regenerated too often by the EA, charts will receive new magic and lose continuity; EA persistence must be stable across restart/recompile.
- If two charts intentionally reuse the same `instance_id`, they will intentionally share the same instance magic. The EA should generate unique-enough IDs and avoid user-editable collisions.
- Requiring a live lane session for `instance_magic` improves bypass resistance but needs a documented retry/error path for followers and stale leaders.
- Existing broker-account company matching is case-sensitive in some flows; do not broaden normalization in this plan unless audit evidence shows it is necessary.
- Do not recycle instance magic numbers by default; old history or open positions may still reference them.
- Do not log license keys, raw secrets, authorization headers, or private customer/billing data while adding support logs.

## Rollback Plan
- The backend change is additive. If issues appear, disable or stop calling `POST /licenses/instance_magic` from upgraded EAs and keep legacy `/licenses/verify` lane behavior running.
- Database rollback can drop the new `license_instance_magic_numbers` table before any dependent feature requires it; after production use, treat the table as support/audit data and avoid destructive rollback without export/backup.
- Daily-results compatibility can be reverted to lane-only validation only if no upgraded EAs are live.
- EA rollout rollback: keep previous Pandora Box build managing legacy-magic positions until flat; do not switch charts between old and new magic while positions are open.

## Production Rollout Checklist
- Deploy Rails backend first with the additive migration and no EA client changes yet.
- Confirm legacy EAs still verify, heartbeat, trade with lane magic, and submit daily results through the existing contract.
- Run staging API payload checks:
  - same `instance_id` returns the same magic;
  - different `instance_id` values on the same broker account return different magic values;
  - different EA IDs on the same broker account do not collide numerically;
  - `instance_magic` does not mutate online seat leases;
  - `lane_session_required` is returned when no active lane session exists;
  - daily results accept allocated instance magic;
  - daily results reject unallocated magic with `invalid_magic_number`.
- Release the Pandora Box shared-guard update to staging/demo accounts before production.
- In MT5 staging/demo, run at least two Pandora Box charts on the same broker account and confirm different runtime magic values, restart stability, accepted daily results, and no request storm during stale leader recovery.
- Upgrade production charts only when flat, or keep the previous EA version managing legacy-magic positions until they close.
- Roll out future EAs only after adopting the same shared contract and passing downstream compile/test in the EA repo.

## Open Questions
- None blocking. User confirmed the read-only active-session guard and truncated/hash `instance_id` logging recommendations.

## Sprint 1 Execution Log
- [PASS] Re-read Sprint 1 scope and relevant contract docs.
- [PASS] Command: `bundle exec rspec spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb spec/requests/api/broker_account_daily_results_spec.rb` (24 examples, 0 failures).
- [PASS] Added frozen upcoming `POST /licenses/instance_magic` contract to `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md`.
- [PASS] Updated `docs_eas/shared/license_guard_v1/README.md` with legacy-vs-upgraded EA runtime magic rules, `instance_id` rules, and migration safety guidance.
- [PASS] Added frozen upcoming API contract notes to `docs/database_model_reference.md`.

## Sprint 2 Execution Log
- [PASS] Added additive migration `db/migrate/20260603120000_create_license_instance_magic_numbers.rb`.
- [PASS] Command: `bin/rails db:migrate`.
- [PASS] Added `LicenseInstanceMagicNumber` model, associations, and factory.
- [PASS] Added `Licenses::InstanceMagicNumberAllocator` with stable reuse, per-broker collision avoidance, legacy lane-magic avoidance, ownership validation, and truncated/hash `instance_id` logging.
- [PASS] Added model and allocator specs.
- [PASS] Command: `bundle exec rspec spec/models/license_instance_magic_number_spec.rb spec/services/licenses/instance_magic_number_allocator_spec.rb` (15 examples, 0 failures).
- [PASS] Command: `bundle exec rspec spec/services/licenses/lane_magic_number_allocator_spec.rb spec/models/license_lane_magic_number_spec.rb spec/models/license_instance_magic_number_spec.rb spec/services/licenses/instance_magic_number_allocator_spec.rb` (23 examples, 0 failures).
- [PASS] Command: `bin/rails zeitwerk:check`.
- [PASS] Command: targeted RuboCop on new model/service/spec/migration files.
- [PASS] Command: `git diff --check`.

## Sprint 3 Execution Log
- [PASS] Added route `POST /api/v1/licenses/instance_magic`.
- [PASS] Added `Api::V1::LicensesController#instance_magic` using existing license verification, existing broker-account lookup, read-only active lane-session guard, separate `instance_magic` rate-limit bucket, and `Licenses::InstanceMagicNumberAllocator`.
- [PASS] Extended `BrokerAccounts::DailyResultRecorder` to authorize either legacy lane magic or instance-scoped magic while preserving existing daily-results payload and response shape.
- [PASS] Added request specs for instance magic success, stable reuse, per-instance uniqueness, invalid identity, missing broker account, missing/invalid `instance_id`, stale lane session, separate rate limiting, and no online-seat mutation.
- [PASS] Added request coverage for daily results with instance-scoped magic.
- [PASS] Command: `bundle exec rspec spec/requests/api/licenses_instance_magic_spec.rb spec/requests/api/broker_account_daily_results_spec.rb` (16 examples, 0 failures).
- [PASS] Command: `bundle exec rspec spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb spec/requests/api/licenses_instance_magic_spec.rb spec/requests/api/broker_account_daily_results_spec.rb spec/services/licenses/instance_magic_number_allocator_spec.rb spec/models/license_instance_magic_number_spec.rb` (48 examples, 0 failures).
- [PASS] Command: `bin/rails zeitwerk:check`.
- [PASS] Command: `bin/rails routes -g instance_magic`.
- [PASS] Command: targeted RuboCop on changed controller/service/model/spec files.
- [PASS] Command: `git diff --check`.
- [INFO] Targeted RuboCop including `config/routes.rb` reports pre-existing array-spacing offenses on unrelated route lines; left unchanged to avoid unrelated formatting churn.

## Sprint 4 Execution Log
- [PASS] Updated `docs/database_model_reference.md` from frozen upcoming contract language to the implemented `license_instance_magic_numbers`, `POST /api/v1/licenses/instance_magic`, and dual daily-results magic contract.
- [PASS] Updated `docs_eas/shared/license_guard_v1/backend-entitlements-contract.md` to list `POST /licenses/instance_magic` as active, document call cadence, active lane-session retry behavior, support logging/privacy rules, daily-results dual magic rules, and Pandora Box rollout guidance.
- [PASS] Updated `docs_eas/shared/license_guard_v1/README.md` with the implemented instance-magic shared-guard sequence, cache/call rules, migration-blocked behavior, and Pandora Box staging/demo checklist.
- [PASS] Added `docs_eas/shared/license_guard_v1/backend-instance-magic-contract.md` as a focused EA maintainer handoff for the implemented endpoint and rollout rules.
- [PASS] Static review against `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/shared/license_guard_v1/backend-instance-magic-contract-update.md`.
- [PASS] Command: `bundle exec rspec spec/requests/api/licenses_instance_magic_spec.rb spec/requests/api/broker_account_daily_results_spec.rb` (16 examples, 0 failures).
- [PASS] Command: `bin/rails routes -g instance_magic`.
- [PASS] Command: `rg -n 'upcoming|Frozen upcoming|Proposed additive|successful verify responses only' docs_eas/shared/license_guard_v1/backend-entitlements-contract.md docs_eas/shared/license_guard_v1/README.md docs_eas/shared/license_guard_v1/backend-instance-magic-contract.md docs/database_model_reference.md` (no matches).
- [PASS] Command: `rg -n '[[:blank:]]$' docs/database_model_reference.md docs_eas/shared/license_guard_v1/backend-entitlements-contract.md docs_eas/shared/license_guard_v1/README.md docs_eas/shared/license_guard_v1/backend-instance-magic-contract.md docs/plans/mql5-license-instance-magic-contract-plan.md` (no matches).
- [PASS] Command: `git diff --check`.
- [INFO] Browser QA not applicable; Sprint 4 is API/docs handoff only.

## Sprint 5 Execution Log
- [PASS] Command: `bin/rails db:migrate`.
- [PASS] Command: `bundle exec rspec spec/models/license_instance_magic_number_spec.rb spec/services/licenses/instance_magic_number_allocator_spec.rb spec/requests/api/licenses_instance_magic_spec.rb spec/requests/api/broker_account_daily_results_spec.rb spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb spec/services/licenses/lane_magic_number_allocator_spec.rb` (53 examples, 0 failures).
- [PASS] Command: `bin/rails zeitwerk:check`.
- [PASS] Command: targeted RuboCop on changed controller/service/model/spec/migration files excluding `config/routes.rb` (10 files inspected, no offenses detected).
- [PASS] Command: `git diff --check`.
- [INFO] Command: `bin/brakeman -q` stopped before scanning because the binstub prepends `--ensure-latest` and local Brakeman is `7.1.1` while latest is `8.0.4`.
- [INFO] Command: `bundle exec brakeman -q` completed with 2 weak SQL warnings in unrelated `app/services/dashboard/main_presenter.rb` lines 413-414; no Brakeman warnings were reported in the license API/model/service/docs changes.
- [PASS] Review Gate: code quality and maintainability for changed files.
- [PASS] Review Gate: feature behavior and goal alignment with legacy API compatibility plus additive instance magic.
- [PASS] Review Gate: tests context for model, allocator service, request endpoint, daily-results compatibility, verify, heartbeat, and lane allocator.
- [PASS] Review Gate: database/data safety for additive table, foreign keys, uniqueness indexes, check constraints, no backfill, and reversible migration shape.
- [PASS] Review Gate: security/privacy for server-authoritative license verification, active lane-session guard, no seat mutation, scoped broker account lookup, no raw license/secret/instance-id logging in new code/docs.
- [PASS] Review Gate: frontend/browser contracts unchanged; Browser QA not applicable.
- [PASS] Added production rollout checklist to this plan.

## Execution Notes
- Because this touches licensing, public API contracts, and migrations, execute one sprint per batch unless the user explicitly asks to continue further.
- Do not create commits unless explicitly requested.
- Run the Audit Gate before finalizing implementation work.
