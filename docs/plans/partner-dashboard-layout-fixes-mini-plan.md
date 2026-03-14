# Plan: Partner Dashboard Layout Fixes

**Generated**: 2026-03-13
**Estimated Complexity**: Small-Medium

## Goal
Fix the current partner dashboard layout issues visible at the reported responsive width without changing backend behavior.

## Definition of Done
- The three chart summary cards render horizontally and keep sane spacing at the reported responsive width.
- The chart or empty-state area no longer creates a tall vertical blank block inside the chart card.
- The payout action card and the referrals section no longer overlap or visually stack into each other at the reported responsive width.
- Dark/light theme behavior remains intact and request specs still pass.

## Constraints
- Keep this as a layout-only follow-up on the existing Mosaic partner dashboard work.
- Preserve current presenter/controller/search/payout backend logic.
- Preserve `DASHBOARD_PALETTE`, theme toggle hooks, and current request-spec coverage.
- Prefer fixing the current ERB structure before adding new CSS or JS.

## Steps
1. Rework the chart card summary row so the three summary tiles stay horizontal at the reported responsive width and match Mosaic spacing.
2. Move or restructure the empty-state/chart area so it does not reserve a tall blank region when there is no paid-data chart to draw.
3. Audit the `show` layout grid and payout/referrals placement so the payout action panel cannot overlap the referrals section at the reported responsive width.
4. Re-run request specs and a targeted responsive browser QA pass on the affected widths.

## Status Log
- PASS: split the chart summary card from the chart or empty-state panel by introducing `app/views/dashboard/partner/_chart_plot_card.html.erb`.
- PASS: kept the three chart summary tiles on a horizontal row at the reported responsive width by simplifying the summary layout in `app/views/dashboard/partner/_chart_card.html.erb`.
- PASS: moved the payout action card into the right rail in `app/views/dashboard/partner/show.html.erb` so it no longer collides with the referrals content flow.
- PASS: `bundle exec rspec spec/requests/dashboard_partner_spec.rb`
- PASS: targeted Playwright QA in test env at `1354x522` dark mode confirmed the horizontal summary row, compact empty state, and non-overlapping payout/referrals layout.

## Audit Gate
- **Code pattern and efficiency**: PASS
  The fix stayed structural and view-scoped: one new partial for the chart or empty-state panel, minimal changes to the parent layout, no backend churn.
- **Feature behavior and goal alignment**: PASS
  The reported responsive issues are addressed directly: horizontal summary row, no tall blank chart block, and payout action separated from the referrals section flow.
- **Tests context**: PASS
  Existing request coverage still passes, and the responsive behavior was verified with a targeted browser QA pass.

## Open Questions
- None right now. The reported screenshots are specific enough to implement directly.
