# Plan: Dashboard Product Release Visual QA Sprint

**Generated**: 2026-03-29
**Status**: Completed after follow-up fixes
**Estimated Complexity**: Medium

## Goal
Run a dedicated visual QA sprint for the new dashboard product release notification feature using `ux-audit` and `playwright`, with Firefox in headless mode, so the bell/dropdown flow is clean before deploy.

## Definition of Done
- The release bell/dropdown is visually validated on desktop and mobile widths.
- The key audience rules are verified in a browser session:
  - add-ons visible to all signed-in users
  - EA updates visible only to users with access to that EA
  - course additions visible only to users with access to that course
- Dismiss flow is verified visually and behaviorally.
- EN and ES copy is checked in the real dashboard.
- A written UX audit report is produced with ranked findings and screenshot evidence.

## Constraints
- Use `ux-audit` as the review mindset and reporting structure.
- Use `playwright` for browser automation.
- Use Firefox headless for efficiency unless a visual defect requires headed rerun.
- Treat this as a separate sprint from implementation; do not mix in new feature work unless the audit reveals a blocking defect.
- Prefer the real deployed/authenticated environment if available. Use local only if the feature is not yet deployed.

## Prerequisites
- Feature branch deployed or locally runnable with the release-notification feature enabled.
- At least three QA users or seeded states:
  - user who should only see add-on release items
  - user who should see an EA update
  - user who should see a course addition
- A recent published `ProductRelease` batch in the target environment.
- `npx` available for the Playwright wrapper flow:
  - command: `command -v npx >/dev/null 2>&1`

## Sprint 1: Browser Preflight
**Goal**: Confirm the target environment and automation path are ready.
**Demo/Validation**:
- Can open the dashboard in Playwright Firefox headless.
- Can authenticate or reuse a valid signed-in session for QA.

### Task 1.1: Resolve target URL and environment
- **Location**: runtime environment, `README.md`, deploy context
- **Description**: Choose the audit target in this order:
  - deployed production/staging URL if available
  - local dashboard URL only if the feature is not yet deployed
- **Validation**:
  - target URL documented in the QA report

### Task 1.2: Confirm Playwright CLI preflight
- **Location**: terminal environment
- **Description**: Verify `npx` exists, point to the `playwright` wrapper, and confirm Firefox headless launch works.
- **Validation**:
  - preflight command passes
  - a simple dashboard open/snapshot works

## Sprint 2: UX Audit Walkthrough
**Goal**: Dogfood the bell/dropdown as a real signed-in user.
**Demo/Validation**:
- One walkthrough completed end-to-end as a user with a relevant unread release.

### Task 2.1: Primary persona walkthrough
- **Location**: dashboard header and notification dropdown across dashboard pages
- **Description**: Use a normal signed-in trader persona and verify:
  - bell discoverability
  - unread dot trust signal
  - dropdown clarity
  - item labeling
  - item click-through usefulness
  - dismiss confidence
- **Validation**:
  - findings recorded with severity and screenshots

### Task 2.2: Resilience checks
- **Location**: same dashboard flow
- **Description**: Verify:
  - reload before dismiss
  - reload after dismiss
  - back button after click-through
  - empty notification state
- **Validation**:
  - pass/fail notes in the audit report

## Sprint 3: Cross-State Visual QA
**Goal**: Verify the feature under the intended audience and layout states.
**Demo/Validation**:
- All required states covered with evidence.

### Task 3.1: Audience-rule validation
- **Description**: Validate these scenarios in the browser:
  - add-on release visible to all signed-in users
  - EA update hidden from non-owners and visible to owners
  - course addition hidden from non-owners and visible to owners
- **Validation**:
  - screenshots and report notes per user state

### Task 3.2: Responsive and theme sweep
- **Description**: Verify the bell/dropdown at:
  - `1280px`
  - `768px`
  - `375px`
  and in both light/dark themes if available.
- **Validation**:
  - screenshots saved for each breakpoint/state

### Task 3.3: Locale sweep
- **Description**: Verify EN and ES copy lengths, truncation behavior, and clarity.
- **Validation**:
  - no clipped or confusing release copy in either locale

## Sprint 4: Reporting And Triage
**Goal**: Produce a deploy-readiness UX audit output.
**Demo/Validation**:
- Report written and ready for review.

### Task 4.1: Save artifacts
- **Location**: `output/playwright/`
- **Description**: Save screenshots and any browser artifacts under the repo-owned Playwright output path.
- **Validation**:
  - evidence files present and named clearly

### Task 4.2: Write UX audit report
- **Location**: `docs/ux-audit-product-release-notifications-2026-03-29.md`
- **Description**: Record:
  - critical/high/medium/low findings
  - click-efficiency notes
  - trust/confusion observations
  - final “would I come back?” verdict
- **Validation**:
  - report includes top issues, screenshots, and recommendation on deploy readiness

## Testing Strategy
- Run the walkthrough as at least 3 user states.
- Re-check any issue once after reproducing it.
- If a bug is fixed during the QA sprint, rerun the affected flow before closing the report.

## Risks
- Local-only QA can miss deployment-specific layout or auth issues.
- The bell/dropdown may look correct on desktop but become cramped in ES or on `375px`.
- Firefox headless may hide some subtle animation/layout timing issues that require a targeted headed rerun.

## Next Step Trigger
- Start this sprint only after the current feature branch is considered implementation-complete and a release batch can be published for QA.

## Execution Notes
- PASS: local QA target resolved to `http://127.0.0.1:3000`
- PASS: `command -v npx >/dev/null 2>&1`
- PASS: Firefox headless preflight via local Playwright package
- PASS: sourced `.envrc` and ran `bundle exec rails db:seed`
- PASS: created a local grouped `ProductRelease` batch for QA with one add-on, one EA update, and one course item
- PASS: ran `node script/product_release_visual_qa.mjs`
- PASS: artifacts saved under `output/playwright/product-release-qa/`
- PASS: report written to `docs/ux-audit-product-release-notifications-2026-03-29.md`
- FAIL: deploy readiness due owner-visible EA update missing from the dropdown
- FAIL: mobile `375px` dropdown shifts off-canvas to the left

## Outcome
- PASS: initial audit surfaced the two blocking defects clearly
- PASS: follow-up fixes resolved the owner EA visibility issue
- PASS: follow-up fixes resolved the mobile `375px` dropdown alignment issue
- PASS: rerun confirmed add-on, EA, and course visibility rules in EN and ES
- PASS: dismiss still removes the unread dot and persists after reload
- PASS: final report updated to deploy-ready status for this feature slice

## Rerun Notes
- PASS: command `set -a && source .envrc && set +a && bundle exec rails runner 'ProductReleaseDismissal.delete_all'`
- PASS: command `node script/product_release_visual_qa.mjs`
- PASS: rerun artifacts updated under `output/playwright/product-release-qa/`
- PASS: rerun report updated in `docs/ux-audit-product-release-notifications-2026-03-29.md`
