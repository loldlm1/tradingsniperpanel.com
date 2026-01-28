# Dashboard UI/UX Audit (Mosaic)

## Goal
- Audit and improve all dashboard UI (layout, sidebar, and dashboard sections) using ui-ux-pro-max guidance and the Mosaic Cruip template guide.

## Definition of Done
- All dashboard views that use `layout "dashboard"` are inventoried and mapped to Mosaic source sections.
- UI/UX improvements applied to the dashboard layout/sidebar and related views/partials without editing vendor template files.
- Copy changes are I18n-driven; repeated UI is extracted to partials where it reduces duplication.
- Manual visual pass at common breakpoints and light/dark modes completed.
- Full test spec command runs green.

## Constraints
- Follow `docs/cruip_template_guide.md` and preserve Mosaic classes, JS hooks, IDs, and comment blocks.
- Keep controllers thin; prefer view/partial/CSS changes.
- No inline `<style>`/`<script>` in views; use assets or utilities.
- Respect existing I18n patterns; no hardcoded UI strings.

## Steps
1) Scope + inventory: list all controllers using `layout "dashboard"` and enumerate their views/partials.
2) Design system alignment: review `design-system/trading-sniper-panel/MASTER.md`; decide to keep or regenerate a dashboard-specific system using ui-ux-pro-max.
3) Audit pass: assess each dashboard view + sidebar against ui-ux-pro-max priorities (a11y, interaction, layout, typography, motion) and Mosaic guidance; capture issues and target fixes.
4) Implement improvements: update `app/views/layouts/dashboard.html.erb`, shared partials, and each dashboard page; keep Mosaic structure and hooks intact.
5) QA + tests: manual UI checks (375/768/1024/1440, light/dark) and run the full test spec.
6) Update this plan with decisions + command PASS/FAIL; archive when done.

## Decisions
- Scope: Mosaic user dashboard only (exclude ActiveAdmin).
- Visual direction: move toward `design-system/trading-sniper-panel/MASTER.md` palette/typography with reversible, low-complexity changes.
- Design system: regenerate a dashboard-specific system with ui-ux-pro-max; prioritize best fit for dashboard UX.
- Tests: run `bundle exec rspec`.
- Priority order: sidebar → settings → marketplace → courses → expert advisors → main + analytics (ignore partner view).

## Open Questions
- None.

## Execution Log (PASS/FAIL)
- PASS: `python3 /home/loldlm/.agents/skills/ui-ux-pro-max/scripts/search.py "trading fintech SaaS analytics dashboard professional clean" --design-system --persist --page dashboard --format markdown --project-name "Trading Sniper Panel" --output-dir design-system/trading-sniper-panel`
- PASS: `python3 /home/loldlm/.agents/skills/ui-ux-pro-max/scripts/search.py "enterprise analytics SaaS dashboard sidebar navigation data-dense" --design-system --format markdown`
- PASS: `cat > design-system/trading-sniper-panel/pages/dashboard.md` (dashboard-specific overrides)
- PASS: `rm .../design-system/trading-sniper-panel/design-system/trading-sniper-panel/MASTER.md`
- PASS: `rm .../design-system/trading-sniper-panel/design-system/trading-sniper-panel/pages/dashboard.md`
- PASS: `rmdir .../design-system/trading-sniper-panel/design-system/...` (cleanup nested output)
- PASS: `rg -l "violet" app/views/layouts app/views/dashboards app/views/dashboard app/views/marketplace app/views/courses app/views/course_lessons app/views/expert_advisors app/views/shared | rg -v "app/views/dashboard/partner" | xargs perl -pi -e 's/violet/teal/g'`
- PASS: `apply_patch` (sidebar helper focus/rings + header focus rings + filter chip focus + card hover polish + course rating buttons)
- PASS: `bundle exec rspec`
