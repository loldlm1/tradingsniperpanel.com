# Expert Advisors Show Redesign

## Goal
Rebuild `expert_advisors#show` to match the Mosaic mock-up (`mosaic-html/dashboard_expert_advisors_show.html`) with real data, preserving Cruip comment blocks, IDs, and JS hooks while keeping Rails view logic minimal.

## Definition of Done
- The show page matches the mock-up layout/structure and retains all HTML section comments from the source template.
- All UI copy is I18n-driven (EN-first with ES translations) with new keys added; no inline strings except data values.
- Each mock-up section is wired to real data with clear empty/locked states (system info, guides, license, charts, add-ons, balance distribution).
- Charts render via existing `data-dashboard-chart` initializer (no inline scripts) with stable IDs/legend containers.
- View logic is pushed into a presenter/service + partials; controller remains thin and avoids N+1s.
- Tests cover presenter calculations and basic rendering for accessible vs locked users.
- After implementation, this plan is updated with additional test-coverage next steps (no separate doc).

## Constraints
- Follow `docs/cruip_template_guide.md`; do not alter vendor assets under `app/assets/templates`.
- Keep Mosaic classes/IDs/Alpine hooks intact; keep template HTML comments intact.
- No inline `<script>` or `<style>`; use existing JS helpers (`copyToClipboard`) and data attributes.
- Optimize queries via eager loading and scoped aggregations.

## Decisions
- “Ultimos ingresos” chart shows last 30 days PnL.
- Balance distribution groups by broker company (using PnL totals).
- License card is always visible; locked/expired states show CTA/disabled UI.
- Guide card shows CTA/disabled state for locked users.
- Add-ons list capped to 3; ordering is unowned first, then owned.
- Copy is EN-first with ES translations.
- Extra data to surface: last sync timestamp + broker accounts count/list.
- QA updates: back link uses inline arrow style; guide section uses fixed copy (no markdown preview); license card uses compact input+copy layout; show only latest broker account on license card.

## Finding Plan (QA Follow-up)
- Inspect the show header markup (`app/views/expert_advisors/show.html.erb`) to locate the right-side badge container and its parent layout (flex/grid), then identify which class or wrapper prevents it from aligning to the top-right corner at `lg+`.
- Inspect the index guide section (`app/views/expert_advisors/_index_card.html.erb`) to confirm the CTA wrapper layout and any width/column constraints that keep buttons from stacking full-width across breakpoints.
- Reproduce both issues in the browser at `lg`, `xl`, and mobile widths to validate current behavior before changes.
- Document the exact class adjustments needed (alignment + stacking) before implementation.

## Steps
1. **Section/Data mapping**: define a per-section data contract for the mock-up blocks:
   - System header (name, description, status badge, type badge).
   - System details (tiers, trial enabled, guide EN/ES availability, file/bundle availability, last sync, broker accounts count).
   - Guide card (summary + guide/download actions).
   - License card (status, key, copy metadata, expiry/trial countdown).
   - PnL line chart (EA-specific 30-day series + totals).
   - Balance distribution pie (EA-specific broker-company distribution).
   - Add-ons list + progress (owned vs available + CTA link).
2. **Presenter/service**: add `ExpertAdvisors::ShowPresenter` that composes:
   - Status/access from `Licenses::AccessibleExpertAdvisors` entry.
   - Guide availability from `doc_guide_en/es` and preview (`ExpertAdvisors::GuidePreview`).
   - Bundle availability from `ExpertAdvisors::BundleResolver` + `ea_files`.
   - Add-ons from `Addon` + `MarketplacePurchase` (cap 3; unowned first).
   - EA-scoped PnL chart + broker distribution from `BrokerAccountDailyResult` (30-day window).
   - Broker account list/count + license last sync timestamp.
3. **Controller wiring**: instantiate the presenter in `ExpertAdvisorsController#show`, passing user/entry/locale; ensure required associations are preloaded.
4. **View rebuild**: replace `app/views/expert_advisors/show.html.erb` with the mock-up markup, preserving HTML comments and chart IDs; split into partials for card blocks.
5. **I18n**: add/adjust keys in `config/locales/dashboard.en.yml` + `.es.yml` for all labels, empty states, and CTAs.
6. **Tests**:
   - Presenter spec for status, add-on progress, chart payload shapes, broker count/list, and empty states.
   - Request spec confirming page renders for accessible and locked users.
7. **Verify**: manual smoke check in browser; run specs.
8. **QA refinements**:
   - Update the back-link UI to match the inline arrow style from QA.
   - Replace guide preview markdown with fixed guide copy (no dynamic heading).
   - Redesign the license block to the compact input+copy layout.
   - Show only the most recent broker account synced for the EA in the license card.
   - Fix `yes/no` translation keys in EN/ES locale files.
   - Adjust layout to reduce the gap between columns when heights differ.
   - Update specs impacted by copy/layout changes.
9. **Dark-mode QA + layout polish**:
   - Use the license section styling from the EA index card for dark-mode contrast.
   - Use the shared filter chip for broker account type badges.
   - Choose a dashboard-standard layout to avoid large column whitespace.
   - Update AGENTS.md with enabled MCP servers list.
10. **Verify**: manual smoke check in browser (dark theme); run specs.
11. **Header + index guide tweaks**:
   - Align the show header right-side badges to the card corner.
   - Update EA index guide CTA layout to match the 3-button stack (guide, details, full-width download).
12. **Verify**: visual review of show + index (light theme).
13. **Post-implementation**: update this plan with additional test-coverage next steps, then archive per AGENTS.md.
14. **QA follow-up (current)**:
   - Diagnose why header badges are not at the top-right corner on desktop.
   - Ensure index guide buttons render as a full-width vertical stack on all breakpoints.
   - Visual verify in light + dark + mobile.

