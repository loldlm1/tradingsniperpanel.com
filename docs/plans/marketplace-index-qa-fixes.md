# Plan: Marketplace Index QA Fixes

## Goal
Align the marketplace index with purchasable one-time products only, fix filters/trending behavior, standardize tag UI, and simplify ratings with lightweight, real data.

## Definition of Done
- Marketplace index only shows one-time purchasable items and excludes products already purchased by the user (marketplace purchases, not entitlements).
- Filters/tabs reflect real marketplace product types and match the agreed UX design.
- Trending cards are derived from marketplace purchase/usage data and link to marketplace product detail pages.
- Tag UI uses the agreed `ul/li` pattern (matching the referenced "With Container" → "Start" design) for consistent active styling in light/dark themes.
- CTA arrows use the same arrow style as analytics links.
- Ratings are based on simple, real stats (usage/purchases) with low query cost.
- Tests updated to cover the new filtering/trending behavior.

## Constraints
- Keep controllers thin; presenter/service owns selection logic.
- Use I18n for UI copy.
- Avoid heavy aggregate queries; prefer simple counts with time windows.

## Steps
1. Inspect the marketplace data model and map “one-time marketplace products” + product types to tabs/filters.
2. Update the presenter to scope to one-time purchasable items, exclude purchased products, and update tag derivation.
3. Rework Trending Now to use marketplace-product trends (30-day window) and link to marketplace product detail.
4. Align tag UI and CTA arrow styles with the referenced dashboard patterns.
5. Simplify rating logic to use purchase/usage counts with lightweight queries.
6. Update/extend specs and run targeted + full suite.

## Decisions
- Include any item purchasable via one-time plans; hide it if the user already has a matching `marketplace_purchases` record.
- Tabs should be dynamic and only appear when matching products exist.
- One-time plans without a `marketplace_product` should not appear in the marketplace index.
- Trending uses purchases in the last 30 days, with usage-based fallback when purchases are sparse.
- Use the `→` arrow glyph in CTA labels.
- Trending window: last 30 days, using simpler queries.
- Use the CTA arrow glyph `→` (matching analytics CTAs).
- Tags UI should follow `component-tabs.html` → “With Container” → “Start” `ul/li` pattern and stay responsive.
- Ratings should map simple purchase/usage counts to a 3.0–5.0 range (lightweight aggregates).
- Product types are inferred per marketplace product: add-ons first, bundles when multiple items or types, otherwise single-category (courses/EAs/assets).
- Query terms `addon`/`bundle` act as lightweight type filters (removed from text search).
- Cards are ordered by purchase counts with usage as a tie-breaker, capped to 4 per section.

## Open Questions
- None.

## Commands (discovery)
- `sed -n '1,240p' docs/database_model_reference.md` (PASS)
- `sed -n '1,240p' mosaic-html/component-tabs.html` (PASS)
- `rg -n "With Container|Start" mosaic-html/component-tabs.html` (PASS)
- `sed -n '1160,1215p' mosaic-html/component-tabs.html` (PASS)
- `rg -n "analytics" app/views -g "*.erb"` (PASS)
- `rg -n "→|->|&rarr;" config/locales -g "*.yml"` (PASS)
- `sed -n '1,240p' app/models/marketplace_product.rb` (PASS)
- `sed -n '1,260p' app/services/marketplace/catalog.rb` (PASS)
- `rg -n "Marketplace::Index|Marketplace::Catalog|Trending|marketplace" app -g "*.rb"` (PASS)
- `sed -n '1,240p' app/views/marketplace/index.html.erb` (PASS)
- `ls app/views/marketplace/cards` (PASS)
- `sed -n '1,200p' app/views/marketplace/cards/_course_card.html.erb` (PASS)
- `sed -n '1,200p' app/views/marketplace/cards/_digital_good_card.html.erb` (PASS)
- `sed -n '1,160p' app/views/marketplace/cards/_category_card.html.erb` (PASS)
- `sed -n '1,200p' app/views/marketplace/cards/_trending_card.html.erb` (PASS)
- `sed -n '1,200p' app/views/dashboard/shared/_filter_chip.html.erb` (PASS)
- `sed -n '1,120p' app/views/expert_advisors/index.html.erb` (PASS)
- `rg -n "Filters|Trending|Categories|Market" mosaic-html/dashboard_marketplace_index.html` (PASS)
- `sed -n '1940,2035p' mosaic-html/dashboard_marketplace_index.html` (PASS)
- `rg -n "marketplace" spec -g "*.rb"` (PASS)
- `sed -n '1,240p' spec/services/marketplace/index_presenter_spec.rb` (PASS)
- `sed -n '1,200p' spec/requests/marketplace_filters_spec.rb` (PASS)
- `sed -n '1,120p' spec/requests/marketplace_spec.rb` (PASS)
- `sed -n '118,200p' config/locales/dashboard.en.yml` (PASS)
- `sed -n '118,200p' config/locales/dashboard.es.yml` (PASS)
- `bundle exec rspec` (PASS)
