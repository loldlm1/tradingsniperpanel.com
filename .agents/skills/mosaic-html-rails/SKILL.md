---
name: mosaic-html-rails
description: Use for authenticated frontend work in this Rails repo that should match the local Cruip Mosaic HTML template with closest practical parity. Trigger on building, refactoring, or reviewing dashboard, settings, billing, plans, support, FAQ, and Mosaic-based auth/account pages; porting `mosaic-html/*.html` into Rails ERB/partials; preserving section comments, Tailwind utility stacks, Alpine/Chart.js/Flatpickr hooks, DOM ids, and asset rewrites to the local Mosaic asset pipeline. Do not use for landing or marketing pages controlled by `LANDING_TEMPLATE` unless the task explicitly concerns the boundary between Mosaic and Neon/Fintech.
---

# Mosaic HTML Rails

Use this skill to keep authenticated UI work anchored to the local `mosaic-html/` source instead of drifting into custom dashboard design. Favor closest-practical 1:1 parity with the source template, then adapt only what Rails, I18n, accessibility, or product behavior requires.

## Quick Start

1. Confirm the surface belongs to Mosaic, not a `LANDING_TEMPLATE` marketing page.
2. Find the closest source page or comment-bounded section in `mosaic-html/`.
3. Lift the smallest complete section that solves the task.
4. Preserve section comments, utility classes, DOM hooks, and layout rhythm.
5. Adapt the section to ERB, partials, I18n keys, Rails asset paths, and existing helpers.
6. Run the project Browser QA Gate at the smallest useful depth.

## Boundary

- Treat authenticated dashboard, settings, plans, billing, support, FAQ, and Mosaic auth/account pages as in-scope.
- Treat landing and marketing pages as out of scope. Those surfaces come from `LANDING_TEMPLATE` and map to Neon or Fintech templates under `app/views/templates/<template>/...`.
- If a task spans both families, keep dashboard/account/auth work on Mosaic and keep landing work on the configured template family.

## Workflow

### 1. Pick the source before editing

- Open `references/mosaic-catalog.md`.
- Prefer an exact page match such as `settings.html`, `signin.html`, `signup.html`, `reset-password.html`, `billing.html`, `plans.html`, or `faqs.html`.
- If no exact match exists, prefer the closest full page with the same shell and section rhythm before falling back to `component-*.html`.
- Start from local HTML, not screenshots and not the already-adapted Rails page.

### 2. Preserve parity first

- Copy the full comment-bounded block whenever possible.
- Keep source comments such as `<!-- Page header -->`, `<!-- Search form -->`, `<!-- Filters -->`, `<!-- Panel body -->`, `<!-- Panel footer -->`, and `<!-- Cards -->`.
- Keep the original Tailwind utility stack and class ordering unless a Rails helper forces a small adjustment.
- Keep ids, `x-data`, `x-show`, `x-cloak`, `@click`, `@click.outside`, `@keydown.escape.window`, `data-*`, chart legend containers, and canvas ids intact.
- Do not redesign a section if a closer Mosaic source already exists.

### 3. Adapt the section to Rails

- Open `references/rails-porting.md`.
- Convert static copy to locale keys.
- Replace static anchors, forms, buttons, and images with Rails helpers.
- Extract repeated cards, rows, and tiles to partials. Keep top-level section wrappers in the parent view so the source structure stays readable.
- Keep dashboard shell concerns in `app/views/layouts/dashboard.html.erb`.
- Put Mosaic auth pages under `app/views/templates/mosaic/devise/...`.

### 4. Reuse repo-local examples

- Open `references/local-examples.md`.
- Follow existing marketplace, settings, support, and auth pages as the baseline for acceptable adaptation in this repo.
- Match the repo’s established comment style when the current Rails view already preserves the source section map.

### 5. Keep vendor assets stable

- Never edit `app/assets/templates/mosaic/**/*`.
- Put custom CSS in `app/assets/stylesheets/dashboard.css` or another Rails-owned stylesheet.
- Add global Tailwind-only adjustments in Rails-owned layers, not vendor files.
- Keep Mosaic asset paths in the `mosaic/...` namespace.
- Keep JS hook compatibility with the local Mosaic JS bundles and any Rails initializers that consume the same DOM nodes.

### 6. Verify

- Run `npm run build:css` when changed templates or CSS affect Tailwind class extraction or generated styles.
- Start with the narrowest project-native checks, then run deterministic browser QA for every browser-visible change.
- Use `token-efficient-web-qa` when available: prefer an existing project runner, then one focused Playwright browser before broader coverage.
- Check source parity, mobile/tablet/desktop layout, light/dark themes, keyboard/focus behavior, and EN/ES copy length.
- Check empty, loading, validation, error, success, and long-content states when the feature touches them.
- Inspect console and network failures for the changed flow. Use interactive screenshots, traces, or browser debugging only as targeted evidence or when the task requests a visual audit.
- Report `Browser QA: PASS`, `FAIL`, `Not applicable`, or `Not run` with the exact limitation.

## Non-Negotiables

- Do not remove source section comments.
- Do not rename JS hook ids or classes without updating every dependent initializer.
- Do not replace a close Mosaic section with unrelated custom UI.
- Do not leave inline copy in new durable UI when the surface is already localized.
- Do not edit vendor template CSS or JS to make a single page easier to port.
- Do not partialize one-off structural wrappers so aggressively that the source hierarchy becomes harder to review.
- Do not skip the Browser QA Gate for browser-visible changes.

## References

- `references/mosaic-catalog.md`: source-page selection, page families, hook inventory, `LANDING_TEMPLATE` boundary
- `references/rails-porting.md`: HTML-to-ERB workflow, partialization, I18n, assets, JS preservation, Browser QA Gate
- `references/local-examples.md`: repo-local examples that map Mosaic source pages to current Rails views
