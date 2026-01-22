# Plan: Marketplace Index Redesign

## Goal
Replace `marketplace#index` with the Mosaic marketplace redesign, keeping HTML comment section markers from `mosaic-html/dashboard_marketplace_index.html` and wiring each card to real data per `dashboard_marketplace_index_cards_en.md`.

## Definition of Done
- `app/views/marketplace/index.html.erb` mirrors the Mosaic layout and section comments for Page header, Search form, Filters, and Cards 1/2/5/6 (Cards 3 comments retained but section hidden with no data).
- Each card section pulls data from a dedicated service/presenter with efficient queries and clear fallbacks when data is missing.
- Search and filters work end-to-end (query + product type tabs + tag chips) without overloading the Filters area.
- All copy uses I18n keys with EN/ES coverage; no inline strings; links respect locale.
- Repeated UI blocks are extracted to partials/components; controller remains thin.
- Tests cover the data selection service and the marketplace index response for basic render/sections.

## Constraints
- Follow `docs/cruip_template_guide.md` (preserve classes, data hooks, and HTML comment blocks).
- Do not edit vendor template assets; add overrides via Tailwind or view classes only.
- Use PORO/service objects under `app/services` for business logic.
- Keep UI strings in `config/locales` (EN/ES).

## Steps
1. Map each HTML section in `mosaic-html/dashboard_marketplace_index.html` to the card definitions in `dashboard_marketplace_index_cards_en.md`; confirm any missing data requirements or fallback rules (skip Online Events data selection).
2. Design a new presenter/service (e.g., `Marketplace::IndexPresenter`) plus a lightweight search scope (ILIKE-based) that returns structured data for each section (courses, EAs, categories, trending) with preloaded associations and aggregate queries.
3. Update `MarketplaceController#index` to use the presenter/service and expose data to the view (search + product type tab + tag params).
4. Rebuild `app/views/marketplace/index.html.erb` from the Mosaic markup, keeping comment blocks; extract repeated card layouts into partials (course, EA, category, trending) and a filter row that supports tabs + tag chips with overflow control.
5. Add/extend I18n keys for headings, CTAs, placeholders, labels, and empty states in `config/locales/*`.
6. Add tests (service spec for selection logic; request spec for index rendering with seeded data).

## Open Questions
- None.

## Decisions
- Search scope: MarketplaceProduct title/summary/description, BillingPlan name/key, ExpertAdvisor name, Course localized title, MarketplaceAsset localized title, and Addon key.
- Filters: tabs + tag chips, top 8 tags max, no “More filters” disclosure; selected tags always visible.
- Tabs: hide unrelated sections when a product type tab is active; tags/query filter within visible sections.
- Metric windows: best selling = 30 days, most recent sales = 14 days, trending = 7 days; otherwise use publish dates or all-time.
- Best conversion = most bought add-on or EA.
- Best retention = most used EA (active licenses with broker activity in last 30 days) and add-ons by most purchased in last 30 days.
- Hide sections when no data is available.
- If no attachment exists, use a general Mosaic placeholder image.
- Online Events: skip data selection and hide the Cards 3 section entirely.
- Popular Categories links use marketplace `tab` + `q` filters; search includes `courses.category` and `expert_advisors.ea_type` to support the category links.
- Add-ons and bundles category uses combined search terms ("addon bundle") so the marketplace filter covers both.

