# Online License Seat Security

## Goal
Implement robust online seat enforcement for EA license verification using heartbeat-based sessions with deterministic subscription caps (5..13) and additive one-time per-EA caps (+8).

## Definition of Done
- Online seat identity is deduped by `user + ea + company + account_number + account_type`.
- Multiple charts with same identity count as one seat.
- Heartbeat model enforced with `OnTimer` cadence (3m from EA) and server TTL 15m.
- Subscription seats are global across all EAs; one-time seats are per-EA and independent (+8).
- One-time seats are allocated before subscription seats when both are available.
- `licenses/verify` and `licenses/heartbeat` enforce capacity transactionally and return deterministic error on overflow.
- Comprehensive specs cover limits, allocation, stale expiry, request contracts, and concurrency boundaries.

## Constraints
- Keep controllers thin; place policy/allocator logic under `app/services/licenses`.
- Preserve existing license verification behavior and addon checks.
- Restrict broker account types to `real` and `demo`.
- Keep `broker_accounts/daily_results` independent from online seat logic.

## Steps
1. Add online session persistence model + migration + indexes.
2. Implement seat limit policy service (tier->cap and entitlement detection).
3. Implement transactional seat allocator service with source priority and TTL-aware counts.
4. Integrate allocator into `api/v1/licenses#verify` and add `api/v1/licenses#heartbeat`.
5. Add request/service/model specs for all critical paths and edge cases.
6. Run targeted + full specs and document outcomes.

## Open Questions
- None blocking; assumptions locked with user.

## Execution Log
- [PASS] Created active implementation plan: `docs/plans/online-license-seat-security.md`.
- [PASS] Decision: enforce strict online lease with 15m TTL and EA->API heartbeat; keep `daily_results` separate from seat logic.
- [PASS] Decision: online seat identity dedupe uses `user + ea + company + account_number + account_type`; account types restricted to `real|demo`.
- [PASS] Added migration/model for `license_online_sessions` with unique identity index and source/account type check constraints.
- [PASS] Added services `Licenses::OnlineSeatLimits` and `Licenses::OnlineSeatAllocator` (one-time first, subscription fallback, transactional seat allocation).
- [PASS] Integrated seat allocation into `api/v1/licenses#verify`; added `api/v1/licenses#heartbeat` route/action.
- [PASS] Added specs: `spec/models/license_online_session_spec.rb`, `spec/services/licenses/online_seat_limits_spec.rb`, `spec/services/licenses/online_seat_allocator_spec.rb`, `spec/requests/api/licenses_heartbeat_spec.rb`; updated `spec/requests/api/licenses_verify_spec.rb`.
- [PASS] Command: `bundle exec rails db:migrate`
- [FAIL] Command: `bundle exec rspec spec/models/license_online_session_spec.rb spec/services/licenses/online_seat_limits_spec.rb spec/services/licenses/online_seat_allocator_spec.rb spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb` (429 regressions from zero subscription cap when billing tier data absent).
- [PASS] Decision: fallback to base subscription cap (5) for verified `access_source=subscription` licenses when active billing tier cannot be resolved.
- [PASS] Command: `bundle exec rspec spec/models/license_online_session_spec.rb spec/services/licenses/online_seat_limits_spec.rb spec/services/licenses/online_seat_allocator_spec.rb spec/requests/api/licenses_verify_spec.rb spec/requests/api/licenses_heartbeat_spec.rb`
- [PASS] Command: `bundle exec rspec`
