# Dashboard Expert Advisors Index QA Polish

## Goal
- Improve license readability + copy UX on EA cards.
- Replace guide preview markdown with a clean, static guide message.
- Use `_filter_chip` styling for card tags.
- Replace locked “View Guide” label with an unlock-focused CTA.
- Improve header status chip and license field styling for dark theme readability.
- Fix header status chip wrapping and improve locked-status contrast in dark theme.

## Definition of Done
- License block renders the full key inside a field-like container with truncation at the end, no overflow, and the copy button state is visible when toggled.
- Guide copy uses an I18n message instead of raw markdown/video embed content.
- Card tags render with `app/views/dashboard/shared/_filter_chip.html.erb` and look good in light/dark themes.
- Locked CTA copy communicates “unlock” intent while keeping the same destination URLs.
- Header status badge uses the filter chip styling and reads clearly in dark theme.
- License field contrast is improved in dark theme so the “Locked” value is visible.
- Status badge stays on one line in the header and locked/expired/revoked text is readable in dark mode.
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
7. Update the header status badge to use the filter chip styling and refine license field colors for dark theme contrast.
8. Keep the status badge on one line (no wrap) and adjust locked/expired/revoked contrast for dark mode.
9. Run request specs + full suite; log PASS/FAIL.

## Open Questions
- (none)

## Progress Log
- Decision: guide copy always uses `dashboard.expert_advisors.index.guide_copy`.
- Decision: card tags render via `_filter_chip` as non-interactive chips.
- Decision: locked guide CTA uses `dashboard.expert_advisors.unlock_cta`.
- Decision: license text sits inside a truncated field with a fixed-width copy button and a 3s reset.
- Decision: header status badge uses `_filter_chip` with status colors and smaller sizing.
- Decision: license field uses a darker background/border in dark theme for contrast.
- Decision: request spec asserts the static guide copy on the index page.
- Command: bundle exec rspec (FAIL)
- Command: bundle exec rspec (PASS)
- Command: bundle exec rspec (FAIL)
- Command: bundle exec rspec (PASS)
- Decision: status badge uses `whitespace-nowrap` + `leading-4` and the header column is `shrink-0` to avoid wrapping.
- Decision: default status badge text uses `dark:text-gray-100` for contrast.
