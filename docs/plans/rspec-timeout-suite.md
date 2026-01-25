# RSpec suite timeout + slow spec improvements

Goal
- Remove per-example timeout that aborts slow tests.
- Optionally introduce a suite-level timeout (configurable) without per-example limits.
- Identify and improve the slowest specs.

Definition of Done
- No `Timeout.timeout` wrapper around individual examples.
- Suite runs without per-example timeouts; if a suite timeout is desired, it is applied only at the runner level and configurable.
- Slowest specs are reported (via `--profile`) and targeted fixes are merged or tracked.
- RSpec can run after test DB environment is set/prepared.

Constraints
- Keep changes minimal and localized to test setup and slow specs.
- Do not hide failures or swallow exceptions.

Steps
1. Locate current timeout hooks and RSpec config (spec helper/support, bin/rspec, rake tasks).
2. Prepare test DB environment and reproduce (`bundle exec rspec spec/`), capturing failures and slow specs (`--profile`).
3. Decide on suite-level timeout behavior (if any) and implement it at the runner level.
4. Remove per-example timeout wrapper and update docs/env vars.
5. Optimize top slow specs (ActiveAdmin access + seed specs first; reduce setup, stub external calls, trim factories) and add regression coverage as needed.
6. Re-run targeted specs and (optionally) the full suite.

DB environment fix (How to fix reliably)
- Ensure test DB is tagged correctly: `bin/rails db:environment:set RAILS_ENV=test`.
- Prepare/reset the test DB: `bin/rails db:prepare RAILS_ENV=test`.
- Verify dev/test DBs are distinct in `config/database.yml` or `DATABASE_URL`.

Open Questions
- Do you want any hard suite timeout at all? If yes, what duration and where (CI only vs local)?
- Should per-example timeouts be removed entirely or kept optional behind an env flag?
- Is it in scope to fix the current failing specs beyond timeout/performance issues?
- Preferred output for slow spec reporting (console only vs saved report file)?

Decisions (2026-01-25)
- Unlimited suite runtime for now (no hard suite timeout).
- Remove per-example timeouts entirely.
- Address failing specs where feasible and improve slow specs.
- OK to set test DB environment and prepare DB as part of repro.
- Proceed with ActiveAdmin access + seed spec performance optimizations next.

Commands run (PASS/FAIL only)
- `rg -n "Timeout\\.timeout|RSPEC_TIMEOUT|timeout" spec .rspec ./.rspec* config -g'*.rb'` PASS
- `sed -n '1,160p' spec/spec_helper.rb` PASS
- `bin/rails db:environment:set RAILS_ENV=test` PASS
- `bin/rails db:prepare RAILS_ENV=test` PASS
- `bundle exec rspec spec/ --profile 20` FAIL
- `bundle exec rspec spec/ --profile 20` PASS
- `bundle exec rspec spec/requests/expert_advisors_spec.rb spec/requests/dashboard_analytics_spec.rb` PASS
- `bundle exec rspec spec/requests/admin_access_spec.rb spec/services/admin/users/role_guard_spec.rb spec/seeds/marketplace_seed_spec.rb spec/seeds/qa_partner_seed_spec.rb` PASS
