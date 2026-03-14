# Plan: Partner Dashboard Mosaic Alignment

**Generated**: 2026-03-13
**Estimated Complexity**: Medium-High

## Goal
Audit and refactor `/dashboard/partner` so the authenticated partner dashboard reads as a real Cruip Mosaic page, while preserving the current referral, payout, chart, search, and access-control behavior.

## Definition of Done
- `app/views/dashboard/partner/show.html.erb` and its partials are rebuilt from chosen `mosaic-html/` source sections instead of bespoke dashboard styling.
- The page preserves current behavior from `Dashboard::PartnerController`, `Dashboard::PartnerPresenter`, `PartnerDashboardHelper`, and `app/javascript/dashboard.js`.
- Theme toggle compatibility still works through `.light-switch` and `localStorage['dark-mode']`.
- Desktop, tablet, and mobile boundaries are verified, including empty/filter/pending states.
- Existing request coverage remains valid or is updated, and test gaps are explicitly called out.
- Audit Gate ends in `PASS` for pattern/efficiency, feature alignment, and tests context.

## Constraints
- Use local Mosaic source pages first. Working source hypothesis:
  - `mosaic-html/dashboard_analytics.html` for page header, metric strip, and primary chart rhythm.
  - `mosaic-html/users-tabs.html` or `mosaic-html/transactions.html` for searchable/tabular referral and payout lists.
  - `mosaic-html/billing.html` for panel framing and secondary information blocks.
- Preserve source section comments wherever those sections are ported.
- Preserve `#partner-paid-earnings-chart`, `data-partner-chart`, search params, pagination hooks, and payout CTA behavior.
- Preserve `DASHBOARD_PALETTE` compatibility so the page continues to inherit the configured dashboard palette rather than hardcoding a one-off accent scheme.
- Do not edit `app/assets/templates/mosaic/**/*`.
- Keep new durable copy in `config/locales/dashboard.en.yml` and `config/locales/dashboard.es.yml`.

## Confirmed Decisions
- Overall feel: deliberate Mosaic mix, biased toward partner-facing analytics, profits, and referrals.
- Styling direction: match Mosaic styling rather than preserve the current bespoke partner styling.
- Filters: Mosaic-style chips/tabs are allowed if they fit the chosen source sections and do not complicate the backend contract unnecessarily.
- Information architecture: the page may be reordered to match the chosen Mosaic source more closely.
- Partner page header: promote one primary partner action into the local page-header action row.
- Header action choice: use copy/share referral link as the promoted page-header action.
- QA: Playwright remains optional and is only for final visual verification if manual QA needs support.
- Tests: no new browser/system specs are planned; request specs may be updated if the HTML contract changes enough to justify it.
- Palette handling: `DASHBOARD_PALETTE` remains a hard requirement for any dashboard-facing color decisions.
- Chips/tabs, if added, are visual or section-navigation only for now and do not introduce real filtering behavior.
- Sign-off does not require separate manual EN/ES visual approval gates; localized copy should still ship in the same implementation pass.

## Status Log
- PASS: inspected `AGENTS.md` workflow and repo-specific frontend constraints.
- PASS: inspected partner route, controller, presenter, helpers, JS hooks, and current partials.
- PASS: inspected in-repo Mosaic references and likely source pages for page-header, chart, table, and panel composition.
- PASS: inspected existing request coverage for `/dashboard/partner`.
- PASS: refactored `app/views/dashboard/partner/show.html.erb` and active partner partials to Mosaic page-header, card, table, and panel patterns.
- PASS: promoted the copy/share referral action into the partner page header and added section-navigation chips for overview, referrals, and payouts.
- PASS: updated `app/javascript/dashboard.js` so the partner chart reads dashboard `--brand-*` palette variables instead of hardcoded sky accents.
- PASS: removed unused pre-refactor partials `_hero.html.erb` and `_stat_card.html.erb`.
- PASS: `bundle exec rspec spec/requests/dashboard_partner_spec.rb`
- PASS: Playwright QA in test env on `http://127.0.0.1:3001/en/dashboard/partner` covering authenticated render, screenshot capture, dark-mode toggle, and mobile-width render.
- PASS: follow-up dark-theme pass replaced low-contrast inset cards with solid Mosaic dark surfaces and widened the inner summary grids.
- PASS: follow-up chart pass replaced the all-zero blank chart area with an explicit empty state while preserving palette-aware rendering for real data.
- PASS: follow-up search pass converted partner referrals to a JS-driven in-page filter with GET fallback preserved for non-JS submission.
- PASS: cleaned temporary Playwright QA records from the test database and reran `bundle exec rspec spec/requests/dashboard_partner_spec.rb`.

