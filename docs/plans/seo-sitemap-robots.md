# Plan: Sitemap + robots + per-page SEO overrides

## Goal
- Add a sitemap and robots.txt so crawlers can discover marketing/legal pages.
- Add per-page SEO overrides for the main landing and legal pages.
- Add specs to cover the new behavior.

## Definition of Done
- `/robots.txt` references the sitemap and allows crawling of public pages.
- `/sitemap.xml` renders valid XML with the desired URLs (including locale variants as agreed).
- Landing and legal pages set `title`/`description` overrides via `content_for`.
- Specs cover sitemap/robots and per-page SEO overrides; full suite passes.

## Constraints
- Keep changes minimal and aligned with existing I18n copy.
- Avoid indexing authenticated/dashboard pages.
- Use locale-aware URLs when enabled.

## Steps
1. Confirm which URLs should be included in the sitemap (and whether to include locale variants).
2. Implement sitemap + robots delivery (static or controller) and wire routes.
3. Add per-page SEO overrides in landing + legal views using existing translations.
4. Add request/view specs for sitemap/robots and meta overrides.
5. Run full test suite.

## Decisions
- Sitemap includes public pages only: home, terms, privacy, refunds-and-cancellations.
- No auth/dashboard/docs in sitemap.
- Locale handling: default locale uses base path; non-default locales include the prefix.
- Robots served dynamically with sitemap URL and disallow rules for private areas.

## Commands (PASS/FAIL)
- PASS: apply_patch app/controllers/sitemaps_controller.rb
- PASS: apply_patch app/views/sitemaps/show.xml.erb
- PASS: apply_patch config/routes.rb
- PASS: apply_patch public/robots.txt (delete)
- PASS: apply_patch app/views/templates/neon/pages/home.html.erb
- PASS: apply_patch app/views/templates/fintech/pages/home.html.erb
- PASS: apply_patch app/views/legal/terms.html.erb
- PASS: apply_patch app/views/legal/privacy.html.erb
- PASS: apply_patch app/views/legal/refunds_and_cancellations.html.erb
- PASS: apply_patch spec/requests/sitemap_spec.rb
- PASS: apply_patch spec/requests/robots_spec.rb
- PASS: apply_patch spec/requests/seo_meta_spec.rb
- PASS: bundle exec rspec

## Open Questions
- None.
