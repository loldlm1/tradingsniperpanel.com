# Staging Seed Stripe Idempotency Recovery

## Goal
- Make staging/production seeding resilient when existing `billing_plans` contain stale non-Stripe IDs (e.g. `seed_prod_*`, `seed_price_*`).

## Definition of Done
- `Billing::PlanCreator` recovers from missing Stripe product/price IDs by creating/finding fresh Stripe resources and persisting new IDs.
- Non-recoverable Stripe errors still raise.
- Targeted specs cover stale ID recovery.

## Constraints
- Keep Stripe required in non-test environments.
- Keep behavior idempotent across repeated `db:seed` runs.
- No destructive data operations.

## Steps
1. Add narrow recovery in `Billing::PlanCreator` for missing Stripe resources.
2. Add spec coverage for stale product/price ID recovery.
3. Run targeted specs.

## Open Questions
- None.

## Decisions
- Recovery is limited to Stripe "resource missing" retrieval failures; all other Stripe failures still raise.

## Command Log (PASS/FAIL)
- PASS: `sed -n '1,260p' app/services/billing/plan_creator.rb`
- PASS: `sed -n '1,260p' app/services/marketplace/plan_sync.rb`
- PASS: `sed -n '1,260p' app/services/marketplace/product_manager.rb`
- PASS: `bundle exec rspec spec/services/billing/plan_creator_spec.rb spec/seeds/runner_spec.rb spec/seeds/marketplace_seed_spec.rb`
