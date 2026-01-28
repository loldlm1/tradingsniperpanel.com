# Courses Show QA Tweaks

## Goal
Address manual QA feedback for `courses#show` by aligning chips/badges with the shared filter chip styling, improving header/tag layout, fixing lesson row spacing, and standardizing pagination cursor affordances while preserving Mosaic section comments and existing data bindings.

## Definition of Done
- The back link matches the “Back to Marketplace” style provided (or is added alongside the existing link per decision) and is I18n-driven.
- Status/access badges and summary chips (level/language/status) use the shared `_filter_chip.html.erb` styling.
- Course tag chips render at the card title level, aligned to the right with reduced empty space.
- Module header lesson count renders as a filter chip with “X lessons” text (number + label together), using proper pluralization.
- Lesson list rows have consistent spacing; long titles truncate/wrap without pushing CTA out of view.
- Pagination buttons (lesson + module nav) show `cursor-pointer` and hover/focus affordance.
- All changes keep Mosaic comments, and no vendor assets are modified.

## Constraints
- Keep `courses#show` structure in line with Mosaic mockup comments.
- Use `_filter_chip.html.erb` for chips/badges (non-interactive where appropriate).
- Use I18n for all new/changed copy (EN/ES).
- Preserve existing data bindings and access gating.

## Steps
1. Map QA items to UI elements in `app/views/courses/show.html.erb` (back link, badges/chips, tags, lesson count, lesson row layout, pagination buttons).
2. Update I18n keys for any new labels (e.g., “Back to Marketplace”, pluralized “lessons”).
3. Replace badge/chip spans with `_filter_chip.html.erb` renders, including non-interactive mode.
4. Add tag chips near the card title row, right-aligned with responsive spacing.
5. Refactor lesson row layout to preserve CTA visibility (flex splits, `min-w-0`, truncation, spacing).
6. Add `cursor-pointer` to pagination buttons (numeric + prev/next) for both module and lesson pagination.
7. Manual QA: verify on `visual-course` with long lesson titles and pagination pages.

## Decisions (user-provided)
- Keep “Back to courses” behavior; only swap to the “Back to Marketplace” link styling.
- Convert top-right status/access badges and module lesson count to `_filter_chip.html.erb` styling.
- No tag filtering in this view; leave tags out for now.
- Lesson count label should read “%{count} lessons” with I18n pluralization.
- Keep lesson title truncation to a single line with improved spacing.
- Apply cursor-pointer and focus rings to all pagination buttons (prev/next + numeric).

## Open Questions
- None.

## Execution Log
- PASS: `agent-browser open http://localhost:3000/users/sign_in`
- PASS: `agent-browser open http://localhost:3000/dashboard/courses/visual-course?locale=en`
- PASS: `agent-browser screenshot --full tmp/visual-courses-show-qa.png`
- PASS: `agent-browser screenshot --full tmp/visual-courses-show-qa-module-page2.png`
- PASS: `agent-browser screenshot --full tmp/visual-courses-show-qa-lesson-page2.png`
- PASS: `bundle exec rspec spec/requests/courses_spec.rb`
