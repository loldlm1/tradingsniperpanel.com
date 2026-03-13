# Plan: Partner Program Simplification

**Generated**: 2026-03-12
**Status**: Implemented, Audit PASS
**Estimated Complexity**: High

## Goal
Replace the current chain-based partner/referral flow with an explicit partner program where only admin-enabled partners can issue a unique referral discount code and receive profit-share commissions, while preserving a clean admin workflow and a stronger Mosaic-based partner dashboard.

## Confirmed Decisions
- Partner enablement will live in `PartnerProfile`, not `User.role`; most users remain `trader`.
- Both `admin` and `master_admin` should be able to manage partner CRUD.
- Referral attribution code and Stripe promo code should be separate concepts.
- `PartnerProfile` should support a manually set public referral code, but generate a unique code automatically when blank.
- Customer discount percent and partner commission/profit-share percent are separate fields.
- The partner dashboard should show only direct referrals, with pagination and email search.
- Payout requests should create a persistent record and notify admins by email with the requesting user/context.
- If a partner public referral code changes, the old code should stop working immediately.
- Existing general dashboard promo-code behavior stays as-is; referral-driven discounts continue to take precedence at checkout because Stripe allows only one discount path.
- Payout email sending should stay asynchronous via job queue, but duplicate clicks/jobs must be prevented and failed notification attempts must allow the request flow to recover.
- Failed payout email delivery can be handled on the next page load/revisit; no Turbo/live in-page recovery is required.
- This is still dev-mode data, so the migration path should prefer the simplest safe rollout over heavy legacy normalization.

## Definition of Done
- Chain-based partner assignment is removed from checkout and commission generation for new traffic.
- Partner eligibility is explicit and admin-managed, not inferred from downstream referral chains.
- Each active partner has one unique public referral code and one commission configuration.
- Referred users do not automatically become commission-sharing partners.
- ActiveAdmin exposes the required CRUD and activation/deactivation workflow for partner management.
- The dashboard partner area is rebuilt with Mosaic-compatible sections/components and reflects the simplified rules.
- Payout requests enforce a minimum requestable balance of `$200`, create an auditable record, and notify configured internal email recipients.
- Relevant request/model/service/mailer specs cover the new behavior and legacy risks are documented.

## Current State Findings
- `PartnerMembership` and `Partners::MembershipManager` are the core of the chain logic today: upstream partner lookup walks the `Refer` tree and stores `depth`.
- `Referrals::AttachReferrer` currently gives referred users their own referral code and immediately assigns partner membership.
- Checkout discounts come from `Billing::ApplyReferralDiscount`, which resolves the discount from the referrer/active membership path.
- Commissions are built asynchronously from `Pay::Charge` via `Partners::CommissionBuilder`, which depends on the active membership and `discount_percent`.
- Dashboard access currently depends on `current_user.partner?` plus an active `partner_profile`.
- ActiveAdmin role changes are currently restricted: `admin` users cannot change roles, `master_admin` can.
- Current payout requests only batch DB records; no threshold or email notification exists.

## Constraints
- Follow repo guidance: thin controllers, business logic in POROs/services, I18n-first copy, no inline scripts/styles in views.
- Reuse existing `Refer`, `Pay`, Stripe, and ActiveAdmin patterns where practical; avoid inventing a second discount system unless required.
- Keep dashboard UI aligned with Mosaic source patterns from `docs/cruip_template_guide.md`.
- Preserve historical commission and payout records even if new partner assignment rules change.
- Prefer additive migrations with explicit backfill/cleanup steps over destructive data rewrites.
- Keep partner access checks tied to active `PartnerProfile` state rather than `user.role == partner`.

## Proposed Shape
- Keep `PartnerProfile` as the explicit partner program record, but refactor it to represent partner status/configuration instead of chain membership ownership.
- Introduce explicit partner referral configuration on `PartnerProfile` or a closely-related model:
  - unique public referral code
  - discount percent
  - commission percent / profit-share percent
  - active/inactive state
