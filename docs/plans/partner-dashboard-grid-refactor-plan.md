# Plan: Partner Dashboard Grid Refactor

**Generated**: 2026-03-14
**Estimated Complexity**: Medium

## Goal
Simplify `dashboard/partner` by removing low-value payout status/history sections, reorganizing the main card layout, and fixing the current grid behavior so left-column cards do not inherit tall blank space from the stacked right rail.

## Definition of Done
- `app/views/dashboard/partner/show.html.erb` uses a simpler card layout centered on the existing `<!-- Cards -->` section.
- The section nav contains only `Overview` and `Referrals`.
- `app/views/dashboard/partner/_request_health_card.html.erb` is no longer rendered from the partner dashboard.
- `app/views/dashboard/partner/_payout_history_section.html.erb` is no longer rendered from the partner dashboard.
- `app/views/dashboard/partner/_referral_hub_card.html.erb` is no longer rendered from the partner dashboard because its referral code/share-link actions are preserved in the page header.
- `#partner-overview`, the chart plot card, and `#partner-referrals` stack cleanly in the main content column without vertical dead space caused by the payout rail.
- The right-side cards behave as independent grid items instead of forcing one shared row height with the main content column.
- The referrals header/count label is corrected and no longer shows placeholder text such as `__COUNT__ matches for "__QUERY__"`.
- Existing partner dashboard behavior, filtering, copy-to-clipboard actions, and payout request actions still work.

## Constraints
- Keep this refactor view-scoped unless an existing helper or locale key must be adjusted.
- Preserve Mosaic section comments, dashboard shell structure, current chart/copy hooks, and existing Rails-owned assets only.
- Do not rename JS-bound selectors or chart ids without updating every dependent initializer.
- Prefer ERB/layout simplification before introducing new CSS or JS.
- Keep durable UI copy in `config/locales/en.yml` and `config/locales/es.yml`.

## Current Findings
- The current top layout uses one grid row with `#partner-overview` as a single `xl:col-span-8` item and `#partner-payouts` as a single `xl:col-span-4` item in [show.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/show.html.erb).
- Because the right rail is wrapped in one tall parent with `space-y-6`, the shared grid row height expands to the tallest rail content, leaving unused vertical space under the left overview stack.
- The chart plot is already split into [\_chart_plot_card.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/_chart_plot_card.html.erb), so the next refactor is mostly about grid placement and section removal.
- The page header already exposes the referral code and copy-share-link action, so [\_referral_hub_card.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/_referral_hub_card.html.erb) is redundant.
- The referrals count label in [\_referrals_section.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/_referrals_section.html.erb) depends on JS string replacement in `app/javascript/dashboard.js`; the reported placeholder output suggests that formatting is not being applied in at least one render path.

## Proposed Approach
Use one 12-column page grid, but make each major card a direct grid item instead of nesting all right-rail content inside one `#partner-payouts` wrapper. Keep the referral/share actions in the page header and remove the duplicate referral hub card. The approved direction is:

1. Keep `#partner-overview` as the first `xl:col-span-8` item.
2. Render the payout action card as the paired `xl:col-span-4` item beside overview.
3. Render the chart plot card as its own `xl:col-span-8` item directly below overview.
4. Keep the program snapshot card as the paired `xl:col-span-4` item beside the chart plot.
5. Render `#partner-referrals` as the next `xl:col-span-8` item below the chart plot.
6. Remove the `Payouts` nav chip so the page nav only targets overview and referrals.

This pattern makes row heights independent by card pair, keeps the right rail lighter, and should remove the tall blank area without custom CSS.

## Sprint 1: Layout Simplification
**Goal**: Replace the nested two-column dashboard structure with a flatter, card-level grid that matches the intended stacking order.

**Demo/Validation**:
- Load `/dashboard/partner` in desktop and tablet widths.
- Verify the overview, chart, and referrals sections stack in the left content column without inherited blank height.
- Verify the right-side cards remain aligned and readable in light and dark mode.

