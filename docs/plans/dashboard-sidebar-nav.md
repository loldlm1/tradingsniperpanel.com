# Dashboard Sidebar Navigation Refresh

## Goal
Update the dashboard sidebar navigation to show the most recent EA/course items (top 5, plus the active item as a 6th if needed), unify numbered badge styling across sections in light/dark mode, and ensure active highlighting works for EA guides and course lessons.

## Definition of Done
- Expert Advisors dropdown shows up to 5 items ordered by `licenses.last_synced_at` (most recent first), and appends the currently viewed EA as item 6 if it is not already included.
- Courses dropdown shows up to 5 items ordered by `course_lesson_progresses.last_watched_at` (most recent first), and appends the currently viewed course as item 6 if it is not already included.
- Marketplace dropdown remains ordered by most purchased items (existing behavior).
- Numbered badges use a single, consistent Mosaic-style circle variant across EA/Courses/Marketplace in both light and dark themes.
- Active highlight works for EA guides (`expert_advisors#guides`) and course lesson pages (`course_lessons#show`).
- `bundle exec rspec` passes.

## Constraints
- Use Mosaic HTML patterns (no edits to vendor template assets in `app/assets/templates`).
- Keep controllers thin; place ordering logic in small service objects under `app/services`.
- Prefer helper methods for view-only composition.

## Steps
1. Choose the Mosaic numbered-circle badge style (recommend: onboarding step indicators from `mosaic-html/onboarding-01.html`) and codify it as a helper/utility class for sidebar badges.
2. Add sidebar ordering services:
   - EAs sorted by `licenses.last_synced_at` (nil timestamps sort last).
   - Courses sorted by `course_lesson_progresses.last_watched_at` (nil timestamps sort last).
3. Update `app/views/layouts/dashboard.html.erb` to use the new sidebar lists, append the active item if missing, and extend active detection to course lesson pages and EA guides.
4. Run `bundle exec rspec`.
5. Update this plan with PASS/FAIL and decisions.

## Open Questions
- None.

## Updates
- Decision: use the Mosaic onboarding step circle style (from `mosaic-html/onboarding-01.html`) with neutral sidebar colors.
- Decision: only show items with recent timestamps; show fewer than 5 when applicable; append active item as a 6th if it is not already included.
- Command: cat > `app/services/dashboard/sidebar_recent_expert_advisors.rb` (PASS)
- Command: cat > `app/services/dashboard/sidebar_recent_courses.rb` (PASS)
- Command: apply_patch `app/controllers/application_controller.rb` (PASS)
- Command: apply_patch `app/helpers/dashboard_navigation_helper.rb` (PASS)
- Command: apply_patch `app/views/layouts/dashboard.html.erb` (PASS)
- Command: `bundle exec rspec` (PASS)
