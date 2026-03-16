# Plan: Promotion Code Modal Responsive Fix

**Generated**: 2026-03-16
**Estimated Complexity**: Medium

## Goal
Fix the authenticated promotion code modal so long title/body/code content renders without overlapping or truncation, and the modal remains aligned and usable across small and large responsive viewports.

## Definition of Done
- The dashboard promotion modal renders long EN/ES copy without text spilling across sections or outside the card.
- Long promotion codes remain readable and copyable in a single-line presentation without breaking the modal layout.
- Small-screen and short-height viewports keep the modal fully reachable, with predictable spacing and action alignment.
- The shared modal continues to work on every route that currently renders it, including dashboard and marketplace surfaces.
- Existing modal behavior remains intact: Alpine open/close flow, session-based dismissal key, CTA destination, and I18n-driven copy.
- Validation covers at least request-level render coverage plus an explicit responsive QA pass for long-content scenarios.
- Audit Gate records PASS/FAIL for code pattern/efficiency, feature behavior, and tests context before implementation is considered done.

## Constraints
- Keep scope limited to the shared dashboard promotion modal, not a broader dashboard visual redesign.
- Reuse existing Mosaic-aligned dashboard patterns instead of introducing a new modal system.
- Keep controllers unchanged unless a view contract issue is discovered.
- Keep copy I18n-driven and avoid inline durable strings.
- Do not edit vendor template assets under `app/assets/templates/...`.

## Current Findings
- Shared modal markup lives in `app/views/dashboards/_discount_marketing_modal.html.erb`.
- Shared modal styling lives in `app/assets/stylesheets/dashboard.css`.
- The same modal is asserted in `spec/requests/dashboard_spec.rb` and `spec/requests/marketplace_spec.rb`, so any layout fix needs to preserve both surfaces.
- `PromotionCode#code` is format-validated but does not have a max-length validation, so the layout needs a practical fallback for unusually long admin-entered codes.
- Likely layout failure points:
  - `.promotion-modal-title`, `.promotion-modal-text`, and `.promotion-modal-code` do not currently enforce safe wrapping for long unbroken strings.
  - The dialog container is vertically centered with `fixed inset-0 flex items-center`, which can clip the modal on short mobile viewports instead of allowing natural top alignment and scroll.
  - The shell uses `overflow-hidden`, which is visually desirable but can hide content once the modal exceeds viewport height.
  - Footer actions currently rely on a generic wrap row, which does not guarantee a clean mobile layout.
- User direction captured on 2026-03-16:
  - Small screens may rearrange to a mobile-first stack.
  - Footer actions may become stacked full-width buttons on mobile.
  - Short-height devices should favor top-aligned viewport scrolling over a self-scrolling modal body.
  - Promotion code should stay visually single-line rather than becoming a wrapped multi-line block.

## Proposed Sprints
### Sprint 1: Layout Contract
**Goal**: Lock down desired responsive behavior and content handling rules before editing the UI.
**Demo/Validation**:
- Review affected routes and confirm the modal contract for long copy, long codes, and mobile action layout.

#### Task 1.1: Confirm Responsive UX Rules
- **Location**: `app/views/dashboards/_discount_marketing_modal.html.erb`, `app/assets/stylesheets/dashboard.css`
- **Description**: Lock the final code overflow treatment while preserving the confirmed mobile footer stacking and top-aligned viewport scrolling behavior.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Long code rendering behavior is explicit and consistent with the single-line shrink-to-fit requirement.
  - Mobile footer alignment behavior is explicit.
  - Viewport overflow behavior is explicit.
- **Validation**:
  - User confirmation against screenshots or stated expectations.

### Sprint 2: Modal Structure and CSS Hardening
**Goal**: Update the shared modal markup and styling so it handles long content and small screens predictably.
**Demo/Validation**:
- Load dashboard and marketplace routes with long-content fixtures and confirm the modal remains readable and usable.

