# Fibonacci Base + Addons Rollout Plan

## Goal
- Launch Fibonacci Elite as a subscription base EA plus one-time addons using the existing Rails marketplace and licensing architecture, with minimal risk and no checkout UX regressions.
- Add addon guide access under the Expert Advisors guides flow (not marketplace detail pages), gated by base + addon ownership.

## Definition of Done
- Fibonacci subscription plans are seeded and active:
- `fibonacci_elite_monthly` at `$40`
- `fibonacci_elite_annual` at `$360` (25% annual discount)
- Fibonacci base EA is seeded in production and prod-mirror profiles with guide content and EA artifact wiring.
- All 8 Fibonacci addons are seeded as one-time marketplace products with canonical keys and pricing from `docs_eas/fibonacci_ea/backend-entitlements-contract.md`.
- `POST /api/v1/licenses/verify` success payload always includes `granted_addons` (empty array when none), computed from server-side entitlements.
- Marketplace product pages keep current checkout sidebar behavior unchanged.
- New addon guide pages exist in Expert Advisors guide flow and require:
- base EA entitlement
- ownership of that addon
- Fibonacci EA show page addon cards show:
- `Buy addon` for unowned addons (links to marketplace product page)
- `View guide` for owned addons (links to addon guide page)
- QA seeds include only simple scenarios:
- base-only user
- base + partial-owned-addons user
- Targeted specs pass for seeds, entitlement response contract, addon guide access/rendering, and presenter CTA switching.

## Constraints
- Keep controllers thin and put business logic in services/presenters/policies.
- Keep seeding idempotent and compatible with `SEED_PROFILE=prod_mirror`.
- Do not introduce addon bundle permutation generation.
- Do not change existing marketplace checkout flow, pricing checkout metadata shape, or Stripe integration behavior.
- Use EN/ES locale keys and markdown content with fallback to EN when localized copy is missing.

## Steps
1. Create Fibonacci catalog constants/mappings (tier keys, addon keys, prices, copy source files, image/source asset paths) in seed-support code.
2. Add Fibonacci subscription billing plans and copy wiring (dashboard + landing + pricing catalog) with tier-safe rendering.
3. Seed Fibonacci base EA + base marketplace product for production and prod-mirror profiles.
4. Seed Fibonacci one-time addon billing plans, `Addon` records, and marketplace products with canonical keys and fixed prices.
5. Implement `granted_addons` response assembly in verify API from server-side entitlements only, normalized and always present on success.
6. Add Expert Advisors addon-guide route/controller/view path using existing guide layout/styling and markdown renderer.
7. Add addon guide access policy requiring base entitlement + addon ownership (preserve privileged role bypass behavior).
8. Extend Fibonacci EA show presenter/view addon cards to switch CTA between `Buy addon` and `View guide` based on ownership.
9. Expand QA seed fixtures minimally (base-only, base+partial) and ensure they are easy to re-seed for staging QA.
10. Add/update focused specs and run targeted validation suite before implementation sign-off.

## Open Questions
- None blocking for implementation.

## Decisions Confirmed
- All Fibonacci addons remain separately purchased one-time items.
- Marketplace purchase pages remain unchanged with checkout sidebar.
- Addon documentation uses a new guide-only path in Expert Advisors flow.
- Addon guide visibility requires both Fibonacci base access and addon ownership.
- QA seeds remain minimal: base-only and base+partial users only.

## Command Log (PASS/FAIL)
- PASS: `ls -1 docs/plans | rg 'fibonacci|addon|rollout' -n || true`
- PASS: `test -f docs/plans/fibonacci-base-addons-rollout.md && echo EXISTS || echo MISSING`
- PASS: `bundle exec ruby -c app/controllers/api/v1/licenses_controller.rb`
- PASS: `bundle exec ruby -c app/controllers/expert_advisors_controller.rb`
- PASS: `bundle exec ruby -c app/services/expert_advisors/show_presenter.rb`
- PASS: `bundle exec ruby -c app/services/licenses/granted_addons.rb`
- PASS: `bundle exec ruby -c db/seeds/runner.rb`
- PASS: `bundle exec ruby -c db/seeds/shared.rb`
- PASS: `bundle exec rspec spec/services/licenses/granted_addons_spec.rb`
- PASS: `bundle exec rspec spec/requests/api/licenses_verify_spec.rb`
- PASS: `bundle exec rspec spec/services/expert_advisors/show_presenter_spec.rb`
- FAIL: `bundle exec rspec spec/requests/expert_advisors_spec.rb`
- PASS: `bundle exec rspec spec/requests/expert_advisors_spec.rb`
- PASS: `bundle exec rspec spec/seeds/runner_spec.rb`
- PASS: `bundle exec rspec spec/services/licenses/granted_addons_spec.rb spec/requests/api/licenses_verify_spec.rb spec/services/expert_advisors/show_presenter_spec.rb spec/requests/expert_advisors_spec.rb spec/seeds/runner_spec.rb`
- PASS: `bundle exec rails routes | rg "dashboard_expert_advisor_addon_guide|api/v1/licenses/verify"`