- Keep the existing non-referral promo-code system unchanged; checkout should continue prioritizing referral discounts over general promo-code entry when a user was referred.
- Stop auto-creating commission eligibility for referred users. Referral attachment should link the user to a referring partner, but not turn them into a commission source for their own downstream tree unless an admin explicitly enables them later.
- Replace chain-driven membership resolution with direct attribution from the referring partner only. New logic should not traverse upstream branches or use `depth`.
- Keep referred-user listings direct-only and paginated/searchable by email to control dashboard load.
- Keep payout requests as first-class records, but gate creation at the service layer with minimum-balance checks, deduplicated email-notification jobs, and recoverable notification failure handling.

## Phases

### Phase 1: Domain and data-model refactor
**Goal**: Move from chain-derived partner behavior to explicit partner eligibility.
**Demo/Validation**:
- A non-partner referred signup gets linked to a partner without gaining partner privileges.
- A configured partner has one active public referral code and a clear commission configuration.

#### Task 1.1: Audit legacy partner tables and map migration path
- **Location**: `db/schema.rb`, `app/models/partner_*.rb`, `app/services/partners/*.rb`
- **Description**: Decide which current fields survive, which become legacy-only, and whether `PartnerMembership` remains for attribution only or is replaced for new records.
- **Dependencies**: none
- **Acceptance Criteria**:
  - Legacy vs future-use fields are identified.
  - Backfill and data-preservation strategy is defined before schema work.
- **Validation**:
  - Review plan against existing seed/spec coverage.

#### Task 1.2: Define the explicit partner configuration model
- **Location**: likely `app/models/partner_profile.rb`, migration(s), optional new model under `app/models`
- **Description**: Model active partner state, optional manual public referral code with automatic generation fallback, customer discount percent, and commission percent with validations and indexes.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Exactly one active shareable code per partner.
  - Changing a partner public referral code invalidates the old code immediately.
  - Admins can enable/disable partner status without relying on referral depth.
  - Partner access no longer depends on `User.role`.
- **Validation**:
  - Model specs for uniqueness, activation, and numeric constraints.

#### Task 1.3: Refactor referral attachment flow
- **Location**: `app/services/referrals/attach_referrer.rb`, user callbacks, signup entry points
- **Description**: Attach a referred user to the direct partner/referrer for attribution while removing automatic downstream partner-code creation for ordinary referred users.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Referred traders do not become partner-enabled by default.
  - Existing signup and OAuth flows still attach the direct referrer correctly.
- **Validation**:
  - Request/service specs for registration + OAuth referral flows.

### Phase 2: Discount and commission engine simplification
**Goal**: Make checkout discounting and commission creation rely on explicit partner config.
**Demo/Validation**:
- Checkout uses the partner’s referral attribution and generated referral discount safely.
- Charges for referred users create commissions only for the explicitly enabled partner.

#### Task 2.1: Refactor discount resolution
- **Location**: `app/services/billing/apply_referral_discount.rb`, `app/services/partners/discount_resolver.rb`, `app/services/partners/referral_coupon.rb`
- **Description**: Resolve discounts from the explicit partner configuration instead of active chain membership. Keep the public referral code separate from the existing promo-code system, and preserve the current behavior where referral discounts win when both paths would otherwise compete.
- **Dependencies**: Phase 1 complete
- **Acceptance Criteria**:
  - Discount metadata reflects the explicit partner config.
  - No dependency on `PartnerMembership.active.find_by(user:)` for checkout discounting.
  - Existing non-referral promo-code management remains unchanged.
- **Validation**:
  - Service/request specs for checkout params and Stripe payload behavior.

#### Task 2.2: Refactor commission attribution
- **Location**: `app/services/partners/commission_builder.rb`, `app/jobs/partners/build_commissions_job.rb`, related models
- **Description**: Attribute commissions to the direct partner that referred the paying user, using explicit config and the dedicated commission percent source.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - No chain traversal for new commissions.
  - Commission percent is independent from customer discount percent.
  - Historical once/renewal behavior is intentionally preserved or intentionally removed by decision.
- **Validation**:
  - Service specs covering initial and renewal charges, duplicate prevention, inactive partner handling.

