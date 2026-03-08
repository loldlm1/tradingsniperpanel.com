# Plan: Stripe Promotion Code Admin Dashboard

**Status**: Implemented, follow-up bugfix audit PASS
**Generated**: 2026-03-08
**Estimated Complexity**: High
**Skills**: planner, rails-expert

## Overview
- Replace the env-driven dashboard discount banner with a first-class Stripe-backed promotion record managed in ActiveAdmin.
- Use one admin CRUD to manage both the local promotion record and the related Stripe coupon / promotion code objects through service objects.
- Move modal rendering to the dashboard layout so the active promotion is available across dashboard routes, refresh the modal UI for dark theme, and align marketplace checkout buttons with the shared loading-state behavior.

## Follow-up Bugfix
- Investigate the production `Stripe::InvalidRequestError` raised while updating an admin-managed promotion.
- Align `Stripe::PromotionCode.create` with Stripe's current API contract for promotion-backed codes.
- Add a regression spec that asserts the outgoing create payload shape so admin create/update cannot silently drift again.

## Definition of Done
- Admins can create, view, edit, activate, deactivate, and archive promotion code records from ActiveAdmin.
- Activating one promotion atomically deactivates any other active promotion records.
- The active promotion is sourced from the database and Stripe metadata rather than `DISCOUNT_BANNER_CODE` / `DISCOUNT_BANNER_PERCENT`.
- Dashboard modal content supports per-record EN/ES title, body, and CTA label and appears across dashboard pages rather than only `/dashboard`.
- Marketplace buy buttons use the same loading/disabled UX pattern already used in subscription checkout actions.
- Referral discounts remain higher priority than promotions and continue to suppress manual promotion entry when applied.
- Request/service coverage exists for admin CRUD, activation rules, Stripe sync, checkout behavior, and dashboard rendering behavior.

## Locked Decisions
- Use a single ActiveAdmin CRUD and let service objects create or sync the Stripe coupon and Stripe promotion code automatically.
- Referral discounts win. When a referral discount is applied, the app should not allow user-entered promotion codes for that checkout session.
- A simple pre-apply flow from the modal CTA is acceptable only if it does not require a second complex discount path.
- Stripe coupon duration should be `once`.
- EN/ES `title`, `body`, and `cta_label` are mandatory per promotion record.
- Stripe restrictions such as expiration date and max redemptions should be optional and hidden or collapsed by default in the admin form.
- Only one promotion can be active globally.
- Inactive promotions remain editable and can be re-activated.
- All ActiveAdmin users can manage promotions.
- The modal should be available across all authenticated dashboard pages.
- The old public home-page discount usage should be removed instead of migrated.
- The active promotion applies to both subscription plan checkouts and one-time marketplace/product checkouts.

## Constraints
- Follow existing Rails patterns: thin controllers, service objects, I18n-driven copy, ActiveAdmin for back-office CRUD.
- Keep Stripe operations idempotent and explicit; do not silently swallow API failures.
- Stay compatible with the `pay` gem checkout flow already used in `DashboardsController` and `MarketplaceController`.
- Keep UI chrome translated via locale files, but store promotion-specific EN/ES marketing copy on the promotion record itself.
- Preserve current referral discount behavior and do not regress the existing Stripe checkout flows.

