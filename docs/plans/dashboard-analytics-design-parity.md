# Dashboard Analytics Design Parity + QA Seeds

Goal
- Restore 1:1 design parity with the Mosaic analytics template (layout, spacing, chart styling, legends, CTA/link styling) while keeping current data bindings.
- Expand seeds to populate all analytics cards for visual QA.

Definition of Done
- All analytics cards match the Mosaic template for structure and styling (classes, spacing, legends, CTA alignment), with approved deviations documented.
- Chart styles (colors, grid, padding, legend UI, tooltip look) mirror `mosaic-html/js/analytics-charts.js` as closely as possible.
- Analytics seeds generate realistic data for all 10 cards (PnL series, active-now, stacked bars, progress, report cards, doughnut/polar), and are idempotent.
- Development/staging seeds include the analytics seed data for the QA user.
- Run full test suite after implementation.

Constraints
- Keep controllers thin; confine logic to services/presenters.
- Do not edit vendor template assets under `app/assets/templates` or `mosaic-html`.
- Use I18n for copy; do not hardcode strings in views.
- Keep seed data idempotent and safe for repeated runs.
- Keep code clean and readable.

Possible Causes (Observed/Expected)
- Chart config drift: `app/javascript/dashboard_analytics.js` diverges from `mosaic-html/js/analytics-charts.js` (colors, padding, ticks, tooltip styling, bar thickness, animations).
- Legend styling mismatch: custom html legends differ from Mosaic (pill buttons vs circle swatches).
- Missing chart defaults/plugin parity (e.g., chart area plugin, layout padding, axis borders).
- Minor markup/class deviations from the Mosaic template in `app/views/dashboards/analytics.html.erb`.
- Insufficient seed data causing empty states and compressed layouts during QA.

Steps
1. Diff `app/views/dashboards/analytics.html.erb` against `mosaic-html/dashboard_analytics.html` and list class/structure mismatches (card headers, footers, spacing, legends).
2. Map each chart config in `app/javascript/dashboard_analytics.js` to `mosaic-html/js/analytics-charts.js`; align styling options while preserving data semantics.
3. Update chart legends to match Mosaic UI (pill buttons for doughnut/polar; circle swatches for bar charts).
4. Adjust any remaining markup mismatches (CTA alignment, padding, chart container sizing) to match the template.
5. Extend seeds to populate analytics cards (broker daily results, EA mix, course progress, lesson progress, license expirations, EA types).
6. Wire analytics seeds into `db/seeds/development.rb` and `db/seeds/staging.rb` for the QA user; keep idempotent.
7. Visual QA and document any approved deviations.
8. Run full test suite.

Decisions
- Chart numeric formatting matches Mosaic (compact numbers).
- Keep `app/javascript/dashboard_analytics.js` and align options to Mosaic.
- Add a new `Seeds::DashboardAnalytics` module.
- Seed analytics data for the QA user only.
- Use a 30-day data range for seeded analytics.

Open Questions
- None.