## Commands (discovery)
- `sed -n '1,200p' docs/cruip_template_guide.md` (PASS)
- `sed -n '1,200p' mosaic-html/dashboard_marketplace_index.html` (PASS)
- `sed -n '1,200p' dashboard_marketplace_index_cards_en.md` (PASS)
- `sed -n '1,200p' docs/database_model_reference.md` (PASS)
- `sed -n '1,200p' app/views/marketplace/index.html.erb` (PASS)
- `rg -n "ILIKE|search" app/services app/controllers app/models` (PASS)
- `ls | rg "dashboard_shop_index"` (FAIL)
- `rg --files -g "*shop_index_cards*"` (FAIL)
- `cat docs/plans/marketplace-index-redesign.md` (PASS)
- `sed -n '1,240p' docs/plans/marketplace-index-redesign.md` (PASS)
- `sed -n '1,120p' docs/plans/marketplace-index-redesign.md` (PASS)
- `rg -n "Category|category" docs/database_model_reference.md` (PASS)
- `rg -n "acts_as_taggable" app/models` (PASS)
- `rg -n "Cards 5|Categories|Category" mosaic-html/dashboard_marketplace_index.html` (PASS)
- `sed -n '1870,1965p' mosaic-html/dashboard_marketplace_index.html` (PASS)
- `rg -n "Popular Categories" -n dashboard_marketplace_index_cards_en.md` (PASS)
- `sed -n '232,320p' dashboard_marketplace_index_cards_en.md` (PASS)
- `sed -n '1,200p' app/models/expert_advisor.rb` (PASS)
- `rg -n "event" app/models app/views app/controllers db/schema.rb` (PASS)
- `sed -n '480,620p' db/schema.rb` (PASS)
- `sed -n '1,200p' app/models/marketplace_asset.rb` (PASS)
- `ls db/seeds` (PASS)
- `rg -n "marketplace" db/seeds` (PASS)
- `sed -n '900,1140p' db/seeds/shared.rb` (PASS)
- `sed -n '1140,1360p' db/seeds/shared.rb` (PASS)
- `rg -n "tag_list|tags" db/seeds/shared.rb` (PASS)
- `sed -n '1,120p' db/seeds/shared.rb` (PASS)
- `sed -n '1,200p' app/views/dashboard/shared/_filter_chip.html.erb` (PASS)
- `sed -n '1,200p' app/views/marketplace/_product_card.html.erb` (PASS)
- `sed -n '1,200p' app/models/billing_plan.rb` (PASS)
- `rg -n "create_table \"billing_plans\"|billing_plans" -n db/schema.rb` (PASS)
- `sed -n '90,130p' db/schema.rb` (PASS)
- `sed -n '1,200p' app/models/marketplace_product.rb` (PASS)
- `sed -n '1,240p' app/services/marketplace/catalog.rb` (PASS)
- `sed -n '1,200p' app/controllers/marketplace_controller.rb` (PASS)
- `sed -n '1,220p' app/views/courses/show.html.erb` (PASS)
- `sed -n '1,220p' app/views/expert_advisors/show.html.erb` (PASS)
- `sed -n '1,200p' app/controllers/marketplace_assets_controller.rb` (PASS)
- `sed -n '1,220p' docs/plans/marketplace-index-redesign.md` (PASS)
- `sed -n '1,260p' app/services/marketplace/index_presenter.rb` (PASS)
- `sed -n '260,520p' app/services/marketplace/index_presenter.rb` (PASS)
- `sed -n '520,1040p' app/services/marketplace/index_presenter.rb` (PASS)
- `sed -n '560,720p' app/services/marketplace/index_presenter.rb` (PASS)
- `sed -n '680,920p' app/services/marketplace/index_presenter.rb` (PASS)
- `sed -n '1,260p' app/views/marketplace/index.html.erb` (PASS)
- `sed -n '1,260p' app/views/marketplace/cards/_course_card.html.erb` (PASS)
- `sed -n '1,220p' app/models/addon.rb` (PASS)
- `rg -n "acts_as_taggable" app/models` (PASS)
- `rg -n "marketplace" config/locales/dashboard.en.yml` (PASS)
- `sed -n '110,220p' config/locales/dashboard.en.yml` (PASS)
- `rg -n "marketplace" config/locales/dashboard.es.yml` (PASS)
- `sed -n '110,220p' config/locales/dashboard.es.yml` (PASS)
- `rg -n "Cards 2|Cards 5|Cards 6|Digital Goods|Popular Categories|Trending Now" mosaic-html/dashboard_marketplace_index.html` (PASS)
- `sed -n '1490,1735p' mosaic-html/dashboard_marketplace_index.html` (PASS)
- `sed -n '1870,1995p' mosaic-html/dashboard_marketplace_index.html` (PASS)
- `sed -n '1995,2055p' mosaic-html/dashboard_marketplace_index.html` (PASS)
- `sed -n '1030,1125p' mosaic-html/dashboard_marketplace_index.html` (PASS)
- `rg -n "dashboard.marketplace.index.title|marketplace.index.title" -g "*.rb" -g "*.erb"` (PASS)
- `sed -n '1,200p' app/models/course.rb` (PASS)
- `sed -n '1,220p' app/models/expert_advisor.rb` (PASS)
- `sed -n '1,200p' app/models/license.rb` (PASS)
- `rg -n "IndexPresenter" spec/services spec` (FAIL)
- `ls spec/services` (PASS)
- `ls spec/services/marketplace` (PASS)
- `sed -n '1,200p' spec/services/marketplace/catalog_spec.rb` (PASS)
- `rg -n "truncate\\(" app/views/marketplace app/views/dashboard -g "*.erb"` (PASS)
- `rg -n "Features list|\\<li class=\\\"flex items-center\\\"\\>" -n mosaic-html/dashboard_marketplace_index.html` (PASS)
- `rg -n "dashboard\\.marketplace" app/views/marketplace app/services/marketplace/index_presenter.rb` (PASS)
- `git status -sb` (PASS)
