# Dashboard Expert Advisors Index Redesign

## Goal
- Rebuild `expert_advisors#index` to match `mosaic-html/dashboard_expert_advisors_index.html` layout with section comments intact.
- Populate each section with real data (licenses, guides, add-ons, bundles) using I18n strings (EN/ES).
- Add a lightweight, reusable client-side search filter for the EA cards.
- Restore test stability by fixing Pagy initialization and expanding request coverage for the EA index.

## Definition of Done
- `app/views/expert_advisors/index.html.erb` (and any partials) mirror the mockup structure, including HTML section comments.
- Card data is driven by existing models/services, with any new fields documented and editable.
- Add-on progress and purchase state render per EA without N+1 queries.
- Filters section shows max 5 EA tags using `app/views/dashboard/shared/_filter_chip.html.erb`.
- Search filter works client-side and is structured for reuse on `courses#index`.
- Pagy is initialized per docs so `Pagy::Frontend` loads in helpers and the suite boots cleanly.
- Request specs cover EA index pagination visibility, CTA states for locked vs accessible EAs, add-on progress rendering, and tag filter chips/data attributes (no system specs).
- New copy lives in `config/locales/dashboard.en.yml` and `config/locales/dashboard.es.yml`.

## Constraints
- Keep controllers thin; add a presenter/service under `app/services`.
- Avoid inline `<script>`/`<style>` in views; use `app/javascript`.
- Do not edit vendor assets under `app/assets/templates`.
- Preserve Mosaic classes/JS hooks and HTML comments from the mockup.
- Request specs only; no system specs or client-side filter automation.

## Steps
1. Map mockup sections to existing data (`Licenses::AccessibleExpertAdvisors`, guides, bundles, add-ons).
2. Use existing EA tags for filter chips (max 5) and decide filter behavior (server/client).
3. Build an `ExpertAdvisors::IndexPresenter` (or similar) to assemble card view models, add-on progress, search text, and pagination (Pagy).
4. Update the index view and extract a card partial, keeping the mockup’s HTML comments.
5. Add a reusable JS search filter in `app/javascript` and wire data attributes in the view.
6. Add/adjust translations and update `docs/database_model_reference.md` if schema changes.
7. Add a Pagy initializer per docs (require frontend helpers, set defaults if needed) and verify the suite boots.
8. Update `spec/requests/expert_advisors_spec.rb` for the new index behavior:
   - Remove/replace status/type filter assertions.
   - Add pagination assertions (nav presence only when > 8 cards, hidden classes on non-page items).
   - Add locked vs accessible CTA assertions (guide URL, download enabled/disabled, license copy state).
   - Add tag chip + data attribute assertions for filter/search.
   - Add add-on progress assertions (0/0 renders, owned/unowned CTAs).
9. Run request specs and full suite; record PASS/FAIL in the progress log.

## Open Questions
- (none)

## Progress Log
- Decision: use existing EA tags for filter chips (max 5).
- Decision: remove header CTA; place CTAs inside item sections for locked EAs.
- Decision: server-side pagination via Pagy; render controls only when > 8 cards.
- Decision: add-ons list only for EA addonables; show up to 3 items, fewer if fewer exist (progress shows `0/0` when none).
- Decision: client-side search matches name/description/type/tags/add-on names; reusable for courses.
- Decision: tag chips replace existing status/type filters.
- Decision: top 5 tags by usage.
- Decision: tag filter client-side (JS).
- Decision: locked “View Guide” links to marketplace/plans unlock flow.
- Decision: top 5 tags computed from the current user’s accessible EAs.
- Decision: load all EAs when filters/search are active so filtering is global.
- Decision: render all EA cards in the DOM and hide non-page items when no filters/search are active.
- Decision: request specs should assert marketplace-linked guide CTAs when a product is available.
- Decision: pagination coverage should include `page=2` visibility changes.
- Decision: assert all CTA states (guide link, download enabled/disabled, license copy, add-on purchase).
- Command: bundle install (PASS)
- Command: bundle exec rspec (FAIL)
- Decision: load Pagy series helper for custom pagination rendering.
- Decision: check `hidden` as a CSS class token to avoid `overflow-hidden` false positives.
- Command: bundle exec rspec (PASS)
