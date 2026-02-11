# Plan: Dashboard Plans Interval Selector Width

## Goal
Adjust the interval selector on `/dashboard/plans` so the background pill wraps the interval options instead of stretching across the full card width, matching the intended compact toggle design.

## Definition of Done
- Interval selector no longer renders as a full-width bar on desktop.
- All interval options remain visible/selectable and preserve existing active/inactive states.
- Layout remains usable on smaller screens (no clipped controls).
- Targeted request specs pass after the view update.

## Constraints
- Keep change scoped to plans page UI; no billing logic or checkout flow changes.
- Reuse existing Tailwind utility approach in the current view.
- Keep Alpine `period` behavior unchanged.

## Steps
1. Confirm current selector markup in `app/views/dashboards/plans.html.erb`.
2. Update selector container classes to content-width styling.
3. Keep mobile behavior safe with wrapping/overflow-friendly classes.
4. Run targeted request specs for plans/checkout pages.
5. Record results in this plan log.

## Open Questions
- None.

## Execution Log (PASS/FAIL)
- PASS: Located current interval selector markup in `app/views/dashboards/plans.html.erb`.
- PASS: Updated interval selector wrapper/button classes in `app/views/dashboards/plans.html.erb` to use compact `inline-flex` layout and horizontal overflow support.
- PASS: `bundle exec rspec spec/requests/subscription_upgrade_spec.rb spec/requests/plan_persistence_spec.rb` (20 examples, 0 failures).
