# Rails Porting

## Workflow

1. Pick the closest source page in `mosaic-html/`.
2. Copy the smallest full comment-bounded section that solves the task.
3. Port the structure into ERB with the fewest structural changes possible.
4. Extract repeated units to partials without hiding the top-level section map.
5. Replace static copy and paths with Rails helpers and locale keys.
6. Verify hook compatibility, layout parity, native checks, and the Browser QA Gate.

## Layout Placement

### Dashboard pages

- Keep shell concerns in `app/views/layouts/dashboard.html.erb`.
- Port inner page sections into the route-specific view under `app/views/...`.
- Keep source section comments in the page body when the Rails view owns those sections.

### Mosaic auth pages

- Place Mosaic auth views under `app/views/templates/mosaic/devise/...`.
- Keep `content_for :full_bleed, true` for full-width auth layouts.
- Preserve the source split between content column and auth image column.

### Shared fragments

- Extract repeated rows, cards, and chips into partials under the nearest view folder or `app/views/dashboard/shared/` when shared across dashboard pages.
- Keep single-instance wrappers inline so reviewers can still map the Rails page to the source HTML quickly.

## ERB Transformation Rules

### Copy and I18n

- Replace static headings, labels, CTA copy, helper text, and empty-state text with locale keys.
- Add new durable copy to both `config/locales/en.yml` and `config/locales/es.yml`.
- Avoid string concatenation. Use interpolation inside locale files when needed.
- Match existing local conventions around `t(..., default: ...)` only for small bridge cases; prefer stable keys for any new or lasting UI copy.

### Links, forms, buttons, and images

- Replace static anchors with `link_to` or `button_to`.
- Replace raw forms with `form_with` and the existing Rails model or URL helpers.
- Replace image paths with `image_tag "mosaic/images/..."`
- Preserve wrapper structure, field order, and button placement from the source unless product behavior requires a change.

### Partials

- Extract repeated cards, rows, and tiles to `_partial.html.erb` files with locals.
- Keep comment labels around repeated groups in the parent template.
- Avoid partializing a one-off section only to reduce line count; parity and reviewability matter more than aggressive decomposition.

## CSS and JS Rules

- Never edit `app/assets/templates/mosaic/**/*`.
- Put page or theme adjustments in `app/assets/stylesheets/dashboard.css` or another Rails-owned stylesheet.
- Use Rails-owned Tailwind layers only for app-level utility additions or overrides.
- Avoid inline `<style>` and `<script>` in views.
- Preserve ids, classes, `x-*` attributes, `data-*` attributes, and supporting DOM nodes expected by Alpine, Flatpickr, or Chart.js initializers.
- Keep class order from the source unless a helper-generated class merge makes that impractical.

## Parity Rules

- Favor closest-practical 1:1 parity before introducing custom layout changes.
- Accept small deviations only for:
  - Rails helper syntax
  - I18n extraction
  - accessibility fixes
  - live data or conditional rendering
  - reusable partial extraction
- If a closer source section exists, use it instead of improvising new dashboard UI.

## Browser QA Gate

- Run `npm run build:css` when Tailwind extraction or generated CSS can change.
- Run the narrowest relevant Rails/request/system or project-native check first.
- Compare the Rails result against the chosen `mosaic-html/` source at desktop width.
- Check mobile and tablet collapse behavior, light/dark themes, keyboard focus, and EN/ES copy length.
- Check validation, empty, loading, error, success, and long-content states when touched by the task.
- Check Alpine, chart, date-picker, dropdown, console, and network behavior when the section depends on them.
- Use `token-efficient-web-qa` for deterministic browser automation when available. Start with one focused browser and capture screenshots or traces on failure or when visual evidence is required.
- Report `Browser QA: PASS`, `FAIL`, `Not applicable`, or `Not run` with the exact limitation.
