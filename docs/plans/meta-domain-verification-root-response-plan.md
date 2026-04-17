# Plan: Meta Domain Verification Root Response

**Generated**: 2026-04-17
**Estimated Complexity**: Low-Medium

## Overview
Investigate why `https://tradingsniperpanel.com/` returns `204 No Content` for some requests even though the Facebook domain verification meta tag exists in [`app/views/layouts/application.html.erb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/layouts/application.html.erb:1). The current evidence points to Rails content negotiation on the marketing home page rather than an SSL or nginx proxy failure. This plan stays intentionally app-first: make the root page reliably return HTML for Meta/Facebook verification, generic crawlers, and plain `curl`, then verify production on both apex and `www`. If verification still fails after that, create a separate follow-up logging/server plan.

## Definition of Done
- Root requests for the public home page return a stable `200 text/html` response for normal browser requests and crawler-like requests that do not send an explicit HTML `Accept` header.
- The Facebook domain verification meta tag is present in the first HTML document returned from the root URL.
- The production app behavior is verified on `https://tradingsniperpanel.com/` and `https://www.tradingsniperpanel.com/` after deploy with reproducible curl checks.
- The fix path is documented clearly enough to separate Rails app changes from server/deploy-only changes.
- Validation includes regression checks for the normal landing page and a clean fallback path if Meta still fails afterward.

## Constraints
- This is a production-facing marketing route; the landing page must keep working for real browsers.
- The repo uses dynamic landing templates under `app/views/templates/*/pages/home.html.erb`.
- The home action currently relies on implicit rendering in [`PagesController`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/controllers/pages_controller.rb:1).
- The production nginx setup in [`script/setup_common.sh`](/home/loldlm/rails_projects/tradingsniperpanel.com/script/setup_common.sh:712) is a standard reverse proxy and does not currently show a custom `204` rule.
- The plan should stay small enough to execute as one feature slice.
- Temporary production request logging is explicitly out of scope for this first pass.

## Current Findings
- PASS: The verification meta tag is present in the app layout at [`app/views/layouts/application.html.erb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/layouts/application.html.erb:9).
- PASS: The live site returns `HTTP/2 204` for `curl https://tradingsniperpanel.com` when the request uses curl's default `Accept: */*`.
- PASS: The live site returns `HTTP/2 200` with `content-type: text/html; charset=utf-8` when the same URL is requested with `Accept: text/html`.
- PASS: The live site also returns `HTTP/2 200` with `Accept: text/html` and `User-Agent: facebookexternalhit/1.1`.
- PASS: The HTML returned with `Accept: text/html` contains the `facebook-domain-verification` meta tag in `<head>`.
- PASS: `http://tradingsniperpanel.com/` currently redirects to `https://tradingsniperpanel.com/`, so plain HTTP is not the primary failure mode in the current deploy.
- PASS: Repo search did not find an explicit `head :no_content`, `status: 204`, or bot-specific short-circuit in app code.
- PASS: The most likely application-level cause is implicit rendering plus request-format negotiation on the root action.
- PASS: Official Rails docs confirm that implicit render behavior can return `204 No Content` when the request is not treated as a normal browser HTML page load.

## Decisions So Far
- Treat this first as a Rails response-format bug, not an SSL certificate or nginx rewrite bug.
- Success scope includes Meta verification plus reliable HTML delivery for generic crawlers and plain `curl`.
- Keep this first pass app-side only; inspect server logs or add temporary request logging only if the app fix does not solve the issue.
- Verify both `tradingsniperpanel.com` and `www.tradingsniperpanel.com` in smoke checks to avoid host-specific surprises.
- Prefer an explicit, testable response contract on the root action over relying on implicit rendering.
- DNS verification may be kept as an optional fallback, but it is not required for the first implementation slice.

## Investigation Log
- PASS: `sed -n '1,220p' README.md`
- PASS: `sed -n '1,260p' AGENTS.md`
- PASS: `sed -n '1,220p' app/views/layouts/application.html.erb`
- PASS: `sed -n '1,220p' config/routes.rb`
- PASS: `sed -n '1,220p' app/controllers/pages_controller.rb`
- PASS: `sed -n '1,260p' app/controllers/application_controller.rb`
- PASS: `sed -n '700,910p' script/setup_common.sh`
- PASS: `curl -sS -L -D - -o /dev/null https://tradingsniperpanel.com`
- PASS: `curl -sS -L -H 'Accept: text/html' -D - -o /dev/null https://tradingsniperpanel.com`
- PASS: `curl -sS -L -A 'facebookexternalhit/1.1' -H 'Accept: text/html' -D - -o /dev/null https://tradingsniperpanel.com`
- PASS: `curl -sS -L -H 'Accept: text/html' https://tradingsniperpanel.com | rg 'facebook-domain-verification|<head|</head>'`

## Execution Notes
- PASS: Added [`spec/requests/root_response_spec.rb`](/home/loldlm/rails_projects/tradingsniperpanel.com/spec/requests/root_response_spec.rb:1) to lock the root HTML contract for `Accept: */*` and `Accept: text/html`.
- FAIL: `bundle exec rspec spec/requests/root_response_spec.rb --format documentation` reproduced the current issue: `GET /` with `Accept: */*` returned `204 No Content`.
- PASS: Updated [`PagesController#home`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/controllers/pages_controller.rb:4) to prepend the landing template view path for non-HTML requests and explicitly render the HTML home template.
- PASS: `bundle exec rspec spec/requests/root_response_spec.rb --format documentation`
- PASS: `bundle exec rspec spec/requests/localization_spec.rb spec/requests/landing_template_spec.rb spec/requests/seo_meta_spec.rb --format documentation`
- PASS: `bundle exec rspec spec/requests/home_pricing_cta_spec.rb spec/requests/landing_template_locale_branding_spec.rb spec/requests/branding_spec.rb --format documentation`
- PASS: `bundle exec rspec spec/requests/root_response_spec.rb spec/requests/home_pricing_cta_spec.rb spec/requests/landing_template_locale_branding_spec.rb spec/requests/branding_spec.rb spec/requests/localization_spec.rb spec/requests/landing_template_spec.rb spec/requests/seo_meta_spec.rb --format progress`
- PASS: `bundle exec rubocop app/controllers/pages_controller.rb spec/requests/root_response_spec.rb`
- PASS: Reviewed `git diff -- app/controllers/pages_controller.rb spec/requests/root_response_spec.rb`

## Sprint 1: Reproduce And Fix The Root HTML Contract
**Goal**: Prove the exact failing request shape, then harden the Rails root action so `/` returns HTML consistently.
**Demo/Validation**:
- Reproduce current behavior locally or in production with a fixed curl matrix.
- Confirm the `204` is driven by request format/content negotiation and remove that failure mode with an explicit controller response.

### Task 1.1: Build A Request Matrix For `/`
- **Location**: investigation notes, optional request spec under `spec/requests/`
- **Description**: Test the root URL with combinations of `Accept`, `User-Agent`, `HEAD` versus `GET`, apex versus `www`, and HTTP versus HTTPS. Record which combinations return `204`, `200`, or redirects, but keep the matrix small and focused on the public marketing route.
- **Dependencies**: None
- **Acceptance Criteria**:
  - The matrix identifies the smallest reproducible input that triggers `204`.
  - The matrix distinguishes crawler behavior from generic curl behavior.
- **Validation**:
  - Curl commands with recorded status, content type, and body presence
  - Optional request spec reproducing the format issue

### Task 1.2: Confirm Rails Template Negotiation Path
- **Location**: [`app/controllers/pages_controller.rb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/controllers/pages_controller.rb:1), [`app/controllers/application_controller.rb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/controllers/application_controller.rb:1), `app/views/templates/*/pages/home.html.erb`
- **Description**: Trace how the root request resolves format and template. Confirm whether implicit rendering is falling back to `204` for non-HTML requests and whether `allow_browser` or locale/template selection affects that path. Use Rails docs as the reference for the final remediation choice.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - The specific code path causing the `204` is identified.
  - The plan selects one clear remediation strategy.
- **Validation**:
  - Local reproduction or targeted code inspection notes

### Build Tasks
- `GET /` returns `200 text/html` with the verification meta tag for browser-like and crawler-like requests.
- Normal page rendering remains unchanged for the active landing template.

### Task 1.3: Replace Implicit Root Rendering With Explicit HTML Handling
- **Location**: [`app/controllers/pages_controller.rb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/controllers/pages_controller.rb:1)
- **Description**: Change the home action to explicitly render the home template or explicitly respond to HTML formats so generic `Accept: */*` requests do not fall through to `204`.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - `GET /` no longer depends on implicit rendering for the public landing page.
  - The chosen implementation is simple, explicit, and compatible with the existing template switching logic.
- **Validation**:
  - Request spec or controller-level verification for `Accept: */*` and `Accept: text/html`

### Task 1.4: Add Regression Coverage For Root HTML Delivery
- **Location**: `spec/requests/` or the most relevant request-spec location
- **Description**: Add tests that prove the root page returns HTML and contains the verification meta tag under the request shapes most likely to matter for bots and support debugging.
- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - Tests fail on the old behavior and pass on the fixed behavior.
  - Coverage checks both status code and HTML response shape.
- **Validation**:
  - `bundle exec rspec` for the new request spec

## Sprint 2: Deploy Verification And Meta/Facebook Validation
**Goal**: Confirm the fix on production and close the loop with Meta verification.
**Demo/Validation**:
- Production curl checks show the corrected behavior for both apex and `www`.
- Meta verification can be retried with evidence ready if support escalation is needed.

### Task 2.1: Production Smoke Check
- **Location**: production shell, deploy notes
- **Description**: After deploy, run a small smoke checklist against apex and `www`, with and without explicit HTML `Accept`, and verify the meta tag is in the returned HTML. Keep the checks small enough to run immediately after deploy.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Production no longer returns `204` for the target request shapes.
  - No regression appears on the visible landing page.
- **Validation**:
  - Curl output summary captured in the implementation notes

### Task 2.2: Meta Retry And Evidence Pack
- **Location**: operator checklist
- **Description**: Retry verification in Meta Business Manager. If verification still fails after the app fix and smoke checks pass, collect the exact production response evidence and open a follow-up plan for temporary request logging and deeper server inspection.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Either the domain verifies successfully, or the remaining blocker is narrowed to real Meta crawler behavior with supporting evidence.
- **Validation**:
  - Meta UI result plus production request evidence

## Testing Strategy
- Prefer a request spec for `/` because this issue is about full-stack response behavior, not isolated view rendering.
- Verify both `Accept: */*` and `Accept: text/html`.
- Verify the response is HTML and that the verification meta tag is in `<head>`.
- Re-check `https://tradingsniperpanel.com/`, `https://www.tradingsniperpanel.com/`, and the HTTP redirect path after deploy.

## Potential Risks And Gotchas
- Meta may send request headers that differ from the simple curl reproduction; the plan should keep room for temporary request logging if the fix does not fully resolve verification.
- A forced HTML response for `/` should not accidentally affect JSON or other future formats if the root route is ever reused.
- If the issue is partially masked by CDN or reverse-proxy caching later, production verification needs to check headers from the live edge, not just local Rails.
- If `www.tradingsniperpanel.com` is also checked inside Meta, the smoke test must cover both hosts explicitly.

## Follow-Up Plan Only If Needed
- **Plan B**: temporary production request logging for Meta crawler requests
- **Plan C**: deeper nginx/Puma/access-log inspection if the app-first fix passes locally but fails in production

## Audit Gate
- PASS: Code pattern and efficiency
  Root-only controller change, no new service complexity, and no impact on query shape. The fix reuses the existing landing-template resolution instead of hardcoding a deploy-specific path.
- PASS: Feature behavior and goal alignment
  The new request spec proves the original failure mode and now verifies `GET /` returns `200 text/html` with the Meta verification tag even for `Accept: */*`.
- PASS: Tests context
  Relevant request coverage passed across the root contract, localization, landing-template selection, branding, pricing CTA behavior, and SEO meta output. Production smoke verification remains pending deploy because this workspace does not deploy automatically.

## Rollback Plan
- Revert the controller/request-spec change if the landing page regresses.
- Re-run the curl matrix to confirm behavior returned to the prior state.
- Leave nginx and SSL config untouched unless a later sprint proves the server layer is part of the failure.

## Open Questions
- No blocking questions for the app-first slice.
- If production verification still fails after Sprint 2, the next plan should decide whether to add temporary request logging, inspect nginx/Puma logs, or add DNS verification as a fallback.