#### Task 2.3: Decide and implement legacy data compatibility
- **Location**: migration(s), backfill task/job if needed
- **Description**: Preserve old commission history while ensuring new records use the simplified attribution path.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Historical dashboards/admin records remain readable.
  - Mixed legacy/new data does not break queries.
- **Validation**:
  - Seed/spec coverage or migration verification script.

### Phase 3: ActiveAdmin partner management
**Goal**: Give internal admins a clear CRUD surface to manage partners and payouts.
**Demo/Validation**:
- Internal staff can create/activate/deactivate a partner record and view linked payout requests.

#### Task 3.1: Add partner management resource(s)
- **Location**: likely `app/admin/partner_profiles.rb` and/or related admin services
- **Description**: Add ActiveAdmin CRUD for partner configuration, including activation state, referral code overrides, discount/commission settings, and linked Stripe identifiers where needed.
- **Dependencies**: Phase 1 model shape complete
- **Acceptance Criteria**:
  - The admin form is explicit about partner status and shareable code.
  - Admin pages reflect the new rule that both `admin` and `master_admin` can manage partners.
- **Validation**:
  - Request specs for admin CRUD and visibility.

#### Task 3.2: Resolve admin permission policy
- **Location**: `app/services/admin/users/role_guard.rb`, admin resource(s), possibly `app/admin/users.rb`
- **Description**: Adjust permissioning so both `admin` and `master_admin` can enable partner status and create/update partner records, without unintentionally broadening unrelated role-edit capabilities.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Partner CRUD permissions match the agreed product policy.
  - Existing role restrictions remain intentional and tested.
- **Validation**:
  - Request/spec coverage for allowed and blocked actions.

#### Task 3.3: Add admin payout workflow visibility
- **Location**: existing payout admin files plus new partner admin screens
- **Description**: Surface requestable balance, pending requests, and payout history so staff can reconcile partner payments.
- **Dependencies**: Phase 4 service behavior
- **Acceptance Criteria**:
  - Staff can see when a request email was created and what commissions were bundled.
- **Validation**:
  - Request specs and manual admin review.

### Phase 4: Payout request thresholds and notifications
**Goal**: Turn the payout button into a controlled request workflow.
**Demo/Validation**:
- Partners below `$200` cannot request payout.
- Eligible partners create a request record and trigger an internal email.

#### Task 4.1: Enforce minimum payout threshold
- **Location**: `app/services/partners/payout_requestor.rb`, `app/models/partner_payout_request.rb`, controller/UI
- **Description**: Enforce a minimum requestable balance of `$200`, prevent duplicate pending requests, and ensure the request flow cannot enqueue duplicate notification jobs from repeated clicks.
- **Dependencies**: Phase 2 complete
- **Acceptance Criteria**:
  - Button is disabled or clearly explained below threshold.
  - Service rejects duplicate/ineligible requests safely.
  - A second request cannot be created while one is still pending.
- **Validation**:
  - Service/request specs for threshold and pending-state behavior.

#### Task 4.2: Add payout request mailer + delivery config
- **Location**: new mailer/views, environment config, controller/service integration
- **Description**: Send a payout request notification to configured internal recipients from an env-backed distribution list using a deduplicated background job tied to the payout request record.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Email recipients are environment-driven.
  - Email includes partner identity, requesting user identity, requested amount, and traceable IDs.
  - The button flow creates at most one request/job per payout attempt.
  - Notification success/failure is persisted on the request so the UI/admin can react safely.
- **Validation**:
  - Mailer specs and request/service specs asserting enqueue/send.

#### Task 4.3: Add notification-delivery state tracking
- **Location**: `app/models/partner_payout_request.rb`, migration(s), job/service/UI wiring
- **Description**: Track queued/sent/failed notification state on payout requests so repeated clicks are blocked and failed sends can re-enable the workflow safely.
- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - One click creates one request and one notification job.
  - Failed notification attempts leave a recoverable state instead of silently trapping the partner.
  - Admins can see whether the payout request email was sent or failed.
- **Validation**:
  - Model/service/request specs for job deduplication and failure recovery.

### Phase 5: Dashboard partner UX rebuild
**Goal**: Reframe the partner dashboard around the simplified program rules.
**Demo/Validation**:
- The partner dashboard communicates code sharing, earnings, threshold progress, and request state clearly.

