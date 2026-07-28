# Plan: Chu Sniper Trailing Subscription Product

**Generated**: 2026-07-27
**Status**: Planning only; implementation not started
**Estimated Complexity**: High

## Overview

Add Chu Sniper Trailing as the lowest paid subscription product while keeping
Pandora Box as the higher tier. Both products remain first-class, recurring
Stripe products with their own monthly and annual prices. Chu customers receive
the Chu Sniper Trailing EA/tool and Discord VIP. Pandora customers retain their
Pandora Box EA and additionally receive Chu Sniper Trailing and Discord VIP.

The current application is intentionally Pandora-only in several layers: the
seed reconciler retires every other plan and EA, the purchasable scope accepts
only Pandora keys, pricing and dashboard views render one card, Discord checks
the Pandora tier, and subscription comparison uses raw charge amounts. The
implementation must introduce an authoritative multi-product catalog and then
adapt those boundaries without changing the public v1 licensing JSON contract.

No database migration is expected. Existing `billing_plans`,
`billing_plan_prices`, entitlement, license, Active Storage, manual billing,
and Discord tables can represent the additive product. A targeted, idempotent
backfill is required for current Pandora subscribers so they receive a Chu
license without regenerating or invalidating their existing Pandora key.

## Product Contract

| Product | Canonical tier | Plan keys | Monthly | Annual | Includes |
| --- | --- | --- | ---: | ---: | --- |
| Chu Sniper Trailing | `chu_sniper_trailing` | `chu_sniper_trailing_monthly`, `chu_sniper_trailing_annual` | `1,999` cents (`$19.99`) | `15,592` cents (`$155.92`) | Chu Sniper Trailing EA/tool, Discord VIP |
| Pandora Box | `pandora_pro` (unchanged) | `pandora_pro_monthly`, `pandora_pro_annual` | `7,900` cents (`$79.00`) | `61,620` cents (`$616.20`) | Pandora Box EA, Chu Sniper Trailing EA/tool, Discord VIP |

The confirmed annual convention is the existing 35% discount:
`1,999 * 12 * 65 / 100 = 15,592` cents using the same integer-cent arithmetic
as Pandora. The effective monthly display is `$12.99` using the current
integer-safe formatting.

Chu's MQL product identity is fixed to `ea_id=chu_sniper_trailing`, display name
`Chu Sniper Trailing`, `ea_type=ea_tool`, no required add-ons, trials disabled,
license verify and heartbeat enabled, instance magic supported, and daily
results reporting disabled. Runtime magic remains backend-issued and
signed-32-bit-safe. The existing asset
`docs_eas/chu_sniper_trailing/Chu_Sniper_Trailing.zip` is user-owned input and
must not be overwritten, regenerated, or purged.

## Scope

- **In scope**: authoritative pricing/catalog definitions; two Stripe product
  identities and four prices; two EA records and six EA entitlements; Chu
  guide and bundle seeding; current-Pandora Chu-license backfill; Stripe and
  manual subscription transitions; Discord VIP eligibility; explicit online
  seat caps; Mosaic dashboard and Neon pricing; EN/ES copy; admin/audit views;
  deployment verification, staging rehearsal, and rollback documentation.
- **Out of scope**: changes to Chu trading behavior, MQL strategy/risk logic,
  MetaEditor source edits, daily-results support, new add-ons, trial
  provisioning, a new API version, a new payment processor, Fintech template
  redesign, or a schema migration unless implementation discovery proves one
  unavoidable.
- **Fixed decisions**: price Chu at `$19.99` monthly and `$155.92` annually;
  preserve Pandora's existing tier/key/product/price identifiers and amounts;
  use a separate Chu Stripe product; keep the same
  configured Discord VIP role for both tiers; keep the existing v1 license API
  request/response shapes and error codes; keep normal license ownership and
  server-authoritative entitlement checks.
- **Assumptions**: both tiers have an explicit five-seat subscription cap (the
  current Pandora cap must not rise merely because a lower tier is added); the
  Chu EA has no trial; and
  `chu_sniper_trailing` is the canonical Rails tier as well as the MQL EA id.

## Named Resources

- **Project instructions**: `AGENTS.md`, `README.md`,
  `docs/database_model_reference.md`,
  `docs/pandora_subscription_rollout_runbook.md`, and
  `docs/discord_vip_rollout_runbook.md`.
- **MQL context (read-only during Rails work)**:
  `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/AGENTS.md`,
  `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/README.md`,
  `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/chu_sniper_license_service_setup.mqh`,
  and
  `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/shared/license_guard_v1/backend-entitlements-contract.md`.
- **New contract/documentation files**:
  `docs/chu_sniper_trailing_backend_contract.md`,
  `docs/chu_sniper_trailing_subscription_rollout_runbook.md`,
  `docs_eas/chu_sniper_trailing/chu_sniper_trailing_guide_en.md`, and
  `docs_eas/chu_sniper_trailing/chu_sniper_trailing_guide_es.md`.
- **Catalog and seed files**:
  `app/services/billing/chu_sniper_pricing.rb`,
  `app/services/billing/subscription_catalog.rb`,
  `app/models/billing_plan.rb`,
  `app/services/billing/pricing_catalog.rb`,
  `app/services/billing/plan_creator.rb`,
  `app/services/billing/subscription_catalog_reconciler.rb`,
  `app/services/billing/pandora_catalog_reconciler.rb` (compatibility entry
  point),
  `app/services/catalog/retire_legacy_access.rb`,
  `db/seeds/shared.rb`, `db/seeds/runner.rb`, and `lib/tasks/catalog.rake`.
- **Billing/runtime files**:
  `app/services/billing/plan_comparator.rb`,
  `app/services/billing/plan_change.rb`,
  `app/services/billing/dashboard_plan.rb`,
  `app/services/billing/subscription_plan_resolver.rb`,
  `app/services/billing/price_key_resolver.rb`,
  `app/services/billing/invoice_plan_labeler.rb`,
  `app/controllers/dashboards_controller.rb`,
  `app/services/manual_subscriptions/grant.rb`,
  `app/admin/manual_subscriptions.rb`,
  `app/services/licenses/subscription_license_sync.rb`,
  `app/services/licenses/manual_subscription_sync.rb`,
  `app/services/licenses/online_seat_limits.rb`,
  `app/services/licenses/online_seat_copy.rb`,
  `app/services/discord/vip_eligibility.rb`, and
  `app/services/admin/subscription_audits/query.rb`.
- **Licensing backfill files**:
  `app/services/licenses/backfill_chu_subscription_licenses.rb`, an
  idempotent `licenses:backfill_chu_subscription_licenses` task in
  `lib/tasks/licenses.rake`, and the corresponding service/task specs.
