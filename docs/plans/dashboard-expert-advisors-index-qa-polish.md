# Dashboard Expert Advisors Index QA Polish

## Goal
- Improve license readability + copy UX on EA cards.
- Replace guide preview markdown with a clean, static guide message.
- Use `_filter_chip` styling for card tags.
- Replace locked “View Guide” label with an unlock-focused CTA.

## Definition of Done
- License block renders the full key inside a field-like container with truncation at the end, no overflow, and the copy button state is visible when toggled.
- Guide copy uses an I18n message instead of raw markdown/video embed content.
- Card tags render with `app/views/dashboard/shared/_filter_chip.html.erb` and look good in light/dark themes.
- Locked CTA copy communicates “unlock” intent while keeping the same destination URLs.
- Request specs cover the new license display and locked CTA label changes (no system specs).

## Constraints
- Keep Mosaic HTML structure/comments and Tailwind classes.
- No inline scripts/styles; keep JS in `app/javascript`.
- Use I18n for any new copy (EN/ES).
- Keep logic in presenter/helpers, not the controller.

## Steps
1. Implement the license field layout (truncate the text inside the field, keep the copy button visible) and keep the copy value intact.
2. Update the license layout to avoid truncation and reserve space for the copy button label state.
3. Replace guide copy rendering to use a static I18n message (and avoid markdown preview injection).
4. Render card tags with `_filter_chip` as display-only chips and tune sizing classes.
5. Add a single locked CTA label + I18n keys and swap the view to use it.
6. Update request specs to assert license display formatting and locked CTA label changes.
7. Run request specs + full suite; log PASS/FAIL.

## Open Questions
- (none)

## Progress Log
- Decision: guide copy always uses `dashboard.expert_advisors.index.guide_copy`.
- Decision: card tags render via `_filter_chip` as non-interactive chips.
- Decision: locked guide CTA uses `dashboard.expert_advisors.unlock_cta`.
- Decision: license text sits inside a truncated field with a fixed-width copy button and a 3s reset.
- Decision: request spec asserts the static guide copy on the index page.
- Command: bundle exec rspec (FAIL)
- Command: bundle exec rspec (PASS)
