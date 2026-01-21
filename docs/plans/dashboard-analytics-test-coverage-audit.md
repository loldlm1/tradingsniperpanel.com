# Dashboard Analytics Test Coverage + Parity Audit

Goal
- Add robust automated coverage for all analytics cards and complete a parity audit against the Mosaic template and the card data guide.

Definition of Done
- Presenter specs cover data/empty states for all 10 analytics cards.
- Request specs verify each card renders with required IDs/legends, HTML comment markers, and key I18n-driven headings in EN/ES.
- Parity audit checklist documents each Mosaic section/comment and confirms match or lists approved deviations.
- Tests use I18n keys (no hardcoded copy) and keep factories lean.

Constraints
- Use request specs for page-level behavior; presenter specs for calculations.
- Use I18n keys in specs; avoid inline copy.
- Keep controllers thin and business logic in services.
- Do not modify vendor template assets.

Decisions
- Parity audit stays inside this plan file.
- Request specs only (no system specs).
- Assert HTML comment markers in tests.
- Chart payload shape validation deferred; assert presence only.
- Cover EN and ES locales where feasible without bloating tests.

Steps
1. Draft a parity audit checklist mapping Mosaic comments/IDs to the current view.
2. Expand presenter specs to cover cards 1-10 (data + empty states, range behavior).
3. Add request specs to assert card/legend IDs, section headings, and HTML comment markers.
4. Add minimal factory helpers/traits for reusable analytics data setup.
5. Run targeted specs and adjust any deviations.

Parity Audit Checklist
- `<!-- Page header -->` (OK)
- `<!-- Cards -->` (OK)
- `<!-- Line chart (Analytics) -->` -> `analytics-card-01` (OK)
- `<!--  Line chart (Active Users Right Now) -->` -> `analytics-card-02` (OK)
- `<!-- Stacked bar chart (Acquisition Channels) -->` -> `analytics-card-03`, `analytics-card-03-legend` (OK)
- `<!-- Horizontal bar chart (Audience Overview) -->` -> `analytics-card-04`, `analytics-card-04-legend` (OK)
- `<!-- Report card (Top Channels) -->` (OK)
- `<!-- Report card (Top Pages) -->` (OK)
- `<!-- Report card (Top Countries) -->` (OK)
- `<!-- Doughnut chart (Sessions By Device) -->` -> `analytics-card-08`, `analytics-card-08-legend` (OK)
- `<!-- Doughnut chart (Visit By Age Category) -->` -> `analytics-card-09`, `analytics-card-09-legend` (OK)
- `<!-- Polar chart (Sessions By Gender) -->` -> `analytics-card-10`, `analytics-card-10-legend` (OK)

Open Questions
- None.

Commands (PASS/FAIL only)
- `sed -n '1,200p' docs/plans/dashboard-analytics-test-coverage-audit.md` (PASS)
- `apply_patch` (PASS)
- `rg -n "<!--" mosaic-html/dashboard_analytics.html` (PASS)
- `rg -n "<!--" app/views/dashboards/analytics.html.erb` (PASS)
- `rg -n "locale|set_locale|I18n" app/controllers -g"*.rb"` (PASS)
- `sed -n '1,140p' app/controllers/application_controller.rb` (PASS)
- `rg -n "class LocaleResolver" -n app lib` (PASS)
- `sed -n '1,200p' app/services/locale_resolver.rb` (PASS)
- `sed -n '1,160p' spec/factories/expert_advisors.rb` (PASS)
- `rg -n "ea_id" app/models/expert_advisor.rb` (PASS)
- `sed -n '1,220p' spec/services/dashboard/analytics_presenter_spec.rb` (PASS)
- `apply_patch (spec/services/dashboard/analytics_presenter_spec.rb)` (PASS)
- `sed -n '1,220p' spec/requests/dashboard_analytics_spec.rb` (PASS)
- `apply_patch (spec/requests/dashboard_analytics_spec.rb)` (PASS)
- `bundle exec rspec spec/services/dashboard/analytics_presenter_spec.rb spec/requests/dashboard_analytics_spec.rb` (PASS)