- **User-facing files**:
  `app/views/dashboards/plans.html.erb`,
  `app/views/dashboards/billing.html.erb`,
  `app/views/dashboards/shared/_discord_vip_card.html.erb`,
  `app/views/templates/neon/pages/home.html.erb`,
  `app/services/marketing/neon_landing_pricing.rb`,
  `config/locales/dashboard.en.yml`, `config/locales/dashboard.es.yml`,
  `config/locales/en.yml`, `config/locales/es.yml`,
  `config/locales/active_admin.en.yml`, and
  `config/locales/active_admin.es.yml`.
- **Tests and validation**: the existing Pandora/catalog, subscription-change,
  licensing API, Discord, ActiveAdmin, dashboard, marketing, seed, and
  accessibility/request specs listed in the sprint sections below, plus
  `bin/rails zeitwerk:check`, `npm run build:css`, RuboCop/Brakeman, and the
  focused browser QA harness.
- **Official Stripe references**:
  `https://docs.stripe.com/products-prices/manage-prices`,
  `https://docs.stripe.com/billing/subscriptions/upgrade-downgrade`, and
  `https://docs.stripe.com/billing/subscriptions/subscription-schedules/use-cases`.
- **Operational resources**: Stripe test/live products and prices, Pay webhook
  delivery, Sidekiq/cron, Active Storage, staging backups, and the deploy hook
  in `script/setup_common.sh`.

## Prerequisites

- Preserve the confirmed 35% Chu annual discount during Stripe price creation;
  calculate it with integer cents and never floating-point arithmetic.
- Snapshot the existing Pandora Stripe product/price ids, active subscriptions,
  manual grants, license ids, and safe schedule metadata. Do not export keys,
  secrets, or raw customer payloads.
- Verify the Chu ZIP checksum and that the Rails process can read the existing
  Active Storage source path. Add guides without changing the ZIP.
- Have Stripe test-mode access, a staging database backup/restore path, seeded
  EN/ES QA users, Discord test configuration, and a Sidekiq worker available.
- Before implementation starts, read
  `/home/loldlm/.codex/skills/planner/references/execution-state.md`; initialize
  ordered plan state only after the user separately authorizes execution.

## Sprint 1: Establish The Multi-Product Catalog

**Goal**: Rails can seed and verify two independent subscription products, two
active EAs, four complete plans, and the six intended EA entitlements without
retiring Chu or changing Pandora's existing Stripe identity.

**Dependencies**: Prerequisites above; no code from later sprints.

**Tracked scope**: `docs/chu_sniper_trailing_backend_contract.md`,
`app/services/billing/chu_sniper_pricing.rb`,
`app/services/billing/subscription_catalog.rb`, seed/catalog/reconciler files,
Chu guide files, and catalog specs.

**Commit**: `feat(catalog): add Chu Sniper Trailing subscription contract`

**Demo/Validation**:

- Run the local seed profile twice and assert four active plan rows, two Stripe
  product ids, two active EAs, and six exact plan-EA entitlement rows.
- Run `bin/rails catalog:subscriptions:verify` in test/staging mode and verify
  that the legacy `catalog:pandora:verify` compatibility task reaches the same
  verifier.
- Run the focused catalog/seed specs and `bin/rails zeitwerk:check`.

**Rollback point**: Revert the Sprint 1 commit and restore the captured local
catalog snapshot. Never run the old Pandora-only retirement against a database
that contains live Chu customers; deactivate new Stripe prices/products rather
than deleting them.

### Task 1.1: Write The Backend Contract And Product Matrix

- **Location**: `docs/chu_sniper_trailing_backend_contract.md`,
  `docs/database_model_reference.md`.
- **Description**: Document canonical ids, exact cents and interval fields,
  integer annual calculation, separate Stripe products, the six-row
  entitlement matrix, access rank, five-seat caps, shared Discord role,
  no-trial/no-add-on/daily-results rules, license endpoints, backfill rules,
  and the unchanged v1 JSON/error contracts. Update the model reference only
  with verified persisted behavior.
- **Dependencies**: Product Contract in this plan and MQL contract files.
- **Acceptance criteria**:
  - The table names all four plan keys and both product ids without exposing
    secrets or customer data.
  - The matrix explicitly shows Chu -> Chu, and Pandora -> Pandora + Chu.
  - The document states that Discord never grants Rails entitlement and that
    backend-issued magic numbers remain signed-32-bit-safe.
- **Validation**:
  - `git diff --check`.
  - Review every referenced path and compare the API section with the existing
    request specs and MQL backend contract.
- **Rollback**: Revert the documentation portion only; no runtime data change.

### Task 1.2: Add Authoritative Pricing And Catalog Metadata

- **Location**: `app/services/billing/chu_sniper_pricing.rb`,
  `app/services/billing/pandora_pricing.rb`,
  `app/services/billing/subscription_catalog.rb`,
  `app/models/billing_plan.rb`, `app/services/billing/pricing_catalog.rb`.
- **Description**: Keep `Billing::PandoraPricing` values stable and add
  `Billing::ChuSniperPricing`. Build a small catalog that owns product key,
  tier, exact plan definitions, Stripe product name, access rank, explicit seat
  cap, VIP eligibility, EA ids, complete-product checks, and robust plan-key
  parsing. Make `BillingPlan.purchasable`, tier ordering, pricing completeness,
  and cache signatures use this catalog. A product with one missing interval
  must not hide a complete product from customer-facing pricing, while an
  incomplete product must not expose a partial checkout option.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - Chu constants produce `1999` monthly and `15592` annual cents using integer
    arithmetic; Pandora constants and keys remain unchanged.
  - Only complete canonical product pairs are purchasable; one-time and stale
    rows remain excluded.
  - Known multi-underscore tiers resolve without the current first-token
    parsing bug; unknown legacy keys retain a safe fallback.
  - Catalog ordering makes Chu lower than Pandora for transitions and display,
    independently of raw price amounts.
- **Validation**:
  - Add/run `spec/services/billing/chu_sniper_pricing_spec.rb`,
    `spec/services/billing/subscription_catalog_spec.rb`,
    `spec/services/billing/pandora_pricing_spec.rb`,
    `spec/models/billing_plan_spec.rb`, and
    `spec/services/billing/pricing_catalog_spec.rb`.
  - Run `bin/rails zeitwerk:check`.
- **Rollback**: Remove the new catalog constants while retaining the Pandora
  compatibility module; no Stripe rows are deleted.

### Task 1.3: Seed The Chu EA, Guides, And Existing Bundle

- **Location**: `db/seeds/shared.rb`,
  `docs_eas/chu_sniper_trailing/chu_sniper_trailing_guide_en.md`,
  `docs_eas/chu_sniper_trailing/chu_sniper_trailing_guide_es.md`, and the
  existing `docs_eas/chu_sniper_trailing/Chu_Sniper_Trailing.zip`.
- **Description**: Add Chu to every core/profile definition and prune list with
  `ea_id=chu_sniper_trailing`, `ea_type=ea_tool`, trials disabled, no required
  add-ons, and allowed tiers `[chu_sniper_trailing, pandora_pro]`. Keep Pandora
  allowed only for `pandora_pro`. Add guide path mappings and a bundle path
  lookup that attaches the existing ZIP with a deterministic Chu filename and
  checksum-aware no-op behavior. Do not edit or recreate the archive.