### Task 1.1: Flatten the main card grid
- **Location**: [show.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/show.html.erb)
- **Description**: Replace the current `#partner-overview` / `#partner-payouts` parent grouping with direct grid items for each surviving card in the approved order: overview + payout action, chart + program snapshot, referrals.
- **Dependencies**: None
- **Acceptance Criteria**:
  - `#partner-overview` remains addressable by the existing filter chip.
  - The chart plot card renders below overview in the main content column.
  - The left column no longer stretches to match the full height of a stacked right-rail wrapper.
- **Validation**:
  - Manual responsive QA at the reported failing width plus desktop/mobile checks.

### Task 1.2: Remove unused payout status/history sections from the page
- **Location**: [show.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/show.html.erb)
- **Description**: Stop rendering `request_health_card`, `payout_history_section`, and the duplicate `referral_hub_card`; remove any now-unused wrapper columns and the `Payouts` nav chip.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - The page no longer shows request-health, payout-history, or duplicate referral/share panels.
  - The page still exposes payout request actions in the right rail and referral/share actions in the page header.
  - The section nav contains only overview and referrals.
- **Validation**:
  - Request spec assertions updated to match the new rendered page content.

### Task 1.3: Keep the program snapshot as the secondary right-rail card
- **Location**: [show.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/show.html.erb), [\_program_snapshot_card.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/_program_snapshot_card.html.erb)
- **Description**: Keep the snapshot card below payout action so the right rail contains one primary action card and one secondary context card without duplicating the page header.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - The remaining cards have a clear hierarchy: payout action first, program context second.
  - The right rail does not feel empty after removing referral hub, request health, and payout history.
- **Validation**:
  - Manual UI review against the approved card order.

## Sprint 2: Referrals Section Cleanup
**Goal**: Make the referrals section title/counter copy consistent and remove the placeholder-label bug.

**Demo/Validation**:
- Load `/dashboard/partner`.
- Type into the referrals search field and verify the count label updates correctly.
- Clear the query and verify the total label is restored.

### Task 2.1: Fix referrals section naming and count text
- **Location**: [\_referrals_section.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/_referrals_section.html.erb), [en.yml](/home/loldlm/rails_projects/tradingsniperpanel.com/config/locales/en.yml), [es.yml](/home/loldlm/rails_projects/tradingsniperpanel.com/config/locales/es.yml)
- **Description**: Keep the existing section title/copy and limit this pass to the broken count text behavior only.
- **Dependencies**: None
- **Acceptance Criteria**:
  - The existing section heading and supporting copy remain unchanged.
  - No new locale churn is introduced unless the count text needs a safer fallback string.
- **Validation**:
  - Manual render check in both locales if feasible; otherwise verify locale key coverage.

### Task 2.2: Fix client-side count-template replacement
- **Location**: [\_referrals_section.html.erb](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboard/partner/_referrals_section.html.erb), [dashboard.js](/home/loldlm/rails_projects/tradingsniperpanel.com/app/javascript/dashboard.js)
- **Description**: Ensure the placeholder templates stored in `data-total-template` and `data-filtered-template` are replaced with real count/query values on first load and during client-side filtering.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - No `__COUNT__` or `__QUERY__` placeholder text appears in the UI.
  - The count label stays accurate when filtering and clearing.
- **Validation**:
  - Manual search interaction test.
  - Optional JS test only if the repo already has a low-friction pattern for dashboard behavior.

## Sprint 3: Verification and Audit
**Goal**: Confirm the refactor is behavior-safe and aligned with the requested simplification.

**Demo/Validation**:
- Run the partner dashboard request spec.
- Do a focused manual QA pass on layout, search, copy buttons, and payout CTA behavior.

### Task 3.1: Update request spec expectations
- **Location**: [dashboard_partner_spec.rb](/home/loldlm/rails_projects/tradingsniperpanel.com/spec/requests/dashboard_partner_spec.rb)
- **Description**: Adjust assertions that currently depend on payout history being present, and add coverage for removed sections where it improves regression confidence.
- **Dependencies**: Sprint 1, Sprint 2
- **Acceptance Criteria**:
  - Specs cover the intended visible sections after the refactor.
  - Removed sections are asserted absent where meaningful.
- **Validation**:
  - `bundle exec rspec spec/requests/dashboard_partner_spec.rb`

