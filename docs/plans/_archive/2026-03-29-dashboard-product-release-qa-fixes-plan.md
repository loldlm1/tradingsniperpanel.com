# Plan: Dashboard Product Release QA Fixes

**Generated**: 2026-03-29
**Status**: Completed

## Goal
Fix the two blocking issues found in the visual QA sprint for dashboard product release notifications, then rerun the Firefox headless audit to confirm deploy readiness.

## Definition of Done
- Entitled EA owners see EA update items in the dashboard notification dropdown.
- The notification dropdown stays on-canvas at `375px`.
- The QA audit script runs again and the updated report reflects the new outcome.

## Constraints
- Keep the fix scoped to the release-notification request path and dropdown UI.
- Preserve the existing bell/dropdown pattern and dismissal behavior.
- Use the existing Firefox headless audit flow and artifact paths.

## Steps
1. Reproduce the owner-visible EA omission through the real request path and identify the divergence from the service-level presenter call.
2. Fix the EA visibility bug with focused test coverage.
3. Fix the mobile dropdown alignment in the Mosaic header partial.
4. Rerun the Playwright Firefox headless audit and update the QA report/plan with PASS or FAIL.

## Open Questions
- None at start; use the local seeded QA state and current release batch unless a blocker appears.

## Execution Notes
- PASS: isolated the request-path bug to `@accessible_eas` being unset when the notification presenter was built on dashboard requests
- PASS: fixed notification setup to fall back to fresh access/service data instead of assuming controller ivars were already populated
- PASS: fixed the mobile dropdown to anchor left on mobile and right from `sm` upward
- PASS: added a request regression proving an entitled EA owner sees an EA update on `dashboard_path`
- PASS: command `bundle exec rspec spec/requests/dashboard_product_releases_spec.rb spec/services/dashboard/product_release_notification_presenter_spec.rb`
- PASS: command `node script/product_release_visual_qa.mjs`

## Outcome
- PASS: entitled owners now see EA update items in the real dashboard request path
- PASS: the dropdown stays fully on-canvas at `375px`
- PASS: the Firefox headless audit reran cleanly across owner, non-owner, EN, ES, dark mode, and dismiss flows