- **Dependencies**: Task 1.2 and the read-only MQL guide.
- **Acceptance criteria**:
  - Both EN and ES guides describe chart-scoped position management, trailing
    controls, broker protection caveats, licensing, and safe use without
    inventing unsupported strategy features.
  - Re-running seeds does not purge/re-attach an unchanged Chu ZIP.
  - No unrelated EA is reactivated and no old guide fallback is used for Chu.
- **Validation**:
  - `bundle exec rspec spec/seeds/runner_spec.rb spec/requests/expert_advisors_spec.rb spec/services/licenses/accessible_expert_advisors_spec.rb`.
  - Inspect Active Storage attachment checksum/filename in a local seed run.
- **Rollback**: Mark the Chu EA inactive and hide its product; retain the ZIP
  and guides for a forward-compatible retry.

### Task 1.4: Generalize Stripe Seeding, Entitlements, And Retirement

- **Location**: `db/seeds/shared.rb`,
  `app/services/billing/plan_creator.rb`,
  `app/services/billing/subscription_catalog_reconciler.rb`,
  `app/services/billing/pandora_catalog_reconciler.rb`,
  `app/services/catalog/retire_legacy_access.rb`, `db/seeds/runner.rb`, and
  `lib/tasks/catalog.rake`.
- **Description**: Seed monthly and annual plans grouped by product so each
  pair shares one Stripe product and Chu never reuses Pandora's product. Keep
  `Billing::PandoraCatalogReconciler` as a compatibility facade if a new
  multi-product reconciler is extracted. Generalize retirement to accept
  desired plans and desired EAs (not a single Pandora EA), preserve financial
  price history, and retain exactly the two core EAs and six entitlements while
  retiring unrelated legacy access as before. Add
  `catalog:subscriptions:verify` and keep `catalog:pandora:verify` as an alias.
- **Dependencies**: Tasks 1.2 and 1.3.
- **Acceptance criteria**:
  - Remote mode creates/reuses exactly two named products and four matching
    prices with idempotency keys; existing Pandora ids are not replaced.
  - Local/test mode preserves `seed_product_pandora_box` and uses the distinct
    `seed_product_chu_sniper_trailing` id for Chu.
  - Final verification rejects wrong amount, currency, interval, product
    association, stale price history, missing entitlements, or unexpected
    active EAs/plans.
  - Legacy renewal migration still targets interval-matched Pandora plans and
    does not move existing Pandora subscribers to Chu.
- **Validation**:
  - Add/run `spec/services/billing/subscription_catalog_reconciler_spec.rb`
    (or the generalized replacement),
    `spec/services/billing/plan_creator_spec.rb`,
    `spec/services/billing/pandora_catalog_reconciler_spec.rb`,
    `spec/services/catalog/retire_legacy_access_spec.rb`,
    `spec/services/billing/legacy_subscription_migrator_spec.rb`, and
    `spec/seeds/runner_spec.rb`.
  - Run `bin/rails db:seed` twice in a disposable test database and compare
    stable product/price/entitlement counts.
- **Rollback**: Stop the new seed task before deploy rollback; deactivate only
  Chu Stripe prices/product and leave existing Pandora schedules and history
  untouched. Do not invoke a pre-change Pandora-only retirement routine.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] Focused catalog, seed, and autoloading validation passes and evidence is
  recorded.
- [ ] Residual Stripe/product and annual-rounding risks are documented.
- [ ] Exactly one Sprint 1 commit is created with the proposed message.
- [ ] The catalog/Stripe rollback point is recorded.
- [ ] Sprint 2 has not started before this gate completes.

## Sprint 2: Entitlements, Licensing, Seats, And VIP Eligibility

**Goal**: New and existing paid access produces the correct EA licenses and
Discord eligibility while preserving API contracts, existing Pandora keys, and
explicit five-seat limits.

**Dependencies**: Sprint 1 gate; Chu EA and six entitlements exist locally.

**Tracked scope**: license sync/backfill, online-seat services, Discord
eligibility, admin audit query, API regression tests, and related jobs/tasks.

**Commit**: `feat(licensing): grant Chu entitlements to Pandora subscribers`

**Demo/Validation**:

- Seed a Pandora subscriber and a Chu subscriber, verify their license counts,
  EA ids, intervals, expiry, and access source.
- Run the targeted backfill twice and show identical counts and an unchanged
  Pandora encrypted key.
- Exercise Chu `verify`, `heartbeat`, and `instance_magic` requests and compare
  response/error shapes with Pandora fixtures.
- Run Discord eligibility and online-seat specs for both tiers and a wrong-tier
  account.

**Rollback point**: Disable Chu checkout and VIP sync, but keep the Chu backend
  resolver and license records deployed. Existing licenses should expire by
  their authoritative period; do not bulk-revoke them or rotate Pandora keys.

### Task 2.1: Apply The Entitlement Matrix To License Sync

- **Location**: `app/services/licenses/subscription_license_sync.rb`,
  `app/services/licenses/manual_subscription_sync.rb`,
  `app/models/expert_advisor.rb`, and related specs.
- **Description**: Resolve a canonical plan through `SubscriptionCatalog`, then
  select EA entitlements from the matrix rather than Pandora constants. Chu
  access must issue only Chu; Pandora access must issue both; scheduled
  Pandora-to-Chu changes must expire Pandora only after the effective period.
  Preserve one-time access precedence, referral completion, token-version
  behavior, and secure logging.
- **Dependencies**: Sprint 1 Task 1.4.
- **Acceptance criteria**:
  - Active Chu and Pandora Stripe/manual subscriptions produce the exact EA set
    in the contract.
  - A plan change never grants an EA merely because a browser or EA supplied a
    tier string; current server records remain authoritative.
  - Existing unsupported/legacy price mappings fail safely and do not expose
    a license.
- **Validation**:
  - `bundle exec rspec spec/services/licenses/subscription_license_sync_spec.rb spec/services/licenses/manual_subscription_sync_spec.rb spec/models/expert_advisor_spec.rb`.
  - Include assertions for license status, expiry, source, and interval. Keep
    the existing renewal key-reissue behavior; Pandora key preservation for the
    migration itself is covered only by Task 2.2.
- **Rollback**: Disable new plan issuance while retaining the old license rows;
  restore only code paths that can still resolve Chu records.

### Task 2.2: Add An Idempotent Chu-License Backfill

- **Location**: `app/services/licenses/backfill_chu_subscription_licenses.rb`,
  the operator-facing `licenses:backfill_chu_subscription_licenses` task in
  `lib/tasks/licenses.rake`, and corresponding specs/runbook steps.
- **Description**: Enumerate users with an active Pandora Stripe subscription or
  active Pandora manual grant, lock one user/Chu EA at a time, and create or
  repair only the Chu subscription license with the current interval and
  authoritative expiry. Skip active one-time Chu access, preserve existing Chu
  keys when already correct, and never call the ordinary all-EA sync for this
  migration. Expose dry-run counts, batch boundaries, and safe progress logs.
