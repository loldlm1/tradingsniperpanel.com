# Plan: Dashboard Courses Index Redesign

Goal:
- Rebuild `courses#index` to match the Mosaic mockup while keeping section comments and wiring real course data.

Definition of Done:
- `app/views/courses/index.html.erb` matches the layout and section comments from `mosaic-html/dashboard_courses_index.html` (page header, more actions, content grid, pagination, empty state).
- Course cards render real data (title, category, summary, modules/lessons counts, duration, progress, access state) using I18n keys for all copy (EN/ES).
- Search/filter/sort behavior is defined and wired with `filterable_cards` + Pagy, using clear data attributes and JS assets.
- Courses support a cover image with a Mosaic placeholder fallback.
- Queries are efficient (preloads for modules/lessons/enrollments) and controller remains thin (use a presenter/service).

Decisions:
- Search/filter are client-side using `filterable_cards`.
- Filter chips cover categories, tags, and access status (free/unlocked/locked) using `_filter_chip`.
- Sort uses `published_at` as the ordering key.
- Add a cover image field to courses, fallback to the Mosaic placeholder.
- Show the progress bar for locked courses but hide the "In progress" label.
- Paginate with Pagy server-side at 8 items per page.
- Sort only reorders the current page client-side.
- Combine all filter chips in a single list (no headings), aligned with the EA index UI.
- Tag filters are limited to the top 5 tags.
- Display access counts in the filter chips.
- Cover image uses Active Storage (`has_one_attached :cover_image`).
- Follow the EA index pattern: render all items, use Pagy only for navigation + `data-filter-index`/`visible_by_default`, and let `filterable_cards` handle filtering across all items.

Constraints:
- Follow `docs/cruip_template_guide.md` and keep Mosaic HTML comment blocks intact.
- Avoid inline `<style>`/`<script>` in views; prefer assets or data attributes.
- Do not edit vendor template assets under `app/assets/templates`.

Steps:
1. Review the mockup sections and list the target HTML blocks to port into `app/views/courses/index.html.erb`.
2. Define a presenter/service (e.g., `Courses::IndexPresenter`) to shape card data, pagination, and filters from `Courses::AccessibleCourses` + enrollments + tags.
3. Add course cover image support (Active Storage or attribute), add model helpers for fallback image URL and alt text.
4. Map each mockup UI element to fields/queries (category label, tags/filters, progress status, unlock CTA) and add missing data or helpers as needed.
5. Update locales (EN/ES) for new labels (search, filters, sort, progress status) and ensure the view uses I18n keys only.
6. Implement the view + partials, reuse shared components (`_filter_chip`, `_badge`, `pagy_mosaic_nav`), and wire JS (reuse `filterable_cards` and add a small sort initializer if needed).
7. Verify output with sample data and ensure empty state/pagination/sort/filter behave as expected.