## Current State
- Dashboard discount modal is rendered only in `DashboardsController#show` via `Marketing::DiscountBanner`, which currently reads `DISCOUNT_BANNER_CODE` and `DISCOUNT_BANNER_PERCENT`.
- `Marketing::DiscountBanner` is also used by `PagesController#home`, and that public-site discount usage should be removed as part of this change.
- The modal partial is [`app/views/dashboards/_discount_marketing_modal.html.erb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/dashboards/_discount_marketing_modal.html.erb) and uses fixed copy keys plus session storage.
- The dashboard layout is the right cross-route rendering point: [`app/views/layouts/dashboard.html.erb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/layouts/dashboard.html.erb).
- Dashboard plans subscription buttons already use `loading_label`, but marketplace checkout in [`app/views/marketplace/show.html.erb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/marketplace/show.html.erb) does not.
- Referral discounts currently convert checkout sessions from `allow_promotion_codes: true` to `discounts: [{ coupon: ... }]`, which prevents end-user promotion code entry when a referral coupon is applied.

## Prerequisites
- Stripe secret key available in environments where remote sync should run.
- Stripe official docs confirmed for Checkout discounts and promotion-code restrictions.
- Pay official docs confirmed that checkout session params are passed through `current_user.payment_processor.checkout(...)`.
- Existing request/service spec harness will stub Stripe calls rather than hit the network.

## Sprint 1: Promotion Domain and Stripe Sync
**Goal**: Introduce a local promotion record with explicit Stripe sync boundaries and a safe single-active rule.
**Demo/Validation**:
- Create or update a promotion record locally in test mode without rendering it yet.
- Confirm activation flips every other record to inactive in one transaction.

### Task 1.1: Add promotion persistence model
- **Location**: `db/migrate/*create_promotion_codes.rb`, `app/models/promotion_code.rb`
- **Description**: Add a local model for admin-managed promotions with global activation state, EN/ES marketing copy, Stripe identifiers, optional limits, and basic audit/status fields.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Record stores `code`, `percent_off`, `active`, `title_en`, `title_es`, `body_en`, `body_es`, `cta_label_en`, `cta_label_es`.
  - Record stores Stripe references such as `stripe_coupon_id` and `stripe_promotion_code_id`.
  - Stripe sync rules fix coupon duration to `once`.
  - Optional advanced restriction fields are persisted without being mandatory.
  - Validation prevents invalid percentage values and duplicate active records at the app level.
- **Validation**:
  - Model spec for validations and the single-active rule.

### Task 1.2: Add admin upsert / activation services
- **Location**: `app/services/admin/promotion_code_upsert.rb`, `app/services/admin/promotion_code_activation.rb`, `app/services/billing/stripe_promotion_code_sync.rb`
- **Description**: Create service objects that normalize admin input, sync Stripe coupon + promotion code objects, and deactivate competing records when one promotion becomes active.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Create and update use one service entry point.
  - Stripe coupon creation uses `duration: "once"`.
  - Stripe sync errors are surfaced back to ActiveAdmin with structured logs.
  - Activation is atomic locally and mirrors remote `active` state where supported.
  - If immutable Stripe fields change, the service can mint replacement Stripe objects and update the local record safely.
- **Validation**:
  - Service specs with Stripe stubs for create, update, activate, deactivate, and failure paths.

## Sprint 2: ActiveAdmin CRUD
**Goal**: Give admins a practical back-office UI for promotion lifecycle management.
**Demo/Validation**:
- Admin can create a promotion with EN/ES copy.
- Admin can activate one promotion and observe every other record becoming inactive.

### Task 2.1: Add ActiveAdmin resource
- **Location**: `app/admin/promotion_codes.rb`, `config/locales/active_admin.en.yml`, `config/locales/active_admin.es.yml`
- **Description**: Add index, filters, show, form, and permitted params for promotion management using the existing admin resource patterns.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Form groups core fields separately from advanced Stripe restriction fields.
  - Index and show views expose local state and Stripe identifiers clearly.
  - All ActiveAdmin users can access the resource through the standard admin auth path.
- **Validation**:
  - Request spec for admin index/new/create/update/show.

### Task 2.2: Add explicit activation / deactivation workflow
- **Location**: `app/admin/promotion_codes.rb`, `app/services/admin/promotion_code_activation.rb`
- **Description**: Provide an explicit admin action or status toggle that makes activation intent obvious and safe.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Activating one record deactivates the previous active record in the same request.
  - Admin feedback explains whether Stripe sync succeeded or failed.
  - Re-activation of a previously inactive record is supported.
- **Validation**:
  - Request spec for activation and deactivation behavior.

## Sprint 3: Dashboard Promotion Delivery
**Goal**: Source the active promotion from the database and make it available across dashboard routes.
**Demo/Validation**:
- The modal appears on `/dashboard`, `/dashboard/plans`, and another dashboard route using the same active promotion.
- Session storage still prevents noisy repeated openings for the same promotion.

### Task 3.1: Replace env-driven banner resolver and remove home-page usage
- **Location**: `app/services/marketing/discount_banner.rb`, `app/services/marketing/active_promotion_resolver.rb`, `app/controllers/dashboards_controller.rb`, `app/controllers/pages_controller.rb`
- **Description**: Replace direct env lookup with a database-backed resolver that returns the currently active promotion payload for the dashboard modal, and remove the public home-page discount dependency entirely.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Dashboard uses the active promotion record instead of `DISCOUNT_BANNER_CODE` / `DISCOUNT_BANNER_PERCENT`.
  - Resolver returns locale-aware title/body/CTA payload and the displayed promotion code.
  - `PagesController#home` no longer builds or depends on a discount banner.
  - Existing env variables are deprecated in README and no longer required.
- **Validation**:
  - Service spec for active promotion resolution.
  - Request spec proving the dashboard modal renders from DB-backed data.
  - Request/spec cleanup proving the home page no longer depends on discount env vars.

### Task 3.2: Render modal from dashboard layout and refresh the design
- **Location**: `app/views/layouts/dashboard.html.erb`, `app/views/dashboards/_discount_marketing_modal.html.erb`, `app/assets/stylesheets/dashboard.css`
- **Description**: Move modal rendering to the shared dashboard layout and restyle the component for better dark-theme readability and stronger marketing hierarchy.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Modal is available across dashboard routes.
  - EN/ES record copy is rendered correctly.
  - Dark theme contrast, spacing, and CTA styling are improved.
  - The storage key varies by promotion identity so a new active promo can reopen.
- **Validation**:
  - Request/view spec for modal presence and translated content.

### Task 3.3: Optional simple pre-apply path from modal CTA
- **Location**: `app/services/billing/checkout_promotion_resolver.rb`, `app/controllers/dashboards_controller.rb`, `app/controllers/marketplace_controller.rb`
- **Description**: If kept simple, add a lightweight signal from the modal CTA so the next checkout can auto-attach the active promotion when no referral discount is present.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Pre-apply path does not conflict with referral discounts.
  - Pre-apply path works for both subscription and one-time marketplace/product checkouts when eligible.
  - If the promotion is auto-applied, checkout still remains deterministic and logs which discount path won.
  - If pre-apply is skipped, manual code entry still works on non-referral checkouts via `allow_promotion_codes: true`.
- **Validation**:
  - Request/service spec covering referral-wins and non-referral flows.

## Sprint 4: Checkout UX Alignment
**Goal**: Make marketplace checkout buttons behave like other dashboard actions.
**Demo/Validation**:
- Clicking a marketplace buy button swaps to the existing spinner/loading label and blocks repeated submissions.

### Task 4.1: Convert marketplace submit button to shared loading pattern
- **Location**: `app/views/marketplace/show.html.erb`, `app/javascript/application.js`, `app/javascript/marketplace_show.js`
- **Description**: Rework the marketplace purchase button so it uses `loading_label` and `data-loading-target` consistently with plan subscription buttons.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Button uses the shared spinner markup.
  - Repeated clicks are blocked once the form is valid and submitted.
  - Cart total refresh logic still updates the visible label correctly before submit.
  - The shared loading behavior stays compatible with promotion-enabled one-time checkout sessions.
- **Validation**:
  - View or request coverage for rendered loading markup.
  - Manual browser check in the dashboard marketplace flow.

## Sprint 5: Test Coverage, Docs, and Audit Gate
**Goal**: Close the feature with coverage, deprecation cleanup, and a formal PASS/FAIL audit.
**Demo/Validation**:
- Specs covering the new promotion flow pass.
- README and plan file reflect the new source of truth.

### Task 5.1: Add or update specs
- **Location**: `spec/models/promotion_code_spec.rb`, `spec/services/admin/promotion_code_upsert_spec.rb`, `spec/services/marketing/discount_banner_spec.rb`, `spec/requests/dashboard_spec.rb`, `spec/requests/dashboard_billing_spec.rb`, `spec/requests/admin_promotion_codes_spec.rb`
- **Description**: Cover model validations, Stripe sync services, admin CRUD, activation exclusivity, modal rendering, and checkout discount precedence.
- **Dependencies**: Sprints 1-4
- **Acceptance Criteria**:
  - Coverage exists for successful and failing Stripe sync paths.
  - Coverage proves referral discounts override active promotions.
  - Coverage proves only one promotion can remain active.
  - Coverage proves promotion handling works for both subscription and one-time checkout flows.
  - Coverage removes home-page env-banner assumptions.
- **Validation**:
  - Targeted RSpec runs for affected files, then broader regression pass as time allows.

### Task 5.2: Deprecation and docs cleanup
- **Location**: `README.md`, `.envrc.example`, `docs/plans/stripe-promotion-code-admin-dashboard-plan.md`
- **Description**: Remove dashboard reliance on the old env vars, document the admin-managed source of truth, and capture any rollout steps.
- **Dependencies**: Sprint 3
- **Acceptance Criteria**:
  - Dashboard-specific env var docs are deprecated or removed.
  - Operational notes explain how to create the first active promotion safely.
- **Validation**:
  - Doc review in diff.

### Task 5.3: Audit Gate
- **Location**: Plan file update + final implementation pass
- **Description**: Run the required PASS/FAIL audit for code patterns, goal alignment, and tests context before marking the feature done.
- **Dependencies**: Task 5.1, Task 5.2
- **Acceptance Criteria**:
  - Audit status is recorded as PASS or FAIL in the plan.
  - Any FAIL is fixed and re-audited before completion.
- **Validation**:
  - Final audit summary in task closeout.

## Testing Strategy
- Prefer request specs for dashboard, checkout, and ActiveAdmin flows.
- Use service specs for Stripe sync and active-promotion resolution.
- Stub Stripe API objects and errors; do not hit the network in tests.
- Add at least one manual verification pass for modal display across multiple dashboard routes and marketplace button loading UX.

## Potential Risks and Gotchas
- Stripe Checkout supports only one coupon or promotion code per session, so referral discounts and admin-managed promotions must remain mutually exclusive in practice.
- Some Stripe coupon or promotion-code attributes may be effectively immutable, so editing an inactive promotion may require remote object replacement instead of in-place mutation.
- Removing the home-page env-backed banner changes public marketing behavior, so home-page controller/spec cleanup must be included in the same change.
- Auto-applying the active promotion from the modal CTA is only safe if it stays subordinate to the referral-discount path and does not create ambiguous session state.
- Stripe promotion-code restrictions and redemptions can diverge from local state if admins edit inactive records repeatedly; the sync service should define when to mutate versus replace remote objects.

## Rollback Plan
- Disable the new ActiveAdmin promotion resource and fall back to no dashboard modal if Stripe sync proves unstable.
- Keep a short-lived compatibility shim only during rollout if needed, but do not preserve the public home-page banner path.
- Revert checkout promotion injection while leaving the admin CRUD and modal data model in place if discount precedence becomes ambiguous in real traffic.

## Remaining Questions
- None. Plan scope is aligned for implementation.

## Execution Summary
- PASS: Added `promotion_codes` persistence, Stripe sync services, ActiveAdmin CRUD, dashboard-wide modal delivery, checkout promotion application, marketplace loading-state alignment, and doc deprecation cleanup.
- PASS: Removed the public home-page discount banner dependency.
- PASS: Verified targeted model, service, admin, dashboard, subscription, and marketplace coverage after preparing the test database serially.
- PASS: Fixed the Stripe promotion-code create payload to use the current `promotion: { type: "coupon", coupon: ... }` API shape, added a direct sync-service regression spec, and covered the admin PATCH flow that backfills missing Stripe IDs.

## Audit Gate
- **Code Pattern and Efficiency**: PASS
  Thin controllers were preserved. Stripe logic lives in dedicated service objects, the dashboard banner is resolved centrally, the marketplace button reuses the shared loading-label behavior instead of adding a second spinner pattern, and the Stripe API fix stays isolated to the sync boundary.
- **Feature Behavior and Goal Alignment**: PASS
  Admins can manage one global active promotion, dashboard routes now share the modal, public home-page banner usage is removed, referral discounts still win, both subscription and one-time checkout flows remain promotion-capable, and admin promotion save/update now matches Stripe's current promotion-code contract.
- **Tests Context**: PASS
  Added targeted specs for the promotion model, admin upsert, dashboard promotion application, admin requests, dashboard rendering, marketplace rendering, subscription checkout precedence, home-page regression coverage, a direct regression spec for the Stripe promotion-code payload shape, and a request-level regression for the failing admin PATCH path.

## Commands Run
- PASS: `sed -n '1,240p' AGENTS.md`
- PASS: `rg -n "DISCOUNT_BANNER_(CODE|PERCENT)|promotion|coupon|stripe|Pay::|pay_customer|dashboard" -S app config db lib spec README.md`
- PASS: `sed -n '1,340p' app/controllers/dashboards_controller.rb`
- PASS: `sed -n '1,220p' app/services/marketing/discount_banner.rb`
- PASS: `sed -n '1,240p' app/views/dashboards/_discount_marketing_modal.html.erb`
- PASS: `sed -n '1,240p' app/javascript/dashboard.js`
- PASS: `sed -n '1,260p' app/views/marketplace/show.html.erb`
- PASS: `sed -n '1,240p' app/javascript/marketplace_show.js`
- PASS: `sed -n '1,220p' app/services/billing/apply_referral_discount.rb`
- PASS: `sed -n '1,220p' /home/loldlm/.agents/skills/rails-expert/references/active-record.md`
- PASS: `sed -n '1,220p' /home/loldlm/.agents/skills/rails-expert/references/rspec-testing.md`
- PASS: `Context7 /websites/stripe query for Checkout discounts, coupons, promotion codes`
- PASS: `Context7 /pay-rails/pay query for Stripe Checkout param passthrough`
- PASS: `rg -n "discount_banner|DISCOUNT_BANNER_CODE|DISCOUNT_BANNER_PERCENT" app/views app/controllers spec README.md config -S`
- PASS: `sed -n '1,220p' app/controllers/pages_controller.rb`
- PASS: `bundle show pay`
- PASS: `bundle exec ruby -c app/models/promotion_code.rb`
- PASS: `bundle exec ruby -c app/services/admin/promotion_code_upsert.rb`
- PASS: `bundle exec ruby -c app/services/admin/promotion_code_activation.rb`
- PASS: `bundle exec ruby -c app/services/billing/stripe_promotion_code_sync.rb`
- PASS: `bundle exec ruby -c app/services/billing/apply_dashboard_promotion.rb`
- PASS: `bundle exec ruby -c app/admin/promotion_codes.rb`
- PASS: `bundle exec rails db:migrate`
- PASS: `bundle exec rspec spec/models/promotion_code_spec.rb spec/services/admin/promotion_code_upsert_spec.rb spec/services/billing/apply_dashboard_promotion_spec.rb spec/services/marketing/discount_banner_spec.rb`
- FAIL: `bundle exec rspec spec/requests/admin_promotion_codes_spec.rb spec/requests/dashboard_spec.rb spec/requests/home_pricing_cta_spec.rb spec/requests/subscription_upgrade_spec.rb spec/requests/marketplace_spec.rb`
- PASS: `RAILS_ENV=test bundle exec rails db:test:prepare`
- PASS: `bundle exec rspec spec/requests/admin_promotion_codes_spec.rb spec/requests/dashboard_spec.rb spec/requests/home_pricing_cta_spec.rb spec/requests/subscription_upgrade_spec.rb spec/requests/marketplace_spec.rb`
- PASS: `sed -n '1,240p' /home/loldlm/.agents/skills/rails-expert/SKILL.md`
- PASS: `sed -n '1,240p' app/services/billing/stripe_promotion_code_sync.rb`
- PASS: `rg -n "Stripe::PromotionCode\\.create|promotion_code_payload|allow_promotion_codes|discounts:|promotion_code:" app spec`
- PASS: `fetch https://docs.stripe.com/api/promotion_codes/create?lang=ruby`
- PASS: `bundle exec rails runner 'promotion = PromotionCode.new(code: "LAUNCH15", percent_off: 15, active: true); service = Billing::StripePromotionCodeSync.new(promotion_code: promotion, replace_remote_objects: true); pp service.send(:promotion_code_payload, "coupon_test")'`
- PASS: `bundle exec rspec spec/services/billing/stripe_promotion_code_sync_spec.rb spec/services/admin/promotion_code_upsert_spec.rb spec/requests/admin_promotion_codes_spec.rb`