- **Dependencies**: Task 2.1 and the seeded Chu EA.
- **Acceptance criteria**:
  - A current Pandora user gets one Chu license; a Chu-only user is untouched;
    expired/cancelled users are not granted access.
  - Re-running the operation is a no-op for correct rows.
  - The pre-existing Pandora license id, encrypted key, token version, and
    last-rotation metadata remain unchanged.
  - Partial failure is retryable per user and does not leave a half-written
    license or disclose a key.
- **Validation**:
  - Add/run `spec/services/licenses/backfill_chu_subscription_licenses_spec.rb`
    with Stripe and manual fixtures, including rerun and failure recovery.
  - Run the dry-run and apply modes against a disposable seeded database and
    compare before/after license fingerprints (never raw keys).
- **Rollback**: Revoke only newly created Chu licenses with an audited,
  user-scoped operation if required; do not touch Pandora licenses or delete
  the EA record.

### Task 2.3: Make Seat Caps Explicit And Stable

- **Location**: `app/services/billing/subscription_catalog.rb`,
  `app/services/licenses/online_seat_limits.rb`,
  `app/services/licenses/online_seat_copy.rb`,
  `app/services/licenses/online_seat_allocator.rb`, and specs.
- **Description**: Replace implicit `BASE + tier index` behavior for canonical
  plans with catalog seat caps: five for Chu and five for Pandora. Preserve the
  current shared subscription-session semantics across EA ids, the one-time
  per-EA cap, locking, TTL, and rate-limit behavior. Leave a documented
  fallback for unknown legacy tiers.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - Adding Chu does not change Pandora's cap from five.
  - Copy shown in EN/ES matches the actual cap.
  - Concurrent verify requests cannot exceed the configured cap.
- **Validation**:
  - `bundle exec rspec spec/services/licenses/online_seat_limits_spec.rb spec/services/licenses/online_seat_copy_spec.rb spec/services/licenses/online_seat_allocator_spec.rb spec/requests/api/licenses_verify_spec.rb`.
- **Rollback**: Restore the previous cap resolver only for a controlled
  compatibility window; do not change active sessions or delete rows.

### Task 2.4: Generalize Discord VIP And Subscription Audit Eligibility

- **Location**: `app/services/discord/vip_eligibility.rb`,
  `app/jobs/discord/reconcile_vip_roles_job.rb`, `lib/tasks/discord.rake`,
  `app/services/admin/subscription_audits/query.rb`, and relevant specs.
- **Description**: Resolve VIP eligibility from the catalog's `vip_eligible`
  flag so both canonical tiers share the configured role. Keep Stripe paid
  status and active manual periods authoritative, preserve safe unlink/removal,
  and make admin audit queries include both product EAs without exposing keys.
  Keep a compatibility cleanup confirmation if operators already use the
  Pandora wording.
- **Dependencies**: Tasks 2.1 and 2.3.
- **Acceptance criteria**:
  - Paid Chu and paid Pandora accounts are eligible; trialing, failed, future,
    expired, and unrelated tiers are not.
  - Discord role reconciliation is idempotent and never grants Rails access.
  - Admin audits show Chu and Pandora licenses and still redact encrypted keys.
- **Validation**:
  - `bundle exec rspec spec/services/discord/vip_eligibility_spec.rb spec/jobs/discord/reconcile_vip_roles_job_spec.rb spec/services/dashboard/discord_presenter_spec.rb spec/services/admin/subscription_audits/query_spec.rb spec/requests/admin_subscription_audits_spec.rb`.
- **Rollback**: Turn off the shared VIP feature flag and reconcile removals
  through the existing safe unlink path; retain catalog-based eligibility code.

### Task 2.5: Preserve The v1 Licensing API Contract For Chu

- **Location**: `app/controllers/api/v1/licenses_controller.rb`,
  `app/services/licenses/license_verifier.rb`,
  `app/services/licenses/instance_magic_number_allocator.rb`,
  `spec/requests/api/licenses_verify_spec.rb`,
  `spec/requests/api/licenses_heartbeat_spec.rb`,
  `spec/requests/api/licenses_instance_magic_spec.rb`, and daily-results
  contract specs where applicable.
- **Description**: Do not add a Chu-specific endpoint or response field. Add
  fixtures for `ea_id=chu_sniper_trailing`, confirm no required add-ons and no
  daily-results submission, and verify that lane/instance magic remains unique,
  positive, and signed-32-bit-safe.
- **Dependencies**: Task 2.1 and the MQL backend contract.
- **Acceptance criteria**:
  - Chu and Pandora use the same verify/heartbeat/instance-magic paths and
    documented status/error codes.
  - License keys, decrypted payloads, secrets, and private customer data never
    appear in responses, logs, or test output.
- **Validation**:
  - Run the three request spec files plus the existing broker-account daily
    results spec to prove no response regression.
  - Run `bin/rails zeitwerk:check` and the configured security scan.
- **Rollback**: No endpoint rollback is needed; remove only Chu fixtures if the
  catalog is disabled.

### Sprint 2 Gate

- [ ] Exact Chu/Pandora entitlement and seat behavior is covered by tests.
- [ ] Backfill dry-run, apply, rerun, and failure evidence is recorded.
- [ ] API shapes and secret-redaction checks pass.
- [ ] Exactly one Sprint 2 commit is created with the proposed message.
- [ ] The license/Discord rollback point is recorded.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Stripe, Manual Billing, And Transition Semantics

**Goal**: Customers can purchase or change any complete plan with product-aware
upgrade/downgrade behavior, and manual grants never activate a future tier
early.

**Dependencies**: Sprint 2 gate; catalog and license resolvers are live in
test/staging.

**Tracked scope**: plan comparison/change, checkout, schedule metadata, manual
grant activation, invoice/audit labels, and request/service specs.

**Commit**: `feat(billing): support cross-product plan transitions`

**Demo/Validation**:

- Exercise the complete transition matrix in Stripe test-mode doubles and
  assert immediate versus end-of-period behavior.
- Create a future manual Chu grant while Pandora is active and prove Pandora
  remains effective until the start boundary; then prove Chu activates at that
  boundary.
- Verify checkout accepts exactly four complete canonical keys and rejects
  partial, stale, one-time, or unknown keys.

**Rollback point**: Disable plan-change CTAs and new Chu checkout while leaving
  current subscriptions on their existing Stripe prices. Release managed
  schedules only through the existing audited schedule service; do not perform
  an untracked price swap.

### Task 3.1: Centralize Plan-Key Resolution And Comparison

- **Location**: `app/services/billing/subscription_catalog.rb`,
  `app/services/billing/price_key_resolver.rb`,
  `app/services/billing/subscription_plan_resolver.rb`,
  `app/services/billing/plan_comparator.rb`,
  `app/services/billing/price_amount_resolver.rb`, and dashboard/license
  presenters that currently split keys on underscores.
