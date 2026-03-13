# Local Examples

## Dashboard Shell

- Source family: `mosaic-html/index.html`, `mosaic-html/settings.html`, and other dashboard-shell pages
- Rails target: `app/views/layouts/dashboard.html.erb`
- Follow this pattern when the task needs the authenticated shell, sidebar, palette handling, or top-level dashboard body classes.
- Preserve sidebar structure, expansion state, and theme hook expectations.

## Marketplace Listing

- Source family: `mosaic-html/dashboard_marketplace_index.html`
- Rails targets:
  - `app/views/marketplace/index.html.erb`
  - `app/views/marketplace/cards/_course_card.html.erb`
  - `app/views/marketplace/cards/_digital_good_card.html.erb`
  - `app/views/marketplace/cards/_category_card.html.erb`
  - `app/views/marketplace/cards/_trending_card.html.erb`
- Use this example for search bars, tab filters, grouped card sections, comment-preserved section boundaries, and Mosaic-style pagination.

## Dashboard Settings

- Source page: `mosaic-html/settings.html`
- Rails target: `app/views/dashboard/settings/show.html.erb`
- Use this example for panel wrappers, `<!-- Panel body -->`, `<!-- Panel footer -->`, signed-in account forms, and page-title/header structure.

## Dashboard Support and FAQ

- Source family: `mosaic-html/faqs.html` and `mosaic-html/feedback.html`
- Rails target: `app/views/dashboards/support.html.erb`
- Use this example for FAQ-style accordions, support cards, split rails, and dashboard-safe help content.

## Mosaic Auth Pages

### Sign in

- Source page: `mosaic-html/signin.html`
- Rails target: `app/views/templates/mosaic/devise/sessions/new.html.erb`
- Preserve the content/image split, header/logo row, heading rhythm, and footer link band.
- Accept product-specific additions such as OAuth buttons if the surrounding structure stays Mosaic.

### Sign up

- Source page: `mosaic-html/signup.html`
- Rails target: `app/views/templates/mosaic/devise/registrations/new.html.erb`
- Preserve the auth shell and form rhythm while adapting to Rails validations, terms acceptance, and localized copy.

### Password reset

- Source pages: `mosaic-html/reset-password.html`
- Rails targets:
  - `app/views/templates/mosaic/devise/passwords/new.html.erb`
  - `app/views/templates/mosaic/devise/passwords/edit.html.erb`
- Use these examples for password-reset entry and reset-confirmation flows.

## Non-Mosaic Boundary Example

- Non-Mosaic landing/auth examples live under `app/views/templates/neon/...`
- Use them only when a task explicitly belongs to the `LANDING_TEMPLATE` landing family rather than authenticated Mosaic work.