## Open Questions
- For the header badges: should they be pinned to the card’s top-right padding edge on `lg+`, even if it means stacking them above the title, or keep them aligned to the title row but right-aligned within it?
- For the guide buttons: should all three be full-width on every breakpoint (including desktop), with consistent vertical spacing?

## Execution Notes
- Commands run:
  - apply_patch docs/plans/expert-advisors-show-redesign.md (PASS)
  - apply_patch config/locales/dashboard.en.yml (PASS)
  - apply_patch config/locales/dashboard.es.yml (PASS)
  - apply_patch app/services/expert_advisors/show_presenter.rb (PASS)
  - apply_patch app/views/expert_advisors/show.html.erb (PASS)
  - apply_patch app/views/expert_advisors/_show_license_card.html.erb (PASS)
  - apply_patch spec/requests/expert_advisors_spec.rb (PASS)
  - apply_patch spec/services/expert_advisors/show_presenter_spec.rb (PASS)
  - bundle exec rspec spec/services/expert_advisors/show_presenter_spec.rb spec/requests/expert_advisors_spec.rb (PASS)
  - bin/rails runner QA seed + broker results (PASS)
  - mcp__playwright__browser_navigate (FAIL)
  - mcp__playwright__browser_install (FAIL)
  - apply_patch AGENTS.md (PASS)
  - bin/rails server -p 3000 -d (PASS)
  - agent-browser open http://localhost:3000/en/users/sign_in (PASS)
  - agent-browser snapshot -i (PASS)
  - agent-browser fill @email/@password (PASS)
  - agent-browser click Sign in (PASS)
  - agent-browser open http://localhost:3000/en/dashboard/expert_advisors/sniper_advanced_panel (PASS)
  - agent-browser screenshot --full /tmp/ea-show.png (PASS)
  - apply_patch AGENTS.md (PASS)
  - apply_patch app/views/expert_advisors/show.html.erb (PASS)
  - apply_patch app/views/expert_advisors/_show_license_card.html.erb (PASS)
  - bin/rails runner qa@example.com seed + broker results (FAIL)
  - bin/rails runner qa@example.com seed + broker results (PASS)
  - agent-browser open http://localhost:3000/en/dashboard/expert_advisors/sniper_advanced_panel (PASS)
  - agent-browser set dark-mode (PASS)
  - agent-browser screenshot --full /tmp/ea-show-dark-v2.png (PASS)
  - bundle exec rspec (PASS)
  - kill puma 7.1.0 (PASS)
  - apply_patch app/views/expert_advisors/show.html.erb (PASS)
  - apply_patch app/views/expert_advisors/_index_card.html.erb (PASS)
  - agent-browser open http://localhost:3000/en/dashboard/expert_advisors (PASS)
  - agent-browser screenshot --full /tmp/ea-index-buttons.png (PASS)
  - agent-browser open http://localhost:3000/en/dashboard/expert_advisors/sniper_advanced_panel (PASS)
  - agent-browser screenshot --full /tmp/ea-show-header.png (PASS)
  - apply_patch app/controllers/expert_advisors_controller.rb (PASS)
  - cat > app/services/expert_advisors/show_presenter.rb (PASS)
  - apply_patch app/services/expert_advisors/show_presenter.rb (PASS)
  - cat > app/views/expert_advisors/show.html.erb (PASS)
  - cat > app/views/expert_advisors/_show_license_card.html.erb (PASS)
  - cat > app/views/expert_advisors/_show_addons.html.erb (PASS)
  - apply_patch config/locales/dashboard.en.yml (PASS)
  - apply_patch config/locales/dashboard.es.yml (PASS)
  - apply_patch spec/requests/expert_advisors_spec.rb (PASS)
  - cat > spec/services/expert_advisors/show_presenter_spec.rb (PASS)
  - bundle exec rspec spec/services/expert_advisors/show_presenter_spec.rb spec/requests/expert_advisors_spec.rb (FAIL)
  - apply_patch spec/services/expert_advisors/show_presenter_spec.rb (PASS)
  - bundle exec rspec spec/services/expert_advisors/show_presenter_spec.rb spec/requests/expert_advisors_spec.rb (PASS)
  - bundle exec rspec spec/services/expert_advisors/show_presenter_spec.rb spec/requests/expert_advisors_spec.rb (PASS)
  - bundle exec rspec (PASS)
  - apply_patch app/views/expert_advisors/show.html.erb (PASS)
  - apply_patch app/views/expert_advisors/_index_card.html.erb (PASS)
  - agent-browser open http://localhost:3000/en/dashboard/expert_advisors/sniper_advanced_panel (PASS)
  - agent-browser set viewport 1440 900 (PASS)
  - agent-browser screenshot --full /tmp/ea-show-header-fix.png (PASS)
  - agent-browser open http://localhost:3000/en/dashboard/expert_advisors (PASS)
  - agent-browser screenshot --full /tmp/ea-index-guide-buttons-fix.png (PASS)
  - agent-browser close (PASS)

## Post-Implementation Test Coverage Next Steps
- Add presenter specs for trial/expired/revoked statuses to verify badge classes and expiry labels.
- Add presenter spec for empty chart states (no PnL results, no broker distribution) to ensure nil charts and empty copy render.
- Add request spec for locked guide CTA + disabled download button states.
- Add request spec for add-ons when none exist (progress 0/0 and empty list copy).
- Add request spec covering multiple broker companies for balance chart legend ordering/\"Other\" bucket.