- **Description**: Resolve canonical plans by database price/product id first,
  then by catalog key, and parse interval suffixes from known definitions rather
  than taking the first underscore token. Compare access rank before amounts:
  product changes use tier rank, and same-product changes use monthly/annual
  interval rank. Unknown legacy values retain the existing safe upgrade
  fallback.
- **Dependencies**: Sprint 1 Task 1.2.
- **Acceptance criteria**:
  - `Chu monthly -> Pandora monthly`, `Chu annual -> Pandora monthly`, and
    `Chu annual -> Pandora annual` are upgrades despite raw-price ordering.
  - Every Pandora -> Chu transition is a downgrade; monthly -> annual within a
    tier is an upgrade; annual -> monthly within a tier is a downgrade; equal
    keys are current.
  - All callers use the same tier/interval result for dashboard, invoices,
    licensing, seats, and Discord.
- **Validation**:
  - Add/run `spec/services/billing/plan_comparator_spec.rb`,
    `spec/services/billing/subscription_plan_resolver_spec.rb`, and extend
    `spec/services/billing/invoice_plan_labeler_spec.rb` with the 4x4 matrix.
- **Rollback**: Keep the catalog resolver behind a compatibility method and
  restore raw comparison only for unknown legacy records, never for canonical
  plans.

### Task 3.2: Apply Transition Rules To Stripe Checkout And Schedules

- **Location**: `app/services/billing/plan_change.rb`,
  `app/services/billing/scheduled_plan_change.rb`,
  `app/services/billing/stripe_subscription_schedule.rb`,
  `app/controllers/dashboards_controller.rb`,
  `app/services/billing/legacy_subscription_migrator.rb`, and request specs.
- **Description**: Preserve Stripe idempotency and metadata while enforcing:
  any Chu -> Pandora change is an immediate prorated upgrade; any Pandora ->
  Chu change is an end-of-period downgrade; monthly -> annual within a tier is
  immediate; annual -> monthly is scheduled. Existing legacy migration remains
  an interval-preserving Pandora migration and never reclassifies a current
  Pandora subscriber as Chu.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - Managed schedules are released only when an immediate upgrade succeeds.
  - Repeated requests are idempotent and cannot create duplicate schedules or
    charges.
  - Checkout rejects incomplete products and preserves referral/promotion
    metadata and localized success destinations.
- **Validation**:
  - Extend `spec/requests/subscription_upgrade_spec.rb`,
    `spec/services/billing/stripe_subscription_schedule_spec.rb`,
    `spec/services/billing/legacy_subscription_migrator_spec.rb`, and
    `spec/services/billing/stripe_invoice_notification_processor_spec.rb`.
  - Run the focused request suite with Stripe calls stubbed and inspect safe
    schedule metadata only.
- **Rollback**: Cancel only newly-created managed schedules through the
  cancellation service; leave processor prices and existing periods intact.

### Task 3.3: Make Manual Grants Effective-Plan Aware

- **Location**: `app/services/manual_subscriptions/grant.rb`,
  `app/services/licenses/manual_subscription_sync.rb`,
  `app/jobs/manual_subscriptions/sync_job.rb`,
  `app/models/manual_subscription.rb`, `app/admin/manual_subscriptions.rb`,
  and ActiveAdmin/request specs.
- **Description**: Replace Pandora-only validation with a catalog-backed
  subscription-plan check. Resolve the user's effective `active_at(now)` grant
  rather than the most recently created or future grant; do not expire the
  current Pandora license or issue Chu before `starts_at`. Schedule a retry at
  a future start boundary through `SyncJob.set(wait_until: starts_at)` with the
  existing retry-safe job path, plus an operator rerun path for repair.
  Let admins choose all four canonical plans while preserving authorization,
  overlap rules, idempotent audit events, payment coherence, and the
  active-Stripe conflict guard.
- **Dependencies**: Tasks 2.1 and 3.1.
- **Acceptance criteria**:
  - Future grants do not change licenses, plan display, or Discord eligibility.
  - At `starts_at`, the new tier becomes authoritative and the old tier is
    synchronized/expired atomically enough to avoid mixed access.
  - Repeated admin submissions with the same request id recover the same grant;
    a conflicting request id is rejected.
- **Validation**:
  - Extend `spec/services/manual_subscriptions/grant_spec.rb`,
    `spec/services/licenses/manual_subscription_sync_spec.rb`,
    `spec/jobs/manual_subscriptions/sync_job_spec.rb`,
    `spec/models/manual_subscription_spec.rb`, and
    `spec/requests/admin_manual_subscriptions_spec.rb` with future/current
    Chu/Pandora transitions.
- **Rollback**: Cancel only an incorrectly-created future grant through the
  audited revoke flow; never edit dates or status with an ad hoc SQL update.

### Task 3.4: Generalize Billing And Audit Presentation

- **Location**: `app/services/billing/invoice_plan_labeler.rb`,
  `app/services/admin/subscription_audits/presenter.rb`,
  `app/services/admin/subscription_audits/query.rb`,
  `app/views/dashboards/billing.html.erb`,
  `config/locales/active_admin.en.yml`, and
  `config/locales/active_admin.es.yml`.
- **Description**: Label invoices and audit rows with the resolved product and
  interval, include both EA licenses, and remove customer-facing Pandora-only
  wording where it describes all subscriptions. Keep raw processor ids and
  encrypted keys out of HTML and logs.
- **Dependencies**: Tasks 3.1-3.3.
- **Acceptance criteria**:
  - A cross-product proration invoice identifies the from/to products using
    catalog comparison, not simply the lowest/highest amount.
  - Admin pages expose plan names and safe references for both tiers.
- **Validation**:
  - Run `spec/services/billing/invoice_plan_labeler_spec.rb`,
    `spec/services/admin/subscription_audits/query_spec.rb`,
    `spec/requests/admin_subscription_audits_spec.rb`, and
    `spec/requests/dashboard_billing_spec.rb`.
- **Rollback**: Restore neutral labels only; do not remove stored audit history.

### Sprint 3 Gate

- [ ] The full transition matrix and manual future-start cases pass.
- [ ] Stripe schedule/idempotency evidence is recorded without real customer
  secrets.
- [ ] Checkout rejects incomplete/unknown plans and preserves referrals.
- [ ] Exactly one Sprint 3 commit is created with the proposed message.
- [ ] The billing rollback point and any scheduled transitions are recorded.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Dashboard, Marketing, Localization, And Browser UX

**Goal**: Authenticated Mosaic and public Neon pricing clearly show both
products, correct interval prices, entitlements, states, and accessible EN/ES
responsive behavior.

**Dependencies**: Sprint 3 gate; pricing catalog and transition states are
stable.

**Tracked scope**: dashboard/marketing presenters and views, localization,
Discord copy, guide/download presentation, and browser-facing specs.

**Commit**: `feat(ui): publish Chu and Pandora plan choices`

**Demo/Validation**:

