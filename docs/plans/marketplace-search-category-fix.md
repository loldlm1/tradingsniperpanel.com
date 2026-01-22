# Plan: Marketplace Search Category Fix

## Goal
Fix marketplace search queries for category links (e.g., `ea_tool`, `beginner`) so they no longer trigger database errors and add request specs that cover these cases.

## Definition of Done
- Search no longer uses `ILIKE` against integer `expert_advisors.ea_type`.
- Requests with `q=ea_tool` + `tab=expert_advisors` and `q=beginner` + `tab=courses` return 200.
- Request specs cover both query cases.
- Full test suite passes.

## Constraints
- Keep search logic in `Marketplace::IndexPresenter`.
- Use request specs for coverage.

## Steps
1. Update search conditions to handle EA type terms safely.
2. Add request specs for `ea_tool` and `beginner` search parameters.
3. Run full test suite.

## Decisions
- Match EA types by enum key and compare with equality instead of `ILIKE` on the integer column.

## Open Questions
- None.

## Commands (discovery)
- `sed -n '1,200p' app/models/expert_advisor.rb` (PASS)
- `sed -n '1,220p' app/services/marketplace/index_presenter.rb` (PASS)
- `sed -n '200,380p' app/services/marketplace/index_presenter.rb` (PASS)
- `sed -n '1,220p' spec/requests/marketplace_filters_spec.rb` (PASS)
- `sed -n '1,220p' spec/requests/marketplace_spec.rb` (PASS)
- `sed -n '1,200p' spec/factories/marketplace_products.rb` (PASS)
- `sed -n '1,200p' spec/factories/billing_plans.rb` (PASS)
- `sed -n '1,200p' spec/factories/expert_advisors.rb` (PASS)

## Commands (execution)
- `bundle exec rspec` (FAIL)
- `bundle exec rspec` (PASS)