#### Task 2.1: Harden Modal Content Layout
- **Location**: `app/views/dashboards/_discount_marketing_modal.html.erb`
- **Description**: Adjust structure only where needed to support better small-screen stacking, action grouping, and top-aligned viewport scrolling without changing the existing Alpine behavior or CTA contract.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Markup cleanly supports mobile-first stacking and long-content containment.
  - Close/copy/CTA behavior remains unchanged.
- **Validation**:
  - Manual route inspection on dashboard and marketplace pages.

#### Task 2.2: Add Safe Wrapping and Viewport Constraints
- **Location**: `app/assets/stylesheets/dashboard.css`
- **Description**: Add wrapping, overflow, spacing, and breakpoint-specific rules so long titles/body text and single-line shrink-to-fit codes plus short viewport heights do not break the layout.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Long title and body copy wrap instead of bleeding outside their sections.
  - Long codes remain visible and copyable in a single-line treatment that shrinks font size before the layout breaks.
  - Small screens keep all actions reachable.
- **Validation**:
  - Manual responsive QA at desktop and narrow/short mobile sizes.

### Sprint 3: Regression Coverage and Audit
**Goal**: Preserve route integration and document any remaining layout-only testing gaps.
**Demo/Validation**:
- Run targeted specs and a manual responsive QA checklist.

#### Task 3.1: Keep Render Coverage Aligned
- **Location**: `spec/requests/dashboard_spec.rb`, `spec/requests/marketplace_spec.rb`
- **Description**: Update request coverage only if the modal contract or class hooks change; otherwise preserve current route-level assertions and add focused expectations where useful.
- **Dependencies**: Task 2.1, Task 2.2
- **Acceptance Criteria**:
  - Shared modal render coverage still passes on dashboard and marketplace routes.
  - Any renamed hooks or structural assumptions are updated in specs.
- **Validation**:
  - Targeted request specs pass.

#### Task 3.2: Run Responsive QA and Audit Gate
- **Location**: This plan file
- **Description**: Record QA results and PASS/FAIL audit outcomes for code pattern, behavior alignment, and test context.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Audit Gate status is recorded.
  - Remaining risks, if any, are explicit.
- **Validation**:
  - PASS/FAIL entries added after implementation.

## Testing Strategy
- Preserve request spec coverage for dashboard and marketplace modal rendering.
- Add a manual QA checklist for:
  - Desktop width with long title/body/code.
  - Narrow mobile width.
  - Short mobile height.
  - EN and ES copy length.
  - Copy button and CTA visibility.
  - Extremely long code strings to verify the minimum practical readable size.
- If layout risk remains high after CSS changes, consider a system or Playwright check for one representative mobile viewport.

## Potential Risks & Gotchas
- Allowing arbitrary wrapping for promotion codes can reduce readability if the product expects codes to stay visually compact.
- Solving height issues at the shell level can unintentionally clip shadows or overlay spacing if max-height and scroll containers are applied in the wrong layer.
- Because `PromotionCode#code` has no max-length validation, shrink-to-fit code styling may eventually hit a readability floor for pathological values; if that happens, the follow-up fix should be a product decision, not a CSS-only patch.
- Over-tuning for pathological single-token strings could harm the normal visual rhythm for standard campaign copy.
- Because current automated coverage is request-level, visual regressions can still slip through unless the manual QA checklist is executed carefully.

## Rollback Plan
- Revert modal partial and stylesheet changes in:
  - `app/views/dashboards/_discount_marketing_modal.html.erb`
  - `app/assets/stylesheets/dashboard.css`
- Revert any spec updates tied to new hooks or structure.

## Open Questions
- None at the moment.
- Working assumptions:
  - Scope is the current shared modal partial on dashboard and marketplace routes.
  - The final layout should stay visually close to the current design, while allowing a more robust mobile-first rearrangement.

