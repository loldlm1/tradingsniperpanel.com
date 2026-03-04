# EA Entitlements Contract Alignment

## Goal
Align Rails entitlement APIs and persistence with `docs_eas/backend-entitlements-contract.md`, including strict lane-level `magic_number` behavior for verify/heartbeat/daily-results flows.

## Definition of Done
- `POST /api/v1/licenses/verify` returns a valid lane `magic_number` (`> 0`) on every success.
- Lane identity is enforced as `source + email + ea_id + company + account_number + account_type` (Rails source of truth), with stable `magic_number` per lane.
- `POST /api/v1/licenses/heartbeat` never rotates/reissues lane `magic_number`.
- `POST /api/v1/broker_accounts/daily_results` requires `magic_number` and validates lane ownership.
- Daily results uniqueness is enforced by `broker_account + ea_id + magic_number + UTC day`.
- Request/service/model specs cover contract success/errors and collision/duplication edge cases.
- `docs/database_model_reference.md` reflects updated schema/API contract.

## Constraints
- Keep controllers thin and place business logic in services/models.
- Keep Rails as source of truth and only report (not patch) shared MQL5 drift.
- Preserve existing seat-allocation policy semantics while adding lane magic handling.
- Use secure random positive bigint (`long`) assignment with collision-safe persistence.

## Steps
1. Add persistence for lane `magic_number` with uniqueness and normalized lane identity.
2. Wire verify flow to allocate/return lane `magic_number` and keep heartbeat non-rotating.
3. Update daily-results flow to require/validate `magic_number` and lane ownership.
4. Update DB/model uniqueness for daily-results (`broker_account + ea_id + magic_number + UTC day`).
5. Expand request/service/model specs for contract and edge cases.
6. Update internal docs (`docs/database_model_reference.md`).
7. Run migrations + targeted/full specs, then audit gate.

## Open Questions
- None blocking.

## Execution Log
- [PASS] Created active plan file: `docs/plans/ea-entitlements-contract-alignment.md`.
- [PASS] Decision: implement stable lane `magic_number` persistence via new `license_lane_magic_numbers` table keyed by `license + source + email + broker identity`.
- [PASS] Added migrations for lane magic persistence and daily-results uniqueness update by `broker_account + ea + magic_number + UTC day`.
- [PASS] Wired `licenses/verify` to allocate/return lane `magic_number` and kept `licenses/heartbeat` non-magic.
- [PASS] Wired `broker_accounts/daily_results` to require/validate `magic_number` against lane identity.
- [PASS] Updated/added request, model, factory, and service specs for lane magic and new daily-results rules.
- [PASS] Command: `bin/rails db:migrate`
- [FAIL] Command: targeted RSpec run (1 failure in `spec/requests/api/broker_account_daily_results_spec.rb` due old duplicate setup not matching new uniqueness key).
- [PASS] Decision: align duplicate test fixture to same `expert_advisor + magic_number` lane key.
- [PASS] Command: targeted RSpec run (`spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb spec/requests/api/broker_account_daily_results_spec.rb spec/models/broker_account_daily_result_spec.rb spec/models/license_lane_magic_number_spec.rb spec/services/licenses/lane_magic_number_allocator_spec.rb spec/services/licenses/license_verifier_spec.rb`)
- [PASS] Command: `bundle exec rspec`
- [PASS] Updated internal reference: `docs/database_model_reference.md` for lane magic + endpoint payload/error changes.
- [PASS] Added contract guard spec: heartbeat does not rotate existing lane `magic_number`.
- [PASS] Command: targeted RSpec re-run after heartbeat guard addition.
- [PASS] Command: final `bundle exec rspec` re-run.
- [PASS] Command: final targeted RSpec verification (`spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb spec/requests/api/broker_account_daily_results_spec.rb spec/services/licenses/lane_magic_number_allocator_spec.rb spec/models/license_lane_magic_number_spec.rb spec/models/broker_account_daily_result_spec.rb`).
- [PASS] Audit Gate (rails-expert): code pattern and efficiency.
- [PASS] Audit Gate (rails-expert): feature behavior and goal alignment.
- [PASS] Audit Gate (rails-expert): tests context (coverage/relevance/gaps).