## Current Findings
- The current partner page is composed from custom-styled partials under `app/views/dashboard/partner/` and does not follow the existing Mosaic comment map or vendor utility stacks.
- The behavior layer is already cleanly separated into presenter/controller/helper code, which makes this primarily a source-mapping and ERB composition task.
- The dashboard shell already includes the Mosaic theme toggle hook in `app/views/layouts/dashboard.html.erb`.
- Existing request coverage in `spec/requests/dashboard_partner_spec.rb` covers access, referral visibility, payout history visibility, filtering, and payout request flows, but not visual parity or theme/responsive behavior.

## Sprint 1: Audit And Source Mapping
**Goal**: Freeze the UI contract and pick exact Mosaic sections before any ERB rewrite.
**Demo/Validation**:
- A section-by-section source map exists for the partner page.
- Each current behavior/state has an explicit destination in the new layout.

### Task 1.1: Inventory partner page contracts
- **Location**: `app/controllers/dashboard/partner_controller.rb`, `app/services/dashboard/partner_presenter.rb`, `app/helpers/partner_dashboard_helper.rb`, `app/javascript/dashboard.js`, `app/views/dashboard/partner/*`
- **Description**: Document all required behaviors, states, and DOM hooks that the redesign cannot break.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Chart, search, copy, payout request, history, and empty-state behavior are enumerated.
  - Mobile vs desktop rendering differences are identified before layout changes.
- **Validation**:
  - Cross-check every partial against controller/presenter data inputs and helper/JS dependencies.

### Task 1.2: Choose exact Mosaic source sections
- **Location**: `mosaic-html/dashboard_analytics.html`, `mosaic-html/users-tabs.html`, `mosaic-html/transactions.html`, `mosaic-html/billing.html`
- **Description**: Select the smallest complete source sections that can be ported with closest-practical parity.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Top header, primary analytics area, referrals area, and payout/history rail each have a named source section.
  - Any unavoidable deviations are logged before implementation.
- **Validation**:
  - Source choices are reviewable and map cleanly onto the current partner information architecture.

### Task 1.3: Define audit criteria and QA matrix
- **Location**: Plan file, request spec checklist, optional Playwright QA notes
- **Description**: Lock the pass/fail checks for layout parity, responsiveness, theme behavior, and preserved backend outcomes.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Manual QA states are enumerated.
  - Optional Playwright usage is scoped to visual/regression verification, not new test authoring by default.
- **Validation**:
  - Audit checklist is concrete enough to run after implementation.

## Sprint 2: Mosaic Parity Refactor
**Goal**: Port the partner page to Mosaic structure without changing business logic.
**Demo/Validation**:
- The partner page visually sits in the same design family as the existing Mosaic dashboard pages.
- Existing data and actions still render and submit correctly.

### Task 2.1: Rebuild the top-level page structure
- **Location**: `app/views/dashboard/partner/show.html.erb`
- **Description**: Replace the bespoke wrapper composition with a comment-preserved Mosaic layout using the chosen header/grid/card structure.
- **Dependencies**: Sprint 1 complete
- **Acceptance Criteria**:
  - Top-level section comments match the selected source map.
  - Grid rhythm and spacing align with Mosaic dashboard patterns already used elsewhere in the repo.
  - Reordering is allowed when it improves parity with the selected Mosaic source while keeping partner priorities clear.
  - The partner page header includes one promoted primary action that matches the final source composition.
- **Validation**:
  - Compare against the selected `mosaic-html/` source at desktop width.

### Task 2.2: Port partner sections with minimal behavioral drift
- **Location**: `app/views/dashboard/partner/_*.html.erb`
- **Description**: Rework referral, payout, chart, and history partials to use Mosaic panels/tables/cards while keeping existing data bindings and CTAs.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Search/filter, pagination, badges, chart canvas, and payout button still use current Rails hooks.
  - Any added chips/tabs map to a real Mosaic pattern and remain visual or section-navigation only.
  - Empty, pending, paid, and notification-failed states still render.
- **Validation**:
  - Render review against seeded partner states and existing request specs.

