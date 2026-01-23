# Plan: Marketplace Show QA UI Tweaks

## Goal
Improve marketplace show tags and divider visibility across themes, reuse filter chip styling for tags (non-clickable), and adjust mobile ordering so checkout appears before related items.

## Definition of Done
- Tag styling on marketplace show matches filter chip appearance and is non-clickable.
- Divider (`hr`) lines are visible on light theme while preserving dark theme styling.
- On mobile/responsive, the checkout sidebar renders before the related items section; desktop layout remains intact.
- Changes are minimal, readable, and keep Mosaic section comments.

## Constraints
- Follow `docs/cruip_template_guide.md`; keep Mosaic classes, JS hooks, and HTML comment blocks intact.
- Avoid over-complex structure changes; prefer small layout tweaks.
- Reuse `app/views/dashboard/shared/_filter_chip.html.erb` for tag styling.

## Steps
1. Update `_filter_chip.html.erb` to support a non-clickable variant without affecting existing callers.
2. Swap marketplace show tags to render via the filter chip partial in non-clickable mode.
3. Adjust `hr` classes in `app/views/marketplace/show.html.erb` for light-theme visibility.
4. Update the marketplace show layout to order sidebar before related items on mobile, preserving desktop layout.
5. Quick visual scan (light/dark) and note any follow-up.

## Open Questions
None.

## Decisions
- Sidebar renders immediately after main product content on small screens, with related items below.
- Add a non-clickable variant to `app/views/dashboard/shared/_filter_chip.html.erb` via `interactive: false`.
- Use a left arrow symbol for the marketplace back link in EN/ES.

## Commands
- PASS: ls
- PASS: sed -n '1,200p' docs/plans/marketplace-show-qa-ui.md
- PASS: rg -n "filter_chip" app/views
- PASS: rg -n "<hr" app/views/marketplace/show.html.erb
- PASS: sed -n '1,200p' app/views/dashboard/shared/_filter_chip.html.erb
- PASS: sed -n '1,260p' app/views/marketplace/show.html.erb
- PASS: sed -n '190,230p' config/locales/dashboard.en.yml
- PASS: sed -n '200,240p' config/locales/dashboard.es.yml
