# Plan: Marketplace Index Test Expansion

## Goal
Expand automated coverage for the marketplace index redesign, focusing on search, filters, empty states, and section visibility.

## Definition of Done
- Service specs cover search, tag filtering, tab behavior, empty state logic, trending card selection fallbacks, and ordering assertions.
- Request specs cover rendering of sections for courses/digital goods, hiding sections when empty, and locale-sensitive copy via I18n.
- External dependencies (Pay/Stripe) are stubbed or isolated to avoid network calls.
- Full spec suite runs after the plan is implemented.

## Constraints
- Use request/system specs for full page flows and service specs for selection logic.
- Use I18n keys in specs instead of hardcoded UI copy.
- Keep factories lean; add traits only if needed.

## Steps
1. Identify critical edge cases not covered (no data, only courses, only EAs, query-only, tag-only, mixed filters). (DONE)
2. Add service specs for `Marketplace::IndexPresenter` covering those cases, trending fallbacks, and ordering. (DONE)
3. Add request specs to validate rendered sections and empty state behavior across locales. (DONE)
4. Run the relevant spec subset and adjust for stability/performance. (DONE)
5. Run the full spec suite. (DONE)

## Decisions
- Stub `Pay::Subscription` to avoid network access.
- Add ordering assertions to ensure query ordering is exercised.

## Commands (discovery)
- `sed -n '1,200p' docs/plans/marketplace-index-test-expansion.md` (PASS)
- `sed -n '1,220p' spec/services/marketplace/index_presenter_spec.rb` (PASS)
- `rg -n "published_at" db/schema.rb` (PASS)
- `sed -n '1,200p' spec/factories/course_enrollments.rb` (PASS)
- `sed -n '1,200p' spec/factories/licenses.rb` (PASS)
- `sed -n '1,200p' spec/factories/broker_accounts.rb` (PASS)
- `sed -n '1,200p' spec/factories/broker_account_daily_results.rb` (PASS)
- `sed -n '1,240p' app/models/billing_plan.rb` (PASS)
- `sed -n '1,200p' spec/factories/marketplace_purchases.rb` (PASS)
- `sed -n '1,200p' spec/factories/addons.rb` (PASS)
- `sed -n '1,260p' spec/services/marketplace/index_presenter_spec.rb` (PASS)
- `bundle exec rspec spec/services/marketplace/index_presenter_spec.rb spec/requests/marketplace_spec.rb spec/requests/marketplace_filters_spec.rb` (FAIL)
- `bundle exec rspec spec/services/marketplace/index_presenter_spec.rb spec/requests/marketplace_spec.rb spec/requests/marketplace_filters_spec.rb` (FAIL)
- `bundle exec rspec spec/services/marketplace/index_presenter_spec.rb spec/requests/marketplace_spec.rb spec/requests/marketplace_filters_spec.rb` (PASS)
- `bundle exec rspec` (PASS)