- Render `/dashboard/plans` in EN and ES with no subscription, Chu, and Pandora
  states; verify both cards, interval toggles, current/scheduled badges, and
  correct CTA directions.
- Render Neon `#pricing` in EN and ES with monthly/annual query hints; verify
  both cards, `$19.99`, `$155.92`, `$79.00`, and `$616.20`.
- Run the focused request suite, `npm run build:css`, and one Chromium smoke
  pass with keyboard/focus, mobile, console, and network assertions.

**Rollback point**: Hide Chu from the UI through the catalog completeness/
feature gate while retaining backend resolution for existing customers. Revert
copy and view changes without purging guides or licenses.

### Task 4.1: Make The Mosaic Plans Page Data-Driven

- **Location**: `app/views/dashboards/plans.html.erb`,
  `app/services/billing/dashboard_plan.rb`,
  `app/controllers/dashboards_controller.rb`, and
  `config/locales/dashboard.en.yml` / `config/locales/dashboard.es.yml`.
- **Description**: Replace the single Pandora card and hardcoded key checks with
  catalog tiers and complete intervals. Render Chu first and Pandora second,
  preserve existing Mosaic/Tailwind/Alpine hooks and DOM contracts, show each
  tier's features and five-seat copy, and keep current/upgrade/downgrade/
  scheduled/manual states accessible on mobile.
- **Dependencies**: Sprint 3 Task 3.2.
- **Acceptance criteria**:
  - Every displayed CTA carries the server-resolved canonical plan key; missing
    Stripe ids render an unavailable state rather than a dead checkout.
  - EN/ES copy handles longer Chu/Pandora names without clipping and exposes
    visible focus and `aria-pressed` state on interval controls.
  - The page never trusts a requested query key to grant access.
- **Validation**:
  - Extend `spec/requests/plan_persistence_spec.rb`,
    `spec/requests/subscription_upgrade_spec.rb`,
    `spec/requests/dashboard_billing_spec.rb`, and add/extend a dashboard plans
    request spec for both tiers.
  - Run `npm run build:css`.
- **Rollback**: Restore the prior single-card template only after confirming no
  active Chu customer is being hidden from account management; keep backend
  routes and licenses intact.

### Task 4.2: Publish Both Products On Neon Pricing

- **Location**: `app/services/marketing/neon_landing_pricing.rb`,
  `app/views/templates/neon/pages/home.html.erb`,
  `app/controllers/pages_controller.rb`, `config/locales/en.yml`, and
  `config/locales/es.yml`.
- **Description**: Build pricing cards from complete catalog tiers, preserve the
  configured `LANDING_TEMPLATE=neon` boundary, accept all four canonical query
  hints, and use server-generated registration/dashboard URLs. Update product
  features and annual copy without exposing internal keys in visible copy.
  Leave the static Fintech template unchanged unless a separate boundary task
  explicitly selects it.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - A missing Chu pair does not blank a valid Pandora card; deployment
    verification still fails for an incomplete production catalog.
  - Monthly and annual links preserve the chosen product and interval for both
    signed-out registration and signed-in dashboard flows.
  - Cards remain keyboard navigable and readable at mobile breakpoints.
- **Validation**:
  - Extend `spec/services/marketing/neon_landing_pricing_spec.rb`,
    `spec/requests/home_pricing_cta_spec.rb`, and
    `spec/requests/landing_template_locale_branding_spec.rb`.
  - Run `npm run build:css` and a focused Neon request render in EN/ES.
- **Rollback**: Remove the Chu card/CTA from the landing catalog while leaving
  existing backend checkout and customer dashboards available.

### Task 4.3: Neutralize Discord, Plan, And Admin Copy

- **Location**: `app/views/dashboards/shared/_discord_vip_card.html.erb`,
  `app/views/dashboard/discord_connections/show.html.erb`,
  `config/locales/dashboard.en.yml`, `config/locales/dashboard.es.yml`,
  `config/locales/active_admin.en.yml`, and
  `config/locales/active_admin.es.yml`.
- **Description**: Replace universal Pandora-only wording with shared VIP
  community language while retaining product-specific names where useful.
  Add Chu tier name/description/features in both locales and neutralize manual
  grant/audit labels. Keep the existing Discord role state machine and safe
  unlink copy.
- **Dependencies**: Sprint 2 Task 2.4 and Tasks 4.1-4.2.
- **Acceptance criteria**:
  - Both tiers describe the correct EA/tool benefits and Discord VIP.
  - Spanish translations are complete; no missing-key fallback produces an
    unrelated Sniper Advanced guide or Pandora-only claim.
  - Sensitive keys, processor references, and secure-mode configuration remain
    absent from rendered HTML.
- **Validation**:
  - Run `spec/requests/dashboard_discord_connections_spec.rb`,
    `spec/services/dashboard/discord_presenter_spec.rb`,
    `spec/requests/admin_manual_subscriptions_spec.rb`, and locale/request
    coverage for EN/ES.
- **Rollback**: Revert copy only; role synchronization remains controlled by the
  backend eligibility flag.

### Task 4.4: Verify Guides, Downloads, And Accessibility

- **Location**: `app/views/expert_advisors/guides.html.erb`,
  `app/views/expert_advisors/_show_license_card.html.erb`,
  `app/services/expert_advisors/show_presenter.rb`, and guide files.
- **Description**: Confirm the new `ea_tool` is listed in the authenticated
  dashboard with localized guide content, gated download behavior, current
  license state, and no trial claim. Preserve existing DOM ids, download
  authorization, and non-cacheable license rendering.
- **Dependencies**: Sprint 1 Task 1.3 and Sprint 2 licensing.
- **Acceptance criteria**:
  - Chu appears only for users with an active Chu/Pandora entitlement or the
    documented locked state; download authorization remains server-side.
  - Keyboard, screen-reader labels, focus order, empty, expired, and error
    states are usable in EN/ES.
- **Validation**:
  - Run `spec/requests/expert_advisors_spec.rb`,
    `spec/requests/dashboard_spec.rb`, and relevant presenter specs.
  - Run the browser QA smoke described in the sprint demo.
- **Rollback**: Hide the guide/download card while preserving the license and
  asset records for existing customers.

### Sprint 4 Gate

- [ ] Dashboard and Neon request specs pass in EN and ES.
- [ ] `npm run build:css` passes with no generated vendor-source edits.
- [ ] Chromium smoke covers desktop/mobile, keyboard/focus, console, and
  network failures; artifacts are recorded only if a failure occurs.
- [ ] Exactly one Sprint 4 commit is created with the proposed message.
- [ ] UI rollback and feature-gate state are recorded.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: Deployment Verification, Staging Rehearsal, And Release

**Goal**: The multi-product catalog is observable and repeatable in deployment,
with a rehearsed backfill, safe rollback, and final Rails/MQL integration gates.

**Dependencies**: Sprints 1-4 gates; staging Stripe and database backup are
available.