## Decisions
- Follow `AGENTS.md` plan-first workflow and keep this plan active under `docs/plans/` until the feature is implemented and audited.
- Use the `planner` skill for the implementation plan and `mosaic-html-rails` for dashboard-surface alignment.
- Skip external documentation lookup for now because the issue is repo-local Rails/ERB/CSS behavior rather than an external library integration.
- User confirmed on 2026-03-16 that mobile can stack the content and footer actions.
- User confirmed on 2026-03-16 that short-height screens should use top-aligned viewport scrolling rather than a self-scrolling modal body.
- User prefers a single-line promotion code treatment with overflow handling rather than a multi-line wrapped code block.
- User confirmed on 2026-03-16 that the preferred single-line code treatment is font shrink-to-fit rather than horizontal scrolling.
- Implemented a top-aligned, viewport-scrollable dialog container instead of a centered fixed shell.
- Kept the existing Alpine modal lifecycle and copy-button hooks while adding dedicated hooks for code fitting.
- Added a JS shrink-to-fit helper with a binary search plus exact-fit fallback because CSS-only sizing was insufficient for long single-line codes.
- Preserved request-level route coverage and added a long-content render contract check in dashboard request specs.

## Command Log (PASS/FAIL)
- `PASS` `sed -n '1,260p' AGENTS.md`
- `PASS` `rg -n "promotion code|promo code|discount code|codigo de descuento|código de descuento|coupon|promotion" app config lib spec`
- `PASS` `sed -n '1,220p' docs/plans/_archive/2026-03-06-discount-marketing-modal-with-dashboard-fallback.md`
- `PASS` `sed -n '1,240p' app/views/dashboards/_discount_marketing_modal.html.erb`
- `PASS` `sed -n '205,435p' app/assets/stylesheets/dashboard.css`
- `PASS` `sed -n '80,150p' spec/requests/dashboard_spec.rb`
- `PASS` `sed -n '245,285p' spec/requests/marketplace_spec.rb`
- `PASS` `sed -n '1,260p' app/models/promotion_code.rb`
- `PASS` `sed -n '1,220p' /home/loldlm/.agents/skills/rails-expert/SKILL.md`
- `PASS` `sed -n '1,260p' /home/loldlm/rails_projects/tradingsniperpanel.com/.agents/skills/mosaic-html-rails/references/rails-porting.md`
- `PASS` `sed -n '1,220p' /home/loldlm/.codex/skills/playwright/SKILL.md`
- `PASS` `node --check app/javascript/dashboard.js`
- `FAIL` `bundle exec rspec spec/requests/dashboard_spec.rb spec/requests/marketplace_spec.rb` after browser QA seed polluted the shared test DB with an active promotion
- `PASS` `RAILS_ENV=test bin/rails runner 'PromotionCode.delete_all; User.where(email: "modal.qa@example.com").delete_all'`
- `PASS` `bundle exec rspec spec/requests/dashboard_spec.rb spec/requests/marketplace_spec.rb`
- `PASS` `RAILS_ENV=test bin/rails server -p 3001`
- `PASS` `RAILS_ENV=test bin/rails runner '...create modal.qa@example.com and long active promotion...'`
- `PASS` `npx -y -p playwright-core node <<'EOF' ... responsive login + screenshot + overflow metrics ... EOF`
- `PASS` `find output/playwright -type f -delete && rmdir output/playwright`

## Audit Gate
- `PASS` Code pattern and efficiency: modal layout stays isolated to the shared partial and dashboard stylesheet, while the new fit logic is a small dashboard JS helper with explicit DOM hooks instead of fragile inline measurement logic.
- `PASS` Feature behavior and goal alignment: long title/body text now wraps inside the modal, small screens use a stacked footer layout with top-aligned viewport scrolling, and responsive browser QA confirmed no horizontal overflow for title/body/code in the exercised long-content scenario.
- `PASS` Tests context: request specs for dashboard and marketplace remain green, with an added dashboard assertion for the responsive modal hooks. Gap noted: there is still no permanent automated visual regression test, so responsive layout coverage remains request-spec plus browser-QA based.
