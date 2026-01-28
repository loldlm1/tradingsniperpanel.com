# Courses Show Redesign (Mosaic)

## Goal
Clone the `mosaic-html/dashboard_courses_show.html` layout into `courses#show`, preserve section comments, and bind each section to real course/module/lesson/progress data per `docs/database_model_reference.md`, while keeping Cruip/Mosaic conventions intact.

## Definition of Done
- `app/views/courses/show.html.erb` matches the Mosaic mockup structure (page header + Cards grid + Section 1–6) with the same HTML comments for each block.
- All visible copy is I18n-driven (EN/ES) and mapped to real data (course, modules, lessons, progress, access state).
- Progress data is accurate and efficient: overall course progress, per-module progress, and per-lesson duration/status without N+1 queries.
- Access gating is respected (free, unlocked, locked) with clear CTAs and disabled/hidden lesson actions when locked.
- Module cards paginate lessons (3 per page) with a reusable JS snippet; module progress defaults to 0% when no data.
- Module cards themselves paginate (4 per page) so the grid always shows a maximum of 4 modules at once.
- Course status badge is visible to all users.
- No vendor assets edited; only Rails view/presenter/helpers updated per `docs/cruip_template_guide.md`.

## Constraints
- Follow Cruip/Mosaic HTML as the source of truth; keep section HTML comments identical.
- Keep controllers thin; move aggregation to a presenter/service.
- Use existing helpers (`format_duration`) and keep Tailwind classes unchanged unless required.
- Respect UI/UX rules (contrast, focus, 44px touch targets, reduced-motion, no emoji icons) per `ui-ux-pro-max` guidance.

## Decisions (user-provided)
- Paginate lesson lists inside each module card via a reusable JS script (per-module pagination).
- Lesson pagination size: 3 per page.
- Module card pagination size: 4 per page.
- Show module progress as 0% when no progress.
- Show course status badge to all users.
- Access source label: prefer one-time access; fallback to subscription when no one-time enrollment.
- Add a “Resume/Continue learning” CTA based on last watched lesson (when available).

## Steps
1. Add a presenter (e.g., `Courses::ShowPresenter`) that builds a view model:
   - course metadata (title, category, status, locale label)
   - access state (free/unlocked/locked), CTA URLs, badge styles
   - totals (modules, lessons, total duration)
   - enrollment/progress (overall percent, per-module percent, per-lesson status)
   - “next lesson”/“resume” data
2. Update `CoursesController#show` to use the presenter and preload:
   - `course_modules` + `course_lessons`
   - `course_lesson_progresses` for the current user, indexed by lesson id
   - `course_enrollment` for overall progress
3. Replace `app/views/courses/show.html.erb` markup with the Mosaic mockup:
   - Page header (back link, breadcrumbs/category, title, status/access badges)
   - Card 1: Course Summary + Details
   - Card 2: Course Progress by Module
   - Cards 3–6: Module cards with progress, lessons list, lesson CTA
   - Preserve HTML comments from the mockup in each section
4. Add a reusable JS pagination helper for module lesson lists (data-attribute driven; 3 per page; per-module scoped).
5. Add module-card pagination (4 per page) for module cards grid via a reusable JS helper.
6. Add/adjust I18n keys in `config/locales/dashboard.en.yml` and `config/locales/dashboard.es.yml` for new labels and badges.
7. Add lightweight request specs for locked vs. accessible courses (and module progress display) or confirm existing coverage.
8. Perform a visual review (Playwright) of the courses show page and adjust UI polish per design system guidance.
9. Add request specs for the new show view behaviors (pagination markers, access labels, progress display).

## Optional Enhancements (if desired)
- Display per-lesson completion (checkmarks) using `course_lesson_progresses`.
- Add tag chips using `course.tags`.

## Open Questions
- None.

## Notes
- Design system persisted at `design-system/trading-sniper-panel/` (MASTER + `courses-show` overrides).

## Execution Log
- PASS: `python3 /home/loldlm/.agents/skills/ui-ux-pro-max/scripts/search.py "trading education SaaS dashboard course detail Mosaic" --design-system --persist -p "Trading Sniper Panel" --page "courses-show" -f markdown`
- FAIL: `bin/rails runner -` (FK violation on course_enrollments.last_lesson)
- PASS: `bin/rails runner -` (seed visual-course + progress for visual@example.com)
- PASS: `agent-browser open http://localhost:3000/dashboard/courses/visual-course?locale=en`
- PASS: `agent-browser screenshot --full tmp/visual-courses-show.png`
- PASS: `agent-browser screenshot --full tmp/visual-courses-show-modules-page2.png`
- PASS: `agent-browser screenshot --full tmp/visual-courses-show-lessons-page2.png`
- FAIL: `bin/rspec spec/requests/courses_spec.rb` (bin/rspec missing)
- PASS: `bundle exec rspec spec/requests/courses_spec.rb`