**Tracked scope**: deploy hook/task aliases, runbooks/README, staging scripts,
operational checks, and final validation artifacts.

**Commit**: `chore(release): verify multi-product catalog rollout`

**Demo/Validation**:

- Run `bin/rails db:prepare db:seed catalog:subscriptions:verify` in staging
  with Stripe test mode and confirm the hook fails closed on missing/wrong
  price, product, or entitlement data.
- Run the Chu backfill dry-run and apply/rerun sequence, then verify counts,
  safe logs, Discord reconciliation, and a representative API smoke.
- Run Rails autoloading, focused/full relevant RSpec, RuboCop, Brakeman, CSS
  build, browser smoke, and the read-only MQL MetaEditor compile command.

**Rollback point**: A tagged release commit plus database backup and a recorded
Stripe catalog snapshot. Disable Chu checkout/price activation first; never
delete Stripe products/prices or run a legacy Pandora-only seed after Chu sales
exist.

### Task 5.1: Replace Pandora-Only Deploy Verification Safely

- **Location**: `lib/tasks/catalog.rake`, `script/setup_common.sh`,
  `README.md`, and `docs/chu_sniper_trailing_subscription_rollout_runbook.md`.
- **Description**: Make the multi-product verifier authoritative, retain
  `catalog:pandora:verify` as a compatibility alias, and update deploy order to
  seed, run `licenses:backfill_chu_subscription_licenses`, verify all four
  prices/six entitlements, then build/restart. Verification must use stable
  ids/counts and never print secrets or license keys.
- **Dependencies**: Sprint 1 reconciler and Sprint 2 backfill.
- **Acceptance criteria**:
  - Deploy fails before restart when either product is incomplete or wrongly
    associated, while a temporary UI/catalog degradation cannot hide a valid
    product from the public page.
  - The verifier confirms legacy migration schedules, active plan/EA counts,
    entitlement exactness, and no unexpected stale access.
  - Re-running setup is idempotent.
- **Validation**:
  - `bin/rails catalog:subscriptions:verify` and
    `bin/rails catalog:pandora:verify` in a disposable environment.
  - Static review of `script/setup_common.sh` to ensure no secret values enter
    command output.
- **Rollback**: Restore the previous hook only before any Chu customer is
  provisioned; otherwise keep the forward-compatible verifier and disable new
  sales with catalog configuration.

### Task 5.2: Publish The Operational Runbook And README Updates

- **Location**: `docs/chu_sniper_trailing_subscription_rollout_runbook.md`,
  `docs/pandora_subscription_rollout_runbook.md`,
  `docs/discord_vip_rollout_runbook.md`, `README.md`, and
  `docs/database_model_reference.md`.
- **Description**: Document preflight snapshots, Stripe test/live product
  creation, seed/reconcile order, backfill dry-run/apply/rerun, manual and
  Discord checks, monitoring, safe key/secret handling, and the product-aware
  rollback. Cross-link the old Pandora runbook instead of deleting its useful
  historical procedure.
- **Dependencies**: Tasks 1.1, 2.2, 2.4, and 5.1.
- **Acceptance criteria**:
  - An operator can identify the exact four prices, two products, six
    entitlements, and two EAs using safe references only.
  - Rollback instructions distinguish pre-launch UI disablement from post-sale
    compatibility preservation.
  - The runbook includes staging rehearsal and post-deploy observation windows.
- **Validation**:
  - `git diff --check`.
  - Validate every command/path in the runbook against the repository and
    installed Stripe/Rails conventions.
- **Rollback**: Revert documentation only; operational state remains governed
  by the tagged release and recorded catalog snapshot.

### Task 5.3: Rehearse Staging And Cross-Repository Integration

- **Location**: staging environment, Rails deploy scripts, and the read-only
  MQL project at
  `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI`.
- **Description**: Use fake/seeded users and Stripe test mode to verify Chu and
  Pandora checkout, webhook sync, licenses, instance magic, seat limits,
  Discord role reconciliation, manual future grants, and rollback. Confirm the
  MQL profile's `chu_sniper_trailing` id, empty required-add-on list, disabled
  daily results, verify/heartbeat paths, and backend-issued magic. Do not edit
  the external MQL repository in this Rails plan.
- **Dependencies**: All prior tasks.
- **Acceptance criteria**:
  - The production `.ex5` is not distributed until backend verification succeeds
    and the external project compiles with zero warnings/errors.
  - No real credentials, license keys, account numbers, or private logs are
    used in browser, Stripe, or external-tool checks.
  - A failed backfill or Discord provider call is visible, retryable, and not
    silently swallowed.
- **Validation**:
  - Run the project-native RSpec command for all affected non-system specs.
  - Run `bin/rails zeitwerk:check`, `bundle exec rubocop` on changed Ruby files,
    `bin/brakeman --no-pager`, and `npm run build:css`.
  - Run the compact browser QA workflow: environment check, one Chromium
    smoke pass, EN/ES pricing/dashboard paths, and console/network assertions.
  - From the MQL framework root, run the documented portable MetaEditor compile:
    `wine MetaEditor64.exe /portable /compile:"$(winepath -w "$(pwd)/MQL5/Experts/HFT_Grid_AI/Chu_Sniper_Trailing.mq5")" /log:"$(winepath -w "$(pwd)/MQL5/Experts/HFT_Grid_AI/BUILD.log")"`,
    treat warnings/errors as failures, inspect the fresh log, and remove it.
- **Rollback**: Restore the staging database/Stripe test snapshot and disable
  Chu checkout; do not reset or modify the external MQL project.

### Task 5.4: Observe, Verify, And Close The Release

- **Location**: deployment dashboards/logs, `docs/chu_sniper_trailing_subscription_rollout_runbook.md`,
  and final release notes.
- **Description**: Monitor seed/reconciliation counts, Stripe webhook failures,
  license verify/heartbeat error codes, online-seat conflicts, backfill
  progress, Discord retry/role state, checkout conversion errors, and support
  reports during the agreed observation window. Record only redacted ids and
  aggregate counts.
- **Dependencies**: Tasks 5.1-5.3.
- **Acceptance criteria**:
  - No unexpected Pandora key rotations, entitlement drift, stale Chu grants,
    duplicate commissions/charges, or unauthorized downloads are observed.
  - Any residual risk has an owner, signal, and next action in the runbook.
- **Validation**:
  - Run the final catalog verifier and a post-deploy EN/ES browser smoke.
  - Review `git status --short`, scoped diff, generated files, skipped checks,
    and unrelated user-owned changes before handoff.
- **Rollback**: Follow the recorded tagged-release and Stripe-disable procedure
  from the runbook; preserve evidence for incident review.

### Sprint 5 Gate

- [ ] Staging seed, backfill, Stripe, licensing, Discord, and rollback rehearsal
  passes.
- [ ] All Rails, security, CSS, browser, and MQL validation evidence is
  recorded, with skipped checks and residual risks explicit.
- [ ] Exactly one Sprint 5 commit is created with the proposed message.
- [ ] The production rollback point, backup, and Stripe snapshot are recorded.
- [ ] The release observation owner and window are documented.