### Task 3.2: Run the required Audit Gate
- **Location**: This plan file
- **Description**: Perform the required PASS/FAIL audit for code pattern/efficiency, feature behavior/goal alignment, and tests context before implementation is considered complete.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Audit results are recorded as PASS/FAIL with short notes.
  - Any FAIL is fixed and re-audited before closing the task.
- **Validation**:
  - Audit notes appended to the active plan.

## Testing Strategy
- Primary automated coverage: [dashboard_partner_spec.rb](/home/loldlm/rails_projects/tradingsniperpanel.com/spec/requests/dashboard_partner_spec.rb)
- Primary manual coverage: desktop/tablet/mobile responsive QA on `/dashboard/partner`, dark/light theme, referrals filtering, copy buttons, and payout request CTA state
- Optional manual locale pass: English and Spanish copy length on the affected headers/buttons

## Risks & Gotchas
- The current anchor chips target section ids, so moving cards must preserve `#partner-overview` and `#partner-referrals` while intentionally removing the `#partner-payouts` chip/anchor behavior.
- Removing payout history may invalidate an existing request spec that explicitly expects that section today.
- The referrals label bug may be caused by JS initialization timing rather than locale content alone.
- Removing the referral hub card shifts all referral/share actions into the page header, so header spacing and mobile wrap behavior need a manual check.

## Open Questions
- None at the planning stage.

## Audit Gate
- **Code pattern and efficiency**: PASS
  The refactor stayed mostly view-scoped: one `<!-- Cards -->` grid, independent left/right column stacks, obsolete partials removed, dead controller/presenter wiring trimmed, and only a minimal JS formatter fix added for the referrals counter.
- **Feature behavior and goal alignment**: PASS
  The dashboard now shows only `Overview` and `Referrals` in the nav, keeps referral/share actions in the page header, removes the duplicate referral hub plus payout history/request-health sections, and preserves the requested visual order of overview, chart, referrals, payout action, and program snapshot.
- **Tests context**: PASS
  Request-spec coverage was updated and passes. A real-browser QA pass covered desktop light mode, desktop dark mode, mobile dark mode, and the referrals search/count behavior. No existing low-friction JS unit-test layer was present for this dashboard behavior, so browser QA is the practical coverage for the counter fix.

## Status Log
- PASS: reviewed AGENTS workflow and the `planner` and `mosaic-html-rails` skills before drafting the plan
- PASS: inspected the current partner dashboard view, affected partials, controller, presenter, locale keys, request spec, and dashboard JS filter logic
- PASS: user confirmed final nav scope, card stacking order, keeping the program snapshot card, limiting referrals changes to the broken count text, and removing the duplicate referral hub in favor of the page header
- PASS: implemented the partner dashboard layout in `app/views/dashboard/partner/show.html.erb` as a single `<!-- Cards -->` grid with `items-start`, left-column stacking for overview/chart/referrals, and right-column stacking for payout action/program snapshot
- PASS: removed the `Payouts` nav chip and deleted obsolete partials `app/views/dashboard/partner/_referral_hub_card.html.erb`, `app/views/dashboard/partner/_request_health_card.html.erb`, and `app/views/dashboard/partner/_payout_history_section.html.erb`
- PASS: fixed the referrals count placeholder bug in `app/javascript/dashboard.js` by supporting both `%{count}`-style and `__COUNT__`-style client-side replacements
- PASS: removed unused payout-history wiring from `app/controllers/dashboard/partner_controller.rb` and `app/services/dashboard/partner_presenter.rb`
- PASS: updated `spec/requests/dashboard_partner_spec.rb`
- PASS: `bundle exec rspec spec/requests/dashboard_partner_spec.rb`
- PASS: `bundle exec rails runner "load Rails.root.join('db/seeds/shared.rb'); qa = Seeds::QaUsers.seed!; Seeds::Partners.seed_qa!(partner: qa[:partner]); puts({ email: qa[:partner].email, password: Seeds::QaUsers::DEFAULT_PASSWORD }.inspect)"`
- PASS: Playwright CLI QA against `http://127.0.0.1:3000/en/dashboard/partner` in headed Firefox, including screenshots `output/playwright/partner-dashboard-light-desktop.png`, `output/playwright/partner-dashboard-dark-desktop.png`, and `output/playwright/partner-dashboard-dark-mobile.png`
