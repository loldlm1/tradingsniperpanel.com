# Seeds Daily Results Magic Alignment

## Goal
Make seeds compatible with the new daily-results contract by ensuring seeded `BrokerAccountDailyResult` rows include required `expert_advisor` and `magic_number` values.

## Definition of Done
- `Seeds::DashboardMain.seed_daily_results` creates valid rows with `expert_advisor` + `magic_number`.
- `Seeds::DashboardAnalytics.seed_recent_results` creates valid rows with `expert_advisor` + `magic_number`.
- Seeded `magic_number` values come from lane allocation logic (stable per lane), not ad-hoc random values.
- Seed/deploy path no longer raises `ActiveRecord::RecordInvalid` for missing daily-results fields.

## Constraints
- Keep scope minimal: patch only seed code paths that create `BrokerAccountDailyResult`.
- Reuse existing service objects when possible (`Licenses::LaneMagicNumberAllocator`).
- Avoid schema/model refactors.

## Steps
1. Add seed helper(s) to resolve license/EA context and allocate/reuse lane `magic_number` for a broker account.
2. Update both daily-results seed insert points to pass `expert_advisor` and `magic_number`.
3. Align duplicate checks to lane identity (`broker_account + expert_advisor + magic_number + UTC day`).
4. Run focused seed validation and record PASS/FAIL in plan.

## Open Questions
- None blocking.

## Execution Log
- [PASS] Created active plan for seed daily-results compatibility fix.
- [PASS] Updated `db/seeds/shared.rb` to resolve lane context via `Licenses::LaneMagicNumberAllocator` and include `expert_advisor` + `magic_number` in both daily-results create paths.
- [PASS] Updated daily duplicate check to lane-aware identity (`broker_account_id + expert_advisor_id + magic_number + UTC day`).
- [FAIL] `bin/rails db:drop db:create db:migrate db:seed` (blocked before feature path by missing `MASTER_ADMIN_EMAIL` bootstrap env var).
- [FAIL] `MASTER_ADMIN_EMAIL=... MASTER_ADMIN_PASSWORD=... REVENUE_SPLIT_US_PERCENT=30 REVENUE_SPLIT_CLIENT_PERCENT=70 bin/rails db:seed` (blocked before feature path by missing `STRIPE_PRIVATE_KEY` in non-test env).
- [PASS] `bin/rails runner /tmp/verify_seed_lane_patch.rb` (loads seed modules and exercises patched methods): `idempotent=true`, `missing_context=0`, `distinct_magic_numbers=1`, `lane_rows=1`.
- [PASS] Audit Gate: code pattern and efficiency review passed (single-context allocation per account, no schema/model churn).
- [PASS] Audit Gate: feature behavior alignment passed (seeded daily results now satisfy required lane fields and lane-specific duplicate identity).
- [PASS] Audit Gate: tests context reviewed (full `db:seed` locally blocked by env constraints; focused runner validation covers changed code paths).
