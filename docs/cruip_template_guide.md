# Cruip Template Guide (Neon + Mosaic)
How to reuse Cruip HTML templates (not our Rails views) to assemble new pages quickly. Always start from the source HTML in `neon-html/` and `mosaic-html/`, then adapt into `.erb` while keeping class names, JS hooks, and assets intact.

## Asset layout & adaptation
- Source: `neon-html/` and `mosaic-html/` at repo root contain the canonical HTML, CSS, JS, and assets.
- Rails copies: `app/assets/templates/neon` and `app/assets/templates/mosaic` hold the imported CSS/JS/images/fonts. Do not edit vendor files; add overrides via Tailwind (`app/assets/tailwind/application.css`) or per-view classes.
- Importing flow: copy the HTML snippet you need, wrap in ERB as required, and keep:
  - Classes/utilities as-is (Tailwind utility stack from Cruip).
  - Data/JS hooks (`data-aos`, Alpine `x-*`, IDs used by Chart.js or Flatpickr).
  - Asset paths (update to `/assets/neon/...` or `/assets/mosaic/...` equivalents when moving to Rails).

## Neon HTML catalogue (marketing/auth)
- Pages: `index.html` (full landing), `signup.html`, `signin.html`, `reset-password.html`.
- Key sections/blocks in `index.html`:
  - Header/nav + gradient CTA buttons.
  - Hero with badge, dual CTAs, background illustration.
  - Logo strip.
  - Feature grid (three icon tiles) and a split feature + bullets.
  - Pricing cards (three tiers) with Alpine toggle for monthly/annual pricing; CTA buttons.
  - Testimonials grid (cards with avatar/title/quote).
  - Resources tabbed cards (Alpine `x-data="{ category: '1' }"` controlling visibility).
  - CTA band with gradient background.
  - Footer links.
- Auth pages: form cards for sign-in/up/reset with social buttons, password fields, and subtle background art.
- Assets: `neon-html/images` (illustrations, avatars, patterns), `fonts`, `css/style.css`.
- JS:
  - `js/vendors/alpinejs.min.js` for lightweight interactivity (tabs, toggles).
  - `js/vendors/aos.js` + `js/main.js` for scroll animations (AOS init: `once`, `disable: 'phone'`, `duration: 500`, `easing: 'ease-out-cubic'`).
  - Hooks to respect: `data-aos` attributes on sections, Alpine toggles on tabs/pricing buttons.

## Mosaic HTML catalogue (dashboard UI kit)
- Pages (grouped):
  - Core dashboards: `index.html` (main), `analytics.html`, `fintech.html`, `pay.html`, `billing.html`, `plans.html`.
  - Commerce/finance: `orders.html`, `transactions.html`, `transaction-details.html`, `credit-cards.html`, `cart.html`, `cart-2.html`, `cart-3.html`, `shop.html`, `shop-2.html`, `product.html`, `invoices.html`.
  - People/content: `users-tabs.html`, `users-tiles.html`, `customers.html`, `company-profile.html`, `profile.html`, `feed.html`, `forum.html`, `forum-post.html`, `meetups.html`, `meetups-post.html`, `notifications.html`, `messages.html`, `inbox.html`.
  - Projects/tasks: `tasks-list.html`, `tasks-kanban.html`, `roadmap.html`, `calendar.html`, `campaigns.html`, `job-listing.html`, `job-post.html`, `onboarding-01..04.html`, `empty-state.html`.
  - Auth/account: `signin.html`, `signup.html`, `reset-password.html`, `settings.html`, `connected-apps.html`, `faqs.html`, `feedback.html`, `404.html`.
  - Component library: `component-accordion.html`, `component-alert.html`, `component-avatar.html`, `component-badge.html`, `component-breadcrumb.html`, `component-button.html`, `component-dropdown.html`, `component-form.html`, `component-icons.html`, `component-modal.html`, `component-pagination.html`, `component-tabs.html`, `component-tooltip.html`.
- Reusable blocks you can lift:
  - Shell: sidebar + topbar layout (light/dark), page header with breadcrumbs/actions.
  - Cards: stat tiles, charts, timelines, feeds, comment threads, activity lists.
  - Tables: striped, compact, paginated tables with badges/avatars and action menus.
  - Forms: settings-style forms, payment/billing forms, filters/search bars, file inputs.
  - Navigation: tabs (solid/underline), breadcrumbs, dropdown menus, pills.
  - Overlays: modals, slide-overs, tooltips, accordions.
  - Commerce widgets: product cards, carts/checkout steps, pricing tables, receipts.
  - Project/task widgets: kanban columns, checklists, calendars, timelines.
  - Social/community: posts, comments, message threads, notifications list.
- Assets: `mosaic-html/images` (avatars, charts, placeholders), `css/style.css`, `fonts` bundled in CSS.
- JS (keep IDs/classes when reusing):
  - Vendors: `alpinejs.min.js` (sidebar, dropdowns, modals), `chart.js` + `chartjs-adapter-moment.js`, `moment.js`, `flatpickr.js`.
  - `js/main.js`: light/dark toggle via `.light-switch` inputs; syncs to `localStorage` (`dark-mode`) and emits `darkMode` custom events.
  - `js/flatpickr-init.js`: attaches range picker to `.datepicker` inputs, sets default last-7-days, custom arrows, and optional class via `data-class`.
  - Chart initializers:
    - `js/dashboard-charts.js`: multiple Chart.js demos bound to IDs `dashboard-card-01`..`dashboard-card-09`, some with legends containers (`dashboard-card-04-legend`, `dashboard-card-06-legend`, `dashboard-card-08-legend`), value/deviation spans for card 05, and dark-mode event handling.
    - `js/analytics-charts.js` and `js/fintech-charts.js`: additional chart setups for their respective pages (line/bar/donut mixes; moment adapter required).
  - Keep canvas IDs and supporting DOM nodes intact when porting chart blocks; dark mode relies on the `darkMode` custom event from `main.js`.

## Using the catalogue to mock screens
- Pick a source page whose layout matches your need (e.g., `plans.html` for pricing, `tasks-kanban.html` for boards, `component-*` for isolated UI bits).
- Copy the section HTML verbatim, then wrap in ERB as needed; keep Tailwind classes, `x-data`/`x-show` Alpine bindings, `data-aos`, and element IDs for JS.
- Update assets to the Rails-served paths and swap copy/images, but avoid renaming structural classes or JS hooks.
- For charts/date pickers, include the matching JS bundle (dashboard/analytics/fintech charts and flatpickr) and ensure the expected IDs/classes exist.
- Leave vendor CSS/JS untouched; apply custom tweaks via additional utility classes or small override files rather than editing `style.css`.
