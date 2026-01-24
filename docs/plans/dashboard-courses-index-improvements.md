# Dashboard Courses Index Improvements

## Goal
- Show only the top 5 tag filters tailored to the current user (based on progress activity).
- Expand course seeds (around 10 courses) to QA pagination and layout with real counts.
- Add lightweight test coverage for the courses index view/BE logic.
- Run the full test suite after implementation (RSpec).

## Definition of Done
- Tag filter chips show only the top 5 tags for the current user, based on count of courses with `progress_percent > 0`.
- Seeds generate ~10 published courses to exercise pagination (8 per page) and allow quick QA.
- Seeded courses exercise marketplace CTA paths (marketplace-only and marketplace+subscription).
- Request/service/model tests cover the index presenter/filtering and access/progress logic (no system/JS specs).
- Full test suite runs successfully via `bundle exec rspec` (or agreed alternative).

## Constraints
- Keep pagination server-side (Pagy) and client-side filtering behavior unchanged.
- Use lightweight specs only (request + service/model). No system/JS specs.
- Follow existing Cruip/Mosaic layout patterns; do not alter the UI structure.
- Prefer minimal schema changes unless necessary.

## Steps
1) Implement tag aggregation based on count of courses with `progress_percent > 0`, then limit to top 5 tags.
2) Add marketplace CTA resolution for locked courses, preferring marketplace products when available, falling back to subscription plans.
3) Update dev/staging seeds to create ~10 courses with tags and mixed access states (free/unlocked/locked + marketplace CTA).
4) Add tests covering the index presenter filtering logic, marketplace CTA selection, and request response shape/content.
5) Run `bundle exec rspec` and record PASS/FAIL in this plan.

## Decisions
- Tag chip counts use the same metric as selection: count of courses with `progress_percent > 0`; if none, fall back to total course counts.
- Unlock CTA prefers marketplace product links when available; fallback to subscription plans.
- Seeds: 10 total courses; 4 tied to marketplace products (3 marketplace+subscription, 1 marketplace-only), remaining 6 subscription-only.

## Open Questions
- None.

## Commands
- `bundle exec rspec` (FAIL)
- `bundle exec rspec` (PASS)
