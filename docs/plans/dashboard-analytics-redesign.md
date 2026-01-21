# Dashboard Analytics Redesign

Goal
- Replace dashboards#analytics view with the Mosaic `dashboard_analytics.html` structure and hook each card to real data per `dashboard_analytics_cards_en.md`.

Definition of Done
- `dashboards#analytics` matches the Mosaic layout/sections with HTML comments preserved.
- All 10 cards render real data with correct empty states and comparisons; date range picker drives PnL-related EA cards only.
- Charts render via Chart.js with dynamic data; no inline scripts; IDs/legend containers match the template.
- Copy sourced from I18n keys in EN/ES.
- Queries avoid N+1 and remain performant for large datasets.

Constraints
- Keep controllers thin; implement data in service objects under `app/services`.
- Do not edit vendor template assets under `app/assets/templates`.
- Keep HTML comment blocks and JS hooks (IDs, data-*).
- Time zone: user time zone if present; otherwise UTC.
- Use flatpickr date range; avoid inline scripts in views.
- Use fixed USD currency formatting.

Steps
1. Confirm UI scope (filters/sections/CTAs) and data definitions; finalize open questions.
2. Build data layer:
   - New presenter/service to compute date range, KPIs, datasets, and lists.
   - Reuse/extend `Dashboard::BrokerAnalyticsPresenter` if appropriate.
3. Update `app/views/dashboards/analytics.html.erb`:
   - Port Mosaic card markup with comments.
   - Remove old filters/table; wire data, empty states, and I18n keys.
4. Add JS for charts:
   - Render charts from data-* payloads; keep chart IDs/legend container IDs.
   - Ensure dark mode handling for chart colors.
5. Update translations (EN/ES) for new copy.
6. Add tests for calculations and analytics page rendering.
7. Verify in browser; update this plan with PASS/FAIL commands; archive when merged.

Decisions
- Remove EA/broker/account-type/compare filters and the “Top accounts by PnL” table to match the Mosaic layout.
- CTA defaults: EA cards -> `dashboard_expert_advisors_path`, course cards -> `dashboard_courses_path`, license/renew -> `dashboard_plans_path`.
- “Active now” uses last-24h `broker_account_daily_results` activity.
- Date range applies only to PnL-related EA cards (cards 1/3/5); courses excluded.
- Currency formatting fixed to USD.
- EA type chart uses separate segments for each `ea_type`.
- Report cards use 8 rows to mirror Mosaic density.
- After this feature, create a new plan for robust test coverage + parity card/section audit (Next Step).

Open Questions
- None.

Course Cards
- Use a fixed last-30-day window.