Commands run:
- `ls` (PASS)
- `sed -n '1,200p' mosaic-html/dashboard_courses_index.html` (PASS)
- `rg --files -g 'app/views/**/*'` (PASS)
- `sed -n '1,200p' app/views/courses/index.html.erb` (PASS)
- `rg -n "class CoursesController|courses#index" app/controllers` (PASS)
- `sed -n '1,200p' app/controllers/courses_controller.rb` (PASS)
- `sed -n '1,200p' docs/cruip_template_guide.md` (PASS)
- `rg -n "course" docs/database_model_reference.md` (PASS)
- `sed -n '1,200p' docs/database_model_reference.md` (PASS)
- `rg -n "<!--" mosaic-html/dashboard_courses_index.html` (PASS)
- `sed -n '1040,1360p' mosaic-html/dashboard_courses_index.html` (PASS)
- `sed -n '1180,1660p' mosaic-html/dashboard_courses_index.html` (PASS)
- `rg -n "data-" mosaic-html/dashboard_courses_index.html` (FAIL)
- `rg -n "published" mosaic-html/dashboard_courses_index.html` (PASS)
- `sed -n '1,200p' app/javascript/filterable_cards.js` (PASS)
- `rg -n "data-filterable|filterable" app/views` (PASS)
- `sed -n '1,200p' app/views/expert_advisors/index.html.erb` (PASS)
- `rg -n "accessible_courses" app` (PASS)
- `sed -n '120,220p' app/controllers/application_controller.rb` (PASS)
- `rg -n "module Courses|class Courses::AccessibleCourses|AccessibleCourses" -g '*.rb' app` (PASS)
- `sed -n '1,200p' app/services/courses/accessible_courses.rb` (PASS)
- `rg -n "class Course|def allowed_for_tier|subscription_tiers|title_for|summary_for" app/models` (PASS)
- `sed -n '1,200p' app/models/course.rb` (PASS)
- `rg -n "dashboard\\.courses" config/locales` (FAIL)
- `ls config/locales` (PASS)
- `rg -n "courses" config/locales/dashboard.en.yml` (PASS)
- `sed -n '520,740p' config/locales/dashboard.en.yml` (PASS)
- `rg -n "course.*image|thumbnail|cover|hero|banner|image" db/schema.rb` (FAIL)
- `sed -n '1060,1240p' mosaic-html/dashboard_courses_index.html` (PASS)
- `rg -n "courses" config/routes.rb` (PASS)
- `sed -n '1,200p' app/javascript/application.js` (PASS)
- `rg -n "Presenter|IndexPresenter" app` (PASS)
- `sed -n '1,200p' app/services/expert_advisors/index_presenter.rb` (PASS)
- `rg -n "pagy_mosaic_nav" -g '*.rb' app` (PASS)
- `sed -n '1,200p' app/helpers/pagination_helper.rb` (PASS)
- `sed -n '1,200p' app/models/course_enrollment.rb` (PASS)
- `sed -n '1,200p' app/services/courses/progress_tracker.rb` (PASS)
- `rg -n "def format_duration" app` (PASS)
- `sed -n '1,120p' app/helpers/application_helper.rb` (PASS)
- `sed -n '1,160p' app/views/dashboard/shared/_badge.html.erb` (PASS)
- `sed -n '1,160p' app/views/dashboard/shared/_filter_chip.html.erb` (PASS)
- `sed -n '1,200p' app/views/dashboard/shared/_secondary_button.html.erb` (PASS)
- `rg --files -g 'product-image.jpg' app/assets templates mosaic-html` (FAIL)
- `sed -n '1,240p' app/views/layouts/dashboard.html.erb` (PASS)
- `sed -n '1,240p' app/views/expert_advisors/_index_card.html.erb` (PASS)
- `rg -n "mosaic/images" app/views` (PASS)
- `rg -n "visible_by_default" -n app/services/expert_advisors/index_presenter.rb` (PASS)
- `sed -n '260,360p' app/services/expert_advisors/index_presenter.rb` (PASS)
- `sed -n '1100,1260p' mosaic-html/dashboard_courses_index.html` (PASS)
- `rg --files -g '*courses_helper.rb' app/helpers` (FAIL)
- `rg -n "courses:" -n config/locales/dashboard.es.yml` (PASS)
- `sed -n '520,700p' config/locales/dashboard.es.yml` (PASS)
- `rg -n "format_duration" app/views` (PASS)
- `rg -n "has_one_attached|has_many_attached" app/models` (PASS)
- `sed -n '520,620p' config/locales/dashboard.en.yml` (PASS)
- `sed -n '520,620p' config/locales/dashboard.es.yml` (PASS)
- `ruby -c app/services/courses/index_presenter.rb` (PASS)
- `ruby -c app/controllers/courses_controller.rb` (PASS)
- `ruby -c app/models/course.rb` (PASS)
- `ruby -c app/services/courses/accessible_courses.rb` (PASS)
- `sed -n '1,240p' app/services/courses/index_presenter.rb` (PASS)
- `sed -n '240,480p' app/services/courses/index_presenter.rb` (PASS)
- `sed -n '1,260p' app/views/courses/index.html.erb` (PASS)
- `sed -n '1,220p' app/views/courses/_index_card.html.erb` (PASS)

Open Questions:
- None.