## Testing Strategy

- **Unit**: Pricing constants, integer-cent annual math, catalog completeness,
  plan-key parsing, access/interval comparison, seat caps, VIP flags, manual
  effective-plan selection, and backfill idempotency.
- **Integration**: Seed profiles, Stripe product/price idempotency and history,
  catalog retirement, legacy renewal scheduling, entitlement/license sync,
  manual activation, Discord reconciliation, ActiveAdmin audit queries, and
  referral/promotion metadata.
- **API**: Chu and Pandora verify, heartbeat, instance-magic, rate-limit,
  ownership, add-on, expiry, online-seat, and signed-32-bit magic cases with
  unchanged v1 JSON/error contracts.
- **Request/UI**: Registration price persistence, checkout, all transition
  directions, dashboard plans/billing, EA guides/downloads, Discord states,
  Neon pricing CTAs, EN/ES locale rendering, and invalid/partial catalog
  states.
- **Browser QA**: One deterministic Chromium smoke first, covering public
  Neon pricing, signed-out registration handoff, authenticated Mosaic plans,
  manual/current/scheduled states, keyboard/focus behavior, mobile layout,
  console errors, and failed network responses. Use seeded/fake credentials
  only; capture screenshots/traces only on failure.
- **Security/privacy**: Authorization and ownership checks, no license keys or
  secrets in HTML/logs/telemetry, Stripe webhook authenticity, safe admin
  boundaries, gated Active Storage downloads, and redacted operational logs.
- **Data/operations**: `bin/rails zeitwerk:check`, `db:prepare`, idempotent seed
  reruns, backfill dry-run/apply/rerun, backup/restore rehearsal, RuboCop,
  Brakeman, deployment verifier, Sidekiq retry behavior, and post-deploy
  aggregate monitoring.
- **MQL handoff**: Read-only profile/contract review and one final MetaEditor
  compile; no source or release artifact changes in this Rails plan.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Annual price rounding or a different discount policy | Wrong Stripe amount or customer copy | Keep cents-only formula and make the 35% choice an explicit pre-live gate | Pricing specs and Stripe test-price verification |
| Chu prices reuse Pandora's Stripe product | Product swaps, reporting and entitlement corruption | Group seed definitions by product and verify product ids/names remotely | Reconciler product-association assertions |
| Raw amount comparison treats a cheaper annual Chu plan as a downgrade | Wrong proration or early/later access change | Compare catalog access rank before interval/amount | Complete 4x4 transition matrix |
| Ordinary subscription sync rotates Pandora keys during backfill | Running Pandora EAs fail authentication | Use a Chu-only, locked, idempotent backfill and fingerprint before/after keys | Backfill rerun and key-preservation spec |
| Future manual grant becomes effective early | Unauthorized EA/VIP access or premature expiry | Resolve `active_at(now)` plan and schedule a start-boundary sync | Future-grant service/job specs |
| Implicit tier-index seat math raises Pandora from five to six seats | Capacity and pricing promise drift | Store explicit canonical caps in the catalog | Seat-limit and concurrent allocator specs |
| Pandora-only retirement removes Chu records/licenses | Data loss on seed/deploy/rollback | Retire against desired plan and EA sets; keep compatibility verifier alias | Final reconciliation counts and rollback rehearsal |
| Incomplete Chu setup hides valid Pandora pricing | Lost checkout availability or misleading UI | Filter pricing by complete product while deployment verification remains strict | Partial-catalog pricing specs |
| Discord role copy/eligibility remains Pandora-only | Chu customers cannot receive VIP or stale roles persist | Use catalog VIP flag and neutral EN/ES copy; retain safe reconciliation | VIP eligibility/job/request specs |
| Underscore parsing misidentifies `chu_sniper_trailing` | Wrong tier, seats, labels, or licenses | Resolve known plan keys centrally and test fallback paths | Resolver and API/license specs |
| External MQL profile and Rails EA id diverge | Distributed `.ex5` cannot verify | Publish backend contract and block distribution until compile/API smoke pass | Read-only MQL review and MetaEditor compile |
| Browser/i18n changes break mobile or Spanish layout | Conversion/accessibility regression | Dynamic cards, accessible toggles, EN/ES request tests, Chromium smoke | Browser artifacts and locale specs |
| Backfill or provider failures are swallowed | Silent entitlement drift | Batch/retry, structured redacted logs, verifier counts, and explicit runbook steps | Job failure/retry and deploy logs |

## Rollback Plan

- Before live launch, disable Chu checkout and Stripe price activation, restore
  the tagged code/database snapshot, and leave new Stripe products/prices
  inactive rather than deleting them.
- After any Chu sale, keep the forward-compatible catalog, resolver, and API
  deployed; use a feature/catalog gate to stop new sales while existing Chu
  licenses expire normally or are revoked only through an audited, approved
  operation. Do not revert to a Pandora-only seed/reconciler that would retire
  active Chu access.
- For a failed backfill, stop the task, inspect aggregate progress, rerun only
  failed users, and revoke newly-created Chu rows only if the documented
  rollback decision requires it. Never bulk-rotate or delete Pandora keys.
- For Stripe transition failures, preserve current periods and release only
  managed schedules through `Billing::CancelScheduledPlanChange`; do not issue
  an untracked swap or refund automatically.
- For Discord failures, disable/retry role synchronization independently; Rails
  entitlement remains authoritative and no role cleanup should delete account
  identity data.
- Restore application code, database, and deployment hooks in sprint order from
  the recorded commit/backup points, then rerun the compatibility verifier and
  a read-only license/API smoke before reopening checkout.

## Execution Order

1. Implement Sprint 1 only.
2. Run and record all Sprint 1 validation.
3. Create exactly one Sprint 1 commit and record its rollback point.
4. Start Sprint 2 only after the Sprint 1 gate passes.
5. Repeat the same implementation, validation, single-commit, and rollback
   gate for Sprints 2 through 5 in order.
6. Do not initialize planner execution state, edit implementation files, create
   commits, or begin a sprint during this planning-only turn.

## Completion Checklist

- [ ] Confirmed annual Chu pricing and all four Stripe prices match the
  documented cents/interval/product contract.
- [ ] Two active EAs, two products, four plans, and six exact entitlements are
  verified; Pandora ids and existing licenses remain stable.
- [ ] Existing Pandora users have idempotently received Chu licenses without
  Pandora key rotation.
- [ ] Stripe/manual transition matrix, future manual starts, Discord VIP, seats,
  API contracts, and admin/audit boundaries pass.
- [ ] Mosaic/Neon EN/ES UI, accessibility, responsive behavior, and browser QA
  pass.
- [ ] Deployment verifier, runbook, staging rehearsal, backup, rollback, and
  observation evidence are current.
- [ ] Every sprint has exactly one sprint-specific commit and a recorded
  rollback point.
- [ ] Final residual risks, skipped checks, and owners are documented.
