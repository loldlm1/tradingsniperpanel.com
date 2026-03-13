# Mosaic Catalog

## Boundary

- Use this skill for authenticated Mosaic surfaces in this repo.
- Keep dashboard, settings, plans, billing, support, FAQ, and Mosaic auth/account work on the Mosaic family.
- Keep landing and marketing work on the template selected by `LANDING_TEMPLATE`.
- Treat `app/views/templates/neon/...` and `app/views/templates/fintech/...` as non-Mosaic territory unless a task explicitly asks about the boundary between landing and dashboard surfaces.

## Source Selection Order

1. Use the exact page match in `mosaic-html/` when it exists.
2. Use the closest full page with the same shell and section rhythm.
3. Use `component-*.html` only for isolated gaps that no page-level source covers well.
4. Use an existing Rails example in this repo to confirm the adaptation pattern after choosing the source.

## Page Families

### Dashboard shell and navigation

- Start from `index.html`, `analytics.html`, `billing.html`, `plans.html`, `settings.html`, or other dashboard pages with the same sidebar/topbar shell.
- Use repo-specific source captures such as `dashboard_marketplace_index.html` and `dashboard_courses_show.html` when they match more closely than generic vendor pages.
- Preserve the page wrapper, sidebar comment map, expansion state, dark-mode classes, and dropdown/sidebar Alpine hooks.

### Search, filters, cards, lists, and tables

- Prefer `dashboard_marketplace_index.html`, `shop.html`, `users-tiles.html`, `users-tabs.html`, `orders.html`, `tasks-list.html`, or `notifications.html`.
- Reach for `component-pagination.html`, `component-tabs.html`, `component-dropdown.html`, `component-badge.html`, and `component-form.html` only when the page-level source is missing an isolated piece.
- Preserve search bars, tab/filter wrappers, grid spacing, pagination nav structure, badge states, and action menus.

### Settings, plans, billing, support, FAQ, feedback

- Prefer `settings.html`, `billing.html`, `plans.html`, `faqs.html`, and `feedback.html`.
- Preserve panel wrappers, section headings, footer actions, split content/sidebar rails, and `details`/`summary` FAQ structures where used.

### Auth and account entry points

- Prefer `signin.html`, `signup.html`, and `reset-password.html`.
- Preserve the `Content` / `Image` split, full-bleed auth layout, logo/header row, auth image placement, and footer link band.
- Use dashboard settings/account patterns for signed-in account management rather than forcing auth pages to do double duty.

### Commerce and marketplace

- Prefer `dashboard_marketplace_index.html`, `shop.html`, `product.html`, `cart.html`, and `invoices.html`.
- Preserve product-card proportions, section headings, pagination, tab bars, and action areas.

### Social and support-style content

- Prefer `faqs.html`, `feedback.html`, `messages.html`, `notifications.html`, `feed.html`, `forum.html`, and `forum-post.html` for support, FAQ, or community-like layouts.

## Hook Inventory

### Alpine and shell behavior

- Preserve `x-data`, `x-show`, `x-cloak`, `@click`, `@click.outside`, and `@keydown.escape.window`.
- Preserve sidebar state that depends on `localStorage` key `sidebar-expanded`.
- Preserve dark-mode expectations tied to `localStorage` key `dark-mode`.

### JS-bound selectors and ids

- Preserve `.light-switch` for theme toggles handled by `app/assets/templates/mosaic/js/main.js`.
- Preserve `.datepicker` and optional `data-class` for `app/assets/templates/mosaic/js/flatpickr-init.js`.
- Preserve chart ids and companion nodes expected by `app/assets/templates/mosaic/js/dashboard-charts.js`, `analytics-charts.js`, and `fintech-charts.js`.
- Add Rails `data-*` attributes only as complements to existing hooks, not as silent replacements for required ids or classes.

## Asset Mapping

- Map `./images/...` to `image_tag "mosaic/images/..."`
- Map vendor CSS and JS to the Rails-loaded Mosaic bundles instead of adding duplicate direct includes
- Keep auth pages on the shared `mosaic/images/auth-image.jpg` unless the task explicitly changes the art direction
- Keep vendor fonts and base utility styles under `app/assets/templates/mosaic/`