Commands (PASS/FAIL only)
- `ls db` (PASS)
- `ls db/seeds` (PASS)
- `sed -n '1,200p' db/seeds.rb` (PASS)
- `sed -n '1,200p' db/seeds/development.rb` (PASS)
- `sed -n '1,200p' db/seeds/shared.rb` (PASS)
- `rg -n "module Dashboard|DashboardSamples|DashboardMain" db/seeds -g"*.rb"` (PASS)
- `sed -n '620,900p' db/seeds/shared.rb` (PASS)
- `rg -n "seed_progress_for" db/seeds -g"*.rb"` (PASS)
- `sed -n '440,620p' db/seeds/shared.rb` (PASS)
- `rg -n "analytics-charts" -g"*.js"` (FAIL)
- `ls mosaic-html` (PASS)
- `ls mosaic-html/js` (PASS)
- `sed -n '1,260p' mosaic-html/js/analytics-charts.js` (PASS)
- `rg -n "Analytics" mosaic-html/dashboard_analytics.html` (PASS)
- `sed -n '660,760p' mosaic-html/dashboard_analytics.html` (PASS)
- `rg -n "htmlLegend|legend" mosaic-html/js/analytics-charts.js` (PASS)
- `sed -n '500,620p' mosaic-html/js/analytics-charts.js` (PASS)
- `sed -n '840,980p' mosaic-html/js/analytics-charts.js` (PASS)
- `sed -n '680,820p' mosaic-html/js/analytics-charts.js` (PASS)
- `apply_patch` (PASS)
- `sed -n '1,240p' docs/plans/dashboard-analytics-design-parity.md` (PASS)
- `sed -n '1,240p' app/views/dashboards/analytics.html.erb` (PASS)
- `sed -n '240,520p' app/views/dashboards/analytics.html.erb` (PASS)
- `sed -n '1,240p' mosaic-html/dashboard_analytics.html` (PASS)
- `rg -n "Line chart|Active Users|Acquisition Channels|Audience Overview|Top Channels|Top Pages|Top Countries|Sessions By" mosaic-html/dashboard_analytics.html` (PASS)
- `sed -n '650,780p' mosaic-html/dashboard_analytics.html` (PASS)
- `sed -n '780,930p' mosaic-html/dashboard_analytics.html` (PASS)
- `sed -n '930,1100p' mosaic-html/dashboard_analytics.html` (PASS)
- `sed -n '1100,1185p' mosaic-html/dashboard_analytics.html` (PASS)
- `rg -n "dashboard\\.analytics\\.cards\\.active_now\\.cta" config/locales` (FAIL)
- `rg -n "active_now" config/locales` (PASS)
- `sed -n '520,590p' config/locales/dashboard.en.yml` (PASS)
- `sed -n '590,660p' config/locales/dashboard.en.yml` (PASS)
- `rg -n "class AnalyticsPresenter|Analytics" app/services app/presenters app/models app/controllers` (FAIL)
- `sed -n '1,260p' app/services/dashboard/analytics_presenter.rb` (PASS)
- `sed -n '260,520p' app/services/dashboard/analytics_presenter.rb` (PASS)
- `sed -n '520,900p' app/services/dashboard/analytics_presenter.rb` (PASS)
- `rg -n "module Seeds|Seeds::" db/seeds/shared.rb` (PASS)
- `sed -n '1,240p' db/seeds/shared.rb` (PASS)
- `sed -n '420,720p' db/seeds/shared.rb` (PASS)
- `sed -n '720,940p' db/seeds/shared.rb` (PASS)
- `sed -n '1,220p' db/seeds/development.rb` (PASS)
- `sed -n '1,220p' db/seeds/staging.rb` (PASS)
- `sed -n '1,240p' dashboard_analytics_cards_en.md` (PASS)
- `rg -n "dashboard_analytics" app/javascript` (PASS)
- `sed -n '1,260p' app/javascript/dashboard_analytics.js` (PASS)
- `sed -n '260,520p' app/javascript/dashboard_analytics.js` (PASS)
- `sed -n '520,780p' app/javascript/dashboard_analytics.js` (PASS)
- `sed -n '1,260p' mosaic-html/js/analytics-charts.js` (PASS)
- `sed -n '260,520p' mosaic-html/js/analytics-charts.js` (PASS)
- `sed -n '520,780p' mosaic-html/js/analytics-charts.js` (PASS)
- `sed -n '780,1040p' mosaic-html/js/analytics-charts.js` (PASS)
- `sed -n '1040,1280p' mosaic-html/js/analytics-charts.js` (PASS)
- `sed -n '1280,1440p' mosaic-html/js/analytics-charts.js` (PASS)
- `rg -n "class CourseEnrollment" app/models` (PASS)
- `sed -n '1,200p' app/models/course_enrollment.rb` (PASS)
- `sed -n '1,220p' app/models/course_lesson_progress.rb` (PASS)
- `rg -n "class BrokerAccountDailyResult" app/models` (PASS)
- `sed -n '1,200p' app/models/broker_account_daily_result.rb` (PASS)
- `rg -n "class CourseLesson" app/models` (PASS)
- `sed -n '1,200p' app/models/course_lesson.rb` (PASS)
- `sed -n '1,240p' app/models/license.rb` (PASS)
- `sed -n '1,200p' app/services/courses/progress_tracker.rb` (PASS)
- `cat <<'EOF' > app/javascript/dashboard_analytics.js` (PASS)
- `apply_patch` (PASS)
- `bundle exec rspec` (FAIL)
- `bundle exec rspec` (PASS)
- `git status -sb` (PASS)