Commands (PASS/FAIL only)
- `ls` (PASS)
- `rg -n "dashboards#analytics|analytics" config/routes.rb app -g"*.rb" -g"*.erb" -g"*.haml" -g"*.slim"` (PASS)
- `sed -n '1,240p' mosaic-html/dashboard_analytics.html` (PASS)
- `rg -n "<!--" -n mosaic-html/dashboard_analytics.html` (PASS)
- `sed -n '1,260p' app/views/dashboards/analytics.html.erb` (PASS)
- `sed -n '1,240p' app/views/layouts/dashboard.html.erb` (PASS)
- `sed -n '1,200p' app/controllers/dashboards_controller.rb` (PASS)
- `sed -n '1,560p' app/services/dashboard/broker_analytics_presenter.rb` (PASS)
- `sed -n '1,240p' dashboard_analytics_cards_en.md` (PASS)
- `sed -n '1,240p' docs/database_model_reference.md` (PASS)
- `sed -n '1,240p' docs/cruip_template_guide.md` (PASS)
- `rg -n "analytics-card|analytics-charts|analytics-chart" app/assets app/javascript app/views -g"*.js" -g"*.erb" -g"*.scss" -g"*.css"` (PASS)
- `sed -n '1,240p' app/javascript/dashboard_analytics.js` (PASS)
- `rg -n "dashboard_analytics" app/views app/assets app/javascript config -g"*.erb" -g"*.js" -g"*.rb" -g"*.yml"` (PASS)
- `sed -n '1,200p' app/javascript/application.js` (PASS)
- `sed -n '1,200p' config/importmap.rb` (PASS)
- `rg -n "javascript_include_tag|importmap|chart|flatpickr" app/views/layouts/dashboard.html.erb` (PASS)
- `sed -n '420,520p' app/views/layouts/dashboard.html.erb` (PASS)
- `sed -n '620,820p' mosaic-html/dashboard_analytics.html` (PASS)
- `ls docs/plans` (FAIL)
- `ls docs` (PASS)
- `rg -n "analytics" config/locales/dashboard.en.yml` (PASS)
- `sed -n '480,620p' config/locales/dashboard.en.yml` (PASS)
- `rg -n "CourseEnrollment|course_enrollments|CourseLessonProgress|course_lesson_progress" app/services app/models app/controllers -g"*.rb"` (PASS)
- `sed -n '300,520p' app/services/dashboard/main_presenter.rb` (PASS)
- `sed -n '1,160p' app/services/dashboard/main_presenter.rb` (PASS)
- `sed -n '1,200p' app/assets/templates/mosaic/js/flatpickr-init.js` (PASS)
- `sed -n '1,200p' config/routes.rb` (PASS)
- `sed -n '1,200p' app/models/license.rb` (PASS)
- `rg -n "last_synced_at" app -g"*.rb"` (PASS)
- `rg -n "BrokerAccountDailyResults|daily_results" app/controllers -g"*.rb"` (PASS)
- `sed -n '1,200p' app/controllers/api/v1/broker_account_daily_results_controller.rb` (PASS)
- `rg -n "DailyResultRecorder" -n app/services -g"*.rb"` (PASS)
- `sed -n '1,220p' app/services/broker_accounts/daily_result_recorder.rb` (PASS)
- `sed -n '1,200p' app/services/licenses/license_verifier.rb` (PASS)
- `sed -n '1,200p' app/models/course_lesson.rb` (PASS)
- `sed -n '1,200p' app/models/course_enrollment.rb` (PASS)
- `sed -n '1,200p' app/models/course_lesson_progress.rb` (PASS)
- `sed -n '1,200p' app/services/courses/progress_tracker.rb` (PASS)
- `mkdir -p docs/plans` (PASS)
- `ls` (PASS)
- `sed -n '1,220p' docs/plans/dashboard-analytics-redesign.md` (PASS)
- `sed -n '1,260p' app/services/dashboard/analytics_presenter.rb` (PASS)
- `sed -n '260,520p' app/services/dashboard/analytics_presenter.rb` (PASS)
- `sed -n '520,1040p' app/services/dashboard/analytics_presenter.rb` (PASS)
- `sed -n '1,260p' app/views/dashboards/analytics.html.erb` (PASS)
- `sed -n '260,520p' app/views/dashboards/analytics.html.erb` (PASS)
- `sed -n '1,200p' app/helpers/dashboards_helper.rb` (PASS)
- `sed -n '1,200p' app/controllers/dashboards_controller.rb` (PASS)
- `sed -n '1,260p' app/javascript/dashboard_analytics.js` (PASS)
- `sed -n '260,520p' app/javascript/dashboard_analytics.js` (PASS)
- `sed -n '520,1040p' app/javascript/dashboard_analytics.js` (PASS)
- `rg -n "\\?\\." app/javascript/dashboard_analytics.js` (PASS)
- `rg -n "chart|Chart" config/importmap.rb` (FAIL)
- `rg -n "Chart" app/assets app/javascript app/views -g"*.js" -g"*.erb" -g"*.scss" -g"*.css"` (PASS)
- `rg -n "analytics-card" app/assets/templates/mosaic/js/dashboard-charts.js` (FAIL)
- `rg -n "card-0|card-10|card-08|card-09" app/assets/templates/mosaic/js/dashboard-charts.js` (PASS)
- `rg -n "chart|Chart|flatpickr|dashboard_analytics" app/views/layouts/dashboard.html.erb` (PASS)
- `sed -n '420,500p' app/views/layouts/dashboard.html.erb` (PASS)
- `sed -n '1,200p' app/assets/templates/mosaic/js/flatpickr-init.js` (PASS)
- `rg -n "dashboard\\.analytics" config/locales/dashboard.en.yml` (FAIL)
- `sed -n '480,820p' config/locales/dashboard.en.yml` (PASS)
- `sed -n '480,820p' config/locales/dashboard.es.yml` (PASS)
- `sed -n '1,200p' spec/requests/dashboard_analytics_spec.rb` (PASS)
- `rg -n "analytics-card-02|Active Users" -n app/views/dashboards/analytics.html.erb` (PASS)
- `sed -n '90,160p' app/views/dashboards/analytics.html.erb` (PASS)
- `sed -n '1,200p' dashboard_analytics_cards_en.md` (PASS)
- `ls spec/services/dashboard` (PASS)
- `sed -n '1,200p' spec/services/dashboard/broker_analytics_presenter_spec.rb` (PASS)
- `sed -n '1,200p' spec/services/dashboard/main_presenter_spec.rb` (PASS)
- `rg -n "broker_account_daily_result" spec/factories` (PASS)
- `sed -n '1,120p' spec/factories/broker_account_daily_results.rb` (PASS)
- `rg -n "factory :course_enrollment" -n spec/factories` (PASS)
- `sed -n '1,120p' spec/factories/course_enrollments.rb` (PASS)
- `rg -n "factory :course_lesson_progress" spec/factories` (PASS)
- `sed -n '1,160p' spec/factories/course_lesson_progresses.rb` (PASS)
- `rg -n "factory :course_lesson" spec/factories` (PASS)
- `sed -n '1,120p' spec/factories/course_lessons.rb` (PASS)
- `rg -n "factory :course_module" spec/factories` (PASS)
- `sed -n '1,120p' spec/factories/course_modules.rb` (PASS)
- `rg -n "factory :course" spec/factories` (PASS)
- `sed -n '1,160p' spec/factories/courses.rb` (PASS)
- `rg -n "factory :user" spec/factories -n` (PASS)
- `sed -n '1,120p' spec/factories/users.rb` (PASS)
- `sed -n '1,120p' spec/factories/broker_accounts.rb` (PASS)
- `sed -n '1,160p' spec/factories/licenses.rb` (PASS)
- `apply_patch (app/javascript/dashboard_analytics.js)` (PASS)
- `rg -n "\\?\\." app/javascript/dashboard_analytics.js` (FAIL)
- `apply_patch (spec/services/dashboard/analytics_presenter_spec.rb)` (PASS)
- `bundle exec rspec spec/services/dashboard/analytics_presenter_spec.rb` (FAIL)
- `rg -n "account_number" app/models/broker_account.rb` (PASS)
- `sed -n '1,120p' app/models/broker_account.rb` (PASS)
- `apply_patch (app/services/dashboard/analytics_presenter.rb)` (PASS)
- `apply_patch (spec/services/dashboard/analytics_presenter_spec.rb)` (PASS)
- `bundle exec rspec spec/services/dashboard/analytics_presenter_spec.rb` (PASS)
- `git status -sb` (PASS)
- `bundle exec rspec spec/requests/dashboard_analytics_spec.rb` (FAIL)
- `apply_patch (spec/requests/dashboard_analytics_spec.rb)` (PASS)
- `bundle exec rspec spec/requests/dashboard_analytics_spec.rb` (PASS)
- `cat <<'EOF' > docs/plans/dashboard-analytics-test-coverage-audit.md` (PASS)
- `bundle exec rspec` (PASS)