#### Task 5.1: Redesign partner dashboard sections with Mosaic patterns
- **Location**: `app/views/dashboard/partner/show.html.erb`, partials, styles/JS helpers
- **Description**: Replace the current generic layout with Mosaic-derived sections for overview, code sharing, requestability, earnings history, a paginated direct-referrals table searchable by email, and payout request state feedback.
- **Dependencies**: Phases 2 and 4
- **Acceptance Criteria**:
  - No inline script in the view; chart/config data moves to view-safe hooks.
  - UI communicates the simplified rules, not branch/depth language.
  - Direct-referral queries are paginated and indexed appropriately for email search.
- **Validation**:
  - View/request specs and browser smoke check.

#### Task 5.2: Align copy and localization
- **Location**: `config/locales/en.yml`, `config/locales/es.yml`, dashboard/admin locale files
- **Description**: Replace outdated chain/referral wording with explicit partner-program language in EN/ES.
- **Dependencies**: Task 5.1
- **Acceptance Criteria**:
  - No new hardcoded strings in partner/admin UI.
- **Validation**:
  - Spec assertions using I18n keys where reasonable.

## Testing Strategy
- Model specs: partner configuration validations, activation rules, payout request state rules.
- Service specs: referral attachment, discount resolution, commission creation, payout request threshold/email flow.
- Request specs: signup referral path, checkout path, dashboard partner actions, ActiveAdmin partner CRUD/permissions.
- Optional system/browser smoke: partner dashboard layout and payout button state after UI rebuild.
- Job-flow validation: verify repeated clicks do not create duplicate jobs/records and verify failure-state recovery.

## Risks and Gotchas
- Current role model (`user.role == partner`) is coupled to dashboard access and automatic profile/referral-code callbacks; moving enablement into `PartnerProfile` requires a deliberate uncoupling pass.
- Current commission percent uses `discount_percent`; if discount and profit-share become separate values, existing naming and historical metadata need cleanup.
- Legacy `PartnerMembership`/`depth` data is embedded in dashboard queries and specs; dropping it outright is riskier than isolating it and phasing it out.
- Referral discounts still depend on Stripe coupon objects under the hood, so code changes and cache invalidation need to avoid stale coupon reuse.
- Payout requests need idempotency rules and delivery-state tracking so repeated button presses do not create duplicate emails/requests.

## Rollback Plan
- Keep migrations additive and reversible.
- Preserve legacy partner records and historical commissions even if new flows stop reading them.
- Gate new partner resolution behind a service boundary so the app can temporarily fall back to legacy resolution if a production issue appears.

## Implementation Decisions
- Kept `PartnerMembership` as a direct-attribution snapshot (`depth = 1`) for backward compatibility with `PartnerCommission` instead of doing a destructive commission-table rewrite.
- Moved partner access checks to active `PartnerProfile` state and left `User.role` intact for unrelated authorization paths.
- Added explicit `referral_code` and `commission_percent` fields to `PartnerProfile`; referral code syncs to the `refer` gem record and old codes stop working immediately when changed.
- Added notification delivery tracking to `PartnerPayoutRequest` so one click creates one request/job, failed notifications are recoverable on the next reload, and admin can see send state.
- Kept the existing generic dashboard promo-code system unchanged; referral discounts still win first at checkout.

## Open Questions
- None. The plan is aligned and ready for implementation.

## Commands Run
- PASS: inspected `AGENTS.md`
- PASS: inspected current partner/referral models, services, jobs, routes, admin resources, locales, seeds, and relevant docs
- PASS: checked official docs for ActiveAdmin custom resources/actions and Stripe promotion-code behavior
- PASS: clarified partner enablement, code ownership, payout deduplication, and reload-based failure UX with the user
- PASS: implemented schema changes via `bin/rails db:migrate`
- PASS: corrected `partner_payout_requests.notification_status` default to `queued`
- PASS: ran focused partner/admin/dashboard specs
- PASS: ran seed/sidebar/admin regression specs

## Audit Gate
- PASS: code pattern and efficiency
- PASS: feature behavior and goal alignment
- PASS: tests context
