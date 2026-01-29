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

## Step 1 Output — Inventory
- Controllers using `layout "dashboard"`: `app/controllers/dashboards_controller.rb`, `app/controllers/dashboard/settings_controller.rb`, `app/controllers/dashboard/partner_controller.rb` (out of scope), `app/controllers/marketplace_controller.rb`, `app/controllers/marketplace_assets_controller.rb`, `app/controllers/expert_advisors_controller.rb`, `app/controllers/courses_controller.rb`, `app/controllers/course_lessons_controller.rb`.
- Dashboard layout + shared: `app/views/layouts/dashboard.html.erb`, `app/views/shared/_alert.html.erb`, `app/views/dashboard/shared/_badge.html.erb`, `app/views/dashboard/shared/_filter_chip.html.erb`, `app/views/dashboard/shared/_secondary_button.html.erb`, `app/views/dashboard/shared/_table_head.html.erb`.
- Dashboards pages: `app/views/dashboards/show.html.erb`, `app/views/dashboards/analytics.html.erb`, `app/views/dashboards/plans.html.erb`, `app/views/dashboards/billing.html.erb`, `app/views/dashboards/support.html.erb`, `app/views/dashboards/_stat_tile.html.erb`.
- Settings: `app/views/dashboard/settings/show.html.erb`.
- Marketplace: `app/views/marketplace/index.html.erb`, `app/views/marketplace/show.html.erb`, `app/views/marketplace/_product_card.html.erb`, `app/views/marketplace/cards/_course_card.html.erb`, `app/views/marketplace/cards/_digital_good_card.html.erb`, `app/views/marketplace/cards/_category_card.html.erb`, `app/views/marketplace/cards/_trending_card.html.erb`, `app/views/marketplace/show/_addon_row.html.erb`, `app/views/marketplace/show/_related_item.html.erb`.
- Courses: `app/views/courses/index.html.erb`, `app/views/courses/show.html.erb`, `app/views/courses/_index_card.html.erb`, `app/views/course_lessons/show.html.erb`.
- Expert Advisors: `app/views/expert_advisors/index.html.erb`, `app/views/expert_advisors/show.html.erb`, `app/views/expert_advisors/guides.html.erb`, `app/views/expert_advisors/_index_card.html.erb`, `app/views/expert_advisors/_show_addons.html.erb`, `app/views/expert_advisors/_show_license_card.html.erb`, `app/views/expert_advisors/_broker_accounts.html.erb`.

## Step 2 Output — Design System Alignment
- Regenerated dashboard-specific guidance in `design-system/trading-sniper-panel/pages/dashboard.md` (data-dense dashboard focus, sidebar behavior, interaction rules).
- Master system remains in `design-system/trading-sniper-panel/MASTER.md` (teal primary + Fira typography); current UI keeps Mosaic Aspekta fonts for now to avoid CSP/asset changes. Palette alignment already shifted to teal in dashboard views (reversible).

## Decisions
- Scope: Mosaic user dashboard only (exclude ActiveAdmin).
- Visual direction: move toward `design-system/trading-sniper-panel/MASTER.md` palette/typography with reversible, low-complexity changes.
- Design system: regenerate a dashboard-specific system with ui-ux-pro-max; prioritize best fit for dashboard UX.
- Tests: run `bundle exec rspec`.
- Priority order: sidebar → settings → marketplace → courses → expert advisors → main + analytics (ignore partner view).

## Open Questions
- Need local login/seeded user to complete agent-browser visual review in both themes.

## QA Findings (Manual)
- Sidebar: active states, collapse/expand, focus rings, and hover states are incorrect in both light and dark themes.
- Request: visually re-review the dashboard for improvements across both themes after fixes.

## Execution Log (PASS/FAIL)
- PASS: `apply_patch` (sidebar nav state classes + focus ring offsets in `app/helpers/dashboard_navigation_helper.rb`)
- PASS: `apply_patch` (sidebar active background + group link state adjustments in `app/helpers/dashboard_navigation_helper.rb`)
- PASS: `apply_patch` (expand/collapse toggle button in `app/views/layouts/dashboard.html.erb`)
- PASS: `python3 /home/loldlm/.agents/skills/ui-ux-pro-max/scripts/search.py "trading fintech SaaS analytics dashboard professional clean" --design-system --persist --page dashboard --format markdown --project-name "Trading Sniper Panel" --output-dir design-system/trading-sniper-panel`
- PASS: `python3 /home/loldlm/.agents/skills/ui-ux-pro-max/scripts/search.py "enterprise analytics SaaS dashboard sidebar navigation data-dense" --design-system --format markdown`
- PASS: `cat > design-system/trading-sniper-panel/pages/dashboard.md` (dashboard-specific overrides)
- PASS: `rm .../design-system/trading-sniper-panel/design-system/trading-sniper-panel/MASTER.md`
- PASS: `rm .../design-system/trading-sniper-panel/design-system/trading-sniper-panel/pages/dashboard.md`
- PASS: `rmdir .../design-system/trading-sniper-panel/design-system/...` (cleanup nested output)
- PASS: `rg -l "violet" app/views/layouts app/views/dashboards app/views/dashboard app/views/marketplace app/views/courses app/views/course_lessons app/views/expert_advisors app/views/shared | rg -v "app/views/dashboard/partner" | xargs perl -pi -e 's/violet/teal/g'`
- PASS: `apply_patch` (sidebar helper focus/rings + header focus rings + filter chip focus + card hover polish + course rating buttons)
- PASS: `bundle exec rspec`
- PASS: `rg -n "layout \"dashboard\"" app/controllers`
- PASS: `find app/views/{dashboards,dashboard,marketplace,courses,course_lessons,expert_advisors} -name '*.html.erb'`
