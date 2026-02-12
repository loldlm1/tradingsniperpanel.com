# Pandora Prod Mirror Launch Seeds

## Goal
- Ship a production-ready `prod_mirror` seed shape with:
- Subscription tiers `basic` and `pandora_pro` only.
- Pandora-only one-time marketplace product at `$299`.
- Updated EN/ES EA guides (including a new EN Sniper guide).
- Stripe-backed idempotent seeding in all non-test environments.

## Definition of Done
- `SEED_PROFILE=prod_mirror` seeds:
- `basic_monthly=2000`, `basic_annual=18000`, `pandora_pro_monthly=3000`, `pandora_pro_annual=27000`.
- Sniper + Pandora EAs with correct bundles and EN/ES guides.
- Pandora marketplace product only, priced at `29900`, with one attached image and no markdown inline image in the description.
- `full_qa` keeps the broad QA catalog behavior.
- Non-test seeding fails fast when Stripe is not configured.
- Targeted specs pass for seed runner, pricing catalog, landing pricing, and marketplace seed behavior.

## Constraints
- Keep seed operations idempotent both locally and on Stripe.
- Preserve `full_qa` breadth; scope launch shape changes to `prod_mirror`.
- Avoid destructive git operations and avoid unrelated file churn.

## Steps
1. Add/translate Sniper EN guide and wire per-EA guide loading.
2. Update `prod_mirror` EA + bundle definitions (Sniper and Pandora).
3. Update `prod_mirror` billing tiers and tier inheritance semantics.
4. Add profile-aware marketplace definitions + pruning for Pandora-only mirror.
5. Enforce Stripe-required non-test seeding paths.
6. Update landing/dashboard EN/ES tier copy for `pandora_pro`.
7. Update/add specs and run targeted validation commands.

## Open Questions
- None.

## Decisions
- `pandora_pro` is the second production tier and includes previous-tier benefits.
- `prod_mirror` must align to production launch shape; `full_qa` remains broad.
- Stripe is required in non-test environments for plan/product seed creation.

## Command Log (PASS/FAIL)
- PASS: `git status --short`
- PASS: `bundle exec rspec spec/seeds/runner_spec.rb spec/seeds/marketplace_seed_spec.rb spec/services/billing/pricing_catalog_spec.rb spec/services/marketing/neon_landing_pricing_spec.rb spec/requests/home_pricing_cta_spec.rb`
- PASS: `git diff -- db/seeds/shared.rb`
- PASS: `git diff -- db/seeds/runner.rb`
- PASS: `git diff -- spec/seeds/runner_spec.rb`
