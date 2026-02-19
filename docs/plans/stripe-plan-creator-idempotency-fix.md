# Plan: Stripe PlanCreator Idempotency Fix

## Goal
Fix Stripe `IdempotencyError` during plan seeding (`setup_staging.sh` and `reset_staging_db.sh`) by ensuring `Billing::PlanCreator` idempotency keys remain stable for retries but change when request parameters change.

## Definition of Done
- `Billing::PlanCreator` no longer reuses the same idempotency key for different Stripe create payloads.
- Staging seed flows can rerun without raising Stripe idempotency key mismatch errors for plan prices/products.
- A spec reproduces the parameter-mismatch scenario and verifies no idempotency conflict is raised.
- Relevant billing specs pass.

## Constraints
- Preserve retry safety: identical request payloads must keep the same idempotency key.
- Avoid changing billing plan business rules or seed definitions.
- Keep the patch localized to `Billing::PlanCreator` and its specs.

## Steps
1. Inspect current `Billing::PlanCreator` key generation against Stripe create params.
2. Update idempotency key derivation to fingerprint full create payloads.
3. Add/extend spec coverage for “same logical plan key, changed create params”.
4. Run targeted specs and record PASS/FAIL results.

## Open Questions
- None.

## Execution Log (PASS/FAIL)
- PASS: Created active plan doc `docs/plans/stripe-plan-creator-idempotency-fix.md` before coding.
- PASS: Updated `app/services/billing/plan_creator.rb` to derive idempotency keys from normalized Stripe create payload fingerprints (product and price create calls).
- PASS: Added regression coverage in `spec/services/billing/plan_creator_spec.rb` simulating Stripe idempotency collision when same key is reused with changed params.
- PASS: `bundle exec rspec spec/services/billing/plan_creator_spec.rb`
- PASS: `bundle exec rspec spec/services/billing`
- PASS: `bundle exec rspec` (full suite) -> `463 examples, 0 failures`