### Task 2.3: Preserve theme, I18n, and app-owned overrides
- **Location**: `config/locales/dashboard.en.yml`, `config/locales/dashboard.es.yml`, optional Rails-owned stylesheet/JS touchpoints
- **Description**: Add only the copy and app-owned styling needed to support the port without touching vendor assets.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Any new durable copy is localized in EN/ES.
  - Dark mode, `DASHBOARD_PALETTE`, and responsive breakpoints remain intact.
- **Validation**:
  - Light/dark checks and EN/ES copy-length pass on the refactored page.

## Sprint 3: Verification And Audit Gate
**Goal**: Confirm the redesign is behaviorally safe and visually aligned.
**Demo/Validation**:
- Request specs pass.
- Manual QA checklist is complete.
- Audit Gate is recorded as `PASS` or loops once for fixes.

### Task 3.1: Run regression checks
- **Location**: request specs plus manual browser verification
- **Description**: Re-run partner dashboard request coverage and verify key UI states manually.
- **Dependencies**: Sprint 2 complete
- **Acceptance Criteria**:
  - Existing partner request flows still pass.
  - No layout break is found in mobile/tablet/desktop checks.
- **Validation**:
  - `spec/requests/dashboard_partner_spec.rb` and manual state review.

### Task 3.2: Optional Playwright visual QA
- **Location**: `output/playwright/` artifacts if used
- **Description**: Capture headed-browser evidence for theme toggle, responsive layout, and major partner states if manual QA needs support.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Screenshots/snapshots cover the final page only if needed.
  - No Playwright-specific code is added to the app unless separately requested.
- **Validation**:
  - Browser snapshot confirms Mosaic alignment and no obvious regressions.

### Task 3.3: Audit Gate
- **Location**: Plan file updates and final summary
- **Description**: Run the required PASS/FAIL audit for pattern quality, goal alignment, and test coverage relevance.
- **Dependencies**: Task 3.2 if used, otherwise Task 3.1
- **Acceptance Criteria**:
  - Failures are either fixed or escalated with a mini-plan if ambiguous.
  - Final summary records audit status and remaining risks.
- **Validation**:
  - Audit checklist is completed before closing the feature.

## Testing Strategy
- Keep `spec/requests/dashboard_partner_spec.rb` as the baseline behavioral safety net.
- Add or adjust request coverage only where markup or routing expectations materially change.
- Manually verify:
  - light mode and dark mode
  - `DASHBOARD_PALETTE` variants that are expected in this repo
  - desktop, tablet, and mobile widths
  - empty referrals/history states
  - filtered referrals state
  - pending and paid payout states
  - localized copy layout sanity without requiring separate manual sign-off gates for both locales

## Potential Risks And Gotchas
- Mixing sections from multiple Mosaic pages can drift back into custom UI if the source map is not fixed first.
- The chart card can look correct but silently break if `#partner-paid-earnings-chart` or theme-sensitive chart colors are disrupted.
- The current page has dense partner-specific payout/referral utility content; consolidation is acceptable, but no data or action should disappear.
- The promoted header action must be chosen deliberately; the wrong choice could weaken the page hierarchy or bury the more stateful payout flow.
- Request specs will not catch responsive or theme regressions, so manual QA or Playwright evidence may be necessary.

## Rollback Plan
- Keep changes scoped to partner view partials, partner locales, and minimal app-owned CSS/JS support.
- Avoid backend changes so rollback can be handled by reverting the partner page refactor only.

## Audit Gate
- **Code pattern and efficiency**: PASS
  Refactor stayed in the presentation layer, preserved the existing controller/presenter/helper boundaries, reused dashboard `brand` palette utilities, and removed dead pre-refactor partials.
- **Feature behavior and goal alignment**: PASS
  The partner page now follows Mosaic header/card/table composition more closely, keeps the copy/share action in the page header, preserves referral search/pagination, payout request behavior, chart rendering, and theme toggle compatibility.
- **Follow-up polish scope**: PASS
  Dark-mode inset cards now separate cleanly, the zero-data chart no longer wastes vertical space, and referral search now behaves like the other dashboard index filters instead of requiring a round-trip on every query.
- **Tests context**: PASS
  `spec/requests/dashboard_partner_spec.rb` passes after the refactor. No browser/system specs were added by design; the visual gap was covered with Playwright screenshots/snapshots in the QA pass.

## Open Questions
- None. Plan is ready for implementation.
