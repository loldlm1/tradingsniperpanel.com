# Courses Show Final Tweaks

## Goal
Finalize the remaining visual QA fixes for `courses#show`: make the “Progress by module” card full-width on smaller screens and add breathing room between lesson status dot, title, CTA, and duration.

## Definition of Done
- “Progress by module” card spans full width on mobile/small breakpoints (no narrow column layout).
- Lesson rows show clear spacing: status dot → title, CTA → duration, without breaking truncation or pushing CTA off-card.
- Layout remains aligned with Mosaic section comments and existing data bindings.
- No vendor assets edited; changes limited to view markup/classes and any needed minor CSS classes.

## Constraints
- Preserve Mosaic mockup HTML comments and structure.
- Use existing Tailwind utility classes; avoid custom CSS unless necessary.
- Keep lesson titles truncated to one line, and maintain CTA visibility.

## Steps
1. Adjust the “Progress by module” card column classes to be full-width on small screens (e.g., `col-span-full` at base).
2. Update lesson row flex layout classes to add gap between dot/title and CTA/duration, while keeping truncation and fixed CTA placement.
3. Visual QA on `visual-course` in mobile/desktop widths to confirm full-width card and spacing.

## Open Questions
- None.

## Decisions (user-provided)
- Make the progress card full-width at widths below 1280 (keep the side-by-side layout at `xl` and up).
- Add spacing between status dot and lesson title, and between “View lesson” and duration.

## Execution Log
- PASS: `bundle exec rspec`
- PASS: `agent-browser open http://localhost:3000/users/sign_in`
- PASS: `agent-browser open http://localhost:3000/dashboard/courses/visual-course?locale=en`
- PASS: `agent-browser screenshot --full tmp/visual-courses-show-final-1200.png`
- PASS: `agent-browser screenshot --full tmp/visual-courses-show-final-1400.png`
