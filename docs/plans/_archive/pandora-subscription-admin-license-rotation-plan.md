# Pandora Subscription, Admin Audit, and License Rotation Plan

- Status: Completed
- Created: 2026-07-12
- Completed: 2026-07-13
- Complexity: Critical / license-sensitive / production-billing-sensitive
- Execution policy: one Sprint per batch, in order, with validation and exactly one Sprint-specific commit before advancing
- Rails repository: `/home/loldlm/rails_projects/tradingsniperpanel.com` (`main`)
- Pandora MQL5 repository: `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI` (`bot/pandora_box_ea`)
- Planning scope only: this artifact does not authorize implementation, production deployment, Stripe mutation, token rotation, or MQL5 release by itself
- Completion scope: Sprints 1-9 were implemented, validated, and committed. Production deployment, customer EA distribution, live Stripe mutation, and token rotation remain separate operational actions.

## Outcome

Deliver a Pandora-only subscription product with a straightforward ActiveAdmin audit workflow, safe manual access grants, and real license-token rotation. Preserve historical billing evidence, remove privileged-role entitlement bypasses, migrate existing Stripe subscriptions at their next renewal, and keep the current one-script seed-driven deployment safe and repeatable.

The final product catalog is:

| Product | Interval | Price | Rule |
| --- | --- | ---: | --- |
| Pandora Box EA | Monthly | $79.00 | Recurring subscription |
| Pandora Box EA | Annual | $616.20 | 12 monthly periods with the current 35% annual discount |

Annual pricing must be calculated with integer/decimal-safe math: `7900 cents * 12 * 65 / 100 = 61620 cents`. Floats must not determine persisted prices, money totals, refunds, or discounts.

## Confirmed Decisions

- `admin`, `master_admin`, and `full_trader` roles keep their role identities, but no role grants product, course, marketplace, add-on, license, download, or checkout entitlement.
- ActiveAdmin remains restricted to `admin` and `master_admin`; removing entitlement bypasses must not remove admin authorization.
- No production lifetime license is expected. Any unexpected active one-time or role-issued license is inventoried and revoked during catalog convergence.
- All active legacy Stripe subscriptions move to the interval-matched Pandora price at `current_period_end`, without immediate proration. The known annual subscriber receives the new annual price on the next paid period.
- Monthly and annual Pandora intervals remain available.
- A manual grant requires only user, Pandora interval, and number of days. It extends from the later of now or the user's current manual expiration.
- Manual grants can be complimentary or pending payment. Optional payment/reference fields remain available without cluttering the primary form.
- A later active Stripe subscription permanently supersedes the remaining manual grant; queued manual sync work must never overwrite Stripe-backed access.
- Global rotation covers all active/trial licenses for every user role and is `master_admin` only.
- Individual rotation covers one user's active/trial subscription licenses and is available to authorized ActiveAdmin operators.
- Rotation buttons use explicit confirmation and never expose an encrypted key or previous token.
- Audit totals show settled gross, refunds, and settled net separately. "Total paid" means settled gross minus refunds; pending/failed invoices and unpaid manual grants are not counted as paid.
- Deployment never rotates customer tokens automatically. Rotation is an explicit admin operation after the compatible Pandora EA is released.

## Current-State Findings Driving The Plan

- `Licenses::RegenerateKeys` currently recreates the same AES token from email, EA ID, and expiration; it does not invalidate the previous token.
- The current Pandora MQL5 guard accepts exactly three decrypted fields: email, EA ID, and expiration.
- `ManualSubscription` requires operational fields that make the admin form unnecessarily complex, and a late manual sync can overwrite a newer Stripe-backed license.
- Privileged entitlement branches are spread across licensing, EAs, courses, marketplace, add-ons, dashboard checkout, and API verification; removing only one branch would leave inconsistent access.
- Production seeds currently prune stale records before desired Stripe prices/products are proven available.
- `Billing::PlanCreator` replaces the current Stripe price ID, but the application has no normalized history of retired price IDs for old invoices and existing subscriptions.
- Production deployment runs `db:prepare db:seed` before Puma and Sidekiq restart. New schema must therefore be additive and compatible with the still-running old process, and seeds must be safe after partial Stripe/database progress.
- The production seed currently defines Sniper Advanced Panel, Fibonacci Elite, Pandora Box, and a $599 Pandora one-time marketplace product. Pandora subscription pricing is currently $99.99 monthly with an annual `7.8x` float multiplier, equivalent to 35% off twelve monthly payments.

## Architecture And Safety Boundaries

### License token contract

- Existing tokens are version 1 and retain the three-field decrypted payload: `email,ea_id,expires_at`.
- Version 2 and later tokens use four fields: `email,ea_id,expires_at,token_version`.
- The Rails license row stores the authoritative positive `token_version`, with existing rows backfilled/defaulted to `1`.
- New Pandora licenses use the current token version only after the compatible EA release gate passes.
- Rotation increments the persisted version and regenerates `encrypted_key` in one database transaction. An old token fails the existing secure stored-key comparison immediately after the transaction commits.
- The REST JSON request/response shapes and error codes for verify, heartbeat, instance magic, and daily results do not change.
- Neither Rails nor MQL5 logs raw tokens, decrypted payloads, cipher keys, or license secrets.

### Billing audit definition

The audit detail page must show, where available:

- User ID, email, role, locale, and Stripe customer reference.
- Access source: Stripe, manual, trial, expired, revoked, or superseded.
- Current subscription status, plan/product, interval, period start, period end, cancel/end date, and last synchronization time.
- Settled gross, refunded amount, settled net, currency, and manual paid totals using integer cents.
- Successful, refunded, failed, unpaid, and pending invoice/payment rows with processor references and event timestamps.
- Promotion code, promotion percent, referral code, referral discount percent, and the source metadata used to apply the discount.
- Manual grant start/end, granted days, payment state, optional reference/notes, recording admin, and superseding Stripe subscription.
- Pandora license status, expiry, token version, last rotation time, source, and sync time, without rendering `encrypted_key`.
- Data freshness and a visible warning when a local Pay/webhook snapshot cannot provide a field.

The page must use local Pay records, stored Stripe object snapshots/webhooks, plan-price history, manual records, and referral/promotion metadata. It must not make unbounded Stripe API calls in the page request or render raw JSON blobs as the audit interface.

### Historical data

- Do not delete old billing plans, Stripe references, marketplace products, purchases, charges, subscriptions, licenses, enrollments, or manual records needed for audit.
- Retire catalog rows with status/active flags and explicit timestamps or metadata.
- Preserve every Stripe price ID in a normalized price-history record so historical invoices and subscriptions continue to resolve to the correct plan and amount.
- Dormant one-time marketplace tables/services may remain for historical interpretation, but no public/admin flow may create new one-time access unless a future plan explicitly restores it.

### Admin authorization and auditability

- Individual audit, individual rotation, and manual grants require `admin` or `master_admin` ActiveAdmin access.
- Global rotation requires `master_admin` and must enforce this server-side, not only by hiding the button.
- Every manual grant and rotation writes a durable admin audit event containing actor ID, action, target, affected license count/IDs, and timestamps. Metadata must exclude tokens and private processor payloads.
- Concurrent rotations lock affected licenses in stable ID order so global and per-user operations cannot partially overwrite each other.

### Release sequencing

1. Compile and release a Pandora EA that accepts both version 1 and version 2+ payloads.
2. Deploy additive Rails schema and backward-compatible token support.
3. Deploy admin/manual/audit/catalog behavior.
4. Reconcile Stripe/catalog state through the normal deployment script.
5. Verify the application, Sidekiq, seed report, Stripe schedules, and Pandora access.
6. Only then may a `master_admin` perform a global rotation.

## Non-Goals

- Do not change trading strategy, order lifecycle, risk controls, magic-number semantics, seat semantics, or daily-result behavior in Pandora.
- Do not add a new payment provider, job backend, frontend runtime, or UI library.
- Do not redesign ActiveAdmin as Mosaic. The new admin section should use native ActiveAdmin patterns and remain dense, readable, accessible, and operationally simple.
- Do not drop historical one-time tables or aggressively remove dormant marketplace code in this project.
- Do not rotate encryption environment keys or embed/copy license secrets into documentation, tests, logs, screenshots, or plan artifacts.
- Do not run the production deployment, mutate live Stripe state, distribute the EA, or click a rotation action without separate execution/operational authorization.

## Sprint Plan

### Sprint 1 - Pandora client accepts versioned license payloads

Repository: Pandora MQL5 (`bot/pandora_box_ea`)

Goal: make the deployed Pandora client backward-compatible with current three-field tokens and forward-compatible with versioned four-field tokens before Rails can issue rotated tokens.

Tasks:

1. Update `services/shared/license_guard_v1/license_guard_online.mqh` so `DecryptEA()` accepts exactly three or four fields.
2. Treat a three-field payload as token version `1`; parse and validate the fourth field as a positive integer for four-field payloads.
3. Keep email, EA ID, and expiration validation unchanged and fail closed for invalid field counts, invalid versions, mismatched EA IDs, expired tokens, or decryption failures.
4. Do not add the version to API JSON payloads; the encrypted `license_key` remains the only token sent to Rails.
5. Ensure diagnostics never print the raw token or decrypted payload. Keep user-facing failure messages generic.
6. Document both token formats and the server-authoritative exact-token check in `services/shared/license_guard_v1/backend-entitlements-contract.md`.
7. Update `services/shared/license_guard_v1/README.md` with the compatibility and rollout rule: clients accepting v2 must ship before rotation.
8. Preserve the existing untracked `.venv/`, `artifacts/`, and `tools/` content and do not include it in the Sprint commit.

Acceptance criteria:

- Existing version 1 tokens still decrypt and reach online verification.
- Version 2+ tokens decrypt, validate locally, and reach the same online verification path.
- Payloads with fewer than three, more than four, or invalid fourth fields fail closed.
- Verify/heartbeat/instance-magic/daily-results JSON contracts remain unchanged.
- Trading behavior, magic-number ownership, add-on checks, timer cadence, and daily-result behavior are untouched.

Validation:

- Run the documented MetaEditor command from the MQL5 `AGENTS.md` against `HFT_Grid_AI.mq5`.
- Parse `BUILD.log` and require zero errors and zero warnings.
- Perform a focused non-production startup smoke with locally generated/sanitized v1 and v2 fixtures; do not commit or report the fixture tokens.
- Review the diff for secret exposure and unrelated trading changes.

Rollback:

- Reverting this Sprint returns the client to v1-only parsing. It is safe only before any version 2+ customer token is issued.

Commit: `Sprint 1: accept versioned Pandora license tokens`

Release gate: distribute the compiled compatible Pandora EA and confirm it is the supported customer build before any rotation UI is enabled or used.

### Sprint 2 - Rails versioned tokens and atomic rotation domain

Repository: Rails (`main`)

Goal: make token regeneration a real revocation operation while preserving all existing API contracts and v1 licenses.

Tasks:

1. Add an additive migration for `licenses.token_version` (`integer`, default/backfill `1`, `null: false`) and `licenses.token_rotated_at` (`datetime`, nullable), with a positive-version database check constraint.
2. Update `app/models/license.rb` with the current token version, validation, and a single method for the token-generation attributes.
3. Extend `app/services/licenses/license_key_encoder.rb`:
   - version 1 builds the current three-field payload;
   - version 2+ builds the four-field payload;
   - `valid_key?` validates against the supplied version;
   - money, IDs, and timestamps remain normalized without leaking plaintext.
4. Update `app/services/licenses/license_verifier.rb` to validate using the license row's version while preserving current secure comparisons and error codes.
5. Replace the misleading behavior in `app/services/licenses/regenerate_keys.rb` with an explicit `Licenses::RotateTokens` command (delete/retire the old class after call sites are migrated).
6. The rotation command accepts either all active/trial licenses or one user's active/trial subscription licenses, locks rows in ID order, increments versions, regenerates keys, stamps rotation/sync times, and commits atomically.
7. Update every remaining token issuer/sync path to supply a token version, including subscription sync, manual sync, trial provisioning, and temporarily retained one-time/manual-transaction paths until their public creation flows are retired.
8. Existing licenses remain version 1 until a sync legitimately reissues their key or an admin explicitly rotates them; deployment itself must not rotate them.
9. Add/adjust factories and focused specs for v1 compatibility, v2 generation, multiple rotations, stale-token rejection, current-token acceptance, transaction rollback, and concurrent stable locking.

Primary files:

- `db/migrate/*_add_token_version_to_licenses.rb`
- `db/schema.rb`
- `app/models/license.rb`
- `app/services/licenses/license_key_encoder.rb`
- `app/services/licenses/license_verifier.rb`
- `app/services/licenses/rotate_tokens.rb`
- `app/services/licenses/regenerate_keys.rb` (retire/remove)
- `app/services/licenses/subscription_license_sync.rb`
- `app/services/licenses/manual_subscription_sync.rb`
- `app/services/licenses/one_time_purchase_sync.rb`
- `app/services/manual_transactions/fulfillment.rb`
- the existing trial provisioning service discovered during implementation
- `spec/factories/licenses.rb`
- `spec/services/licenses/license_key_encoder_spec.rb`
- `spec/services/licenses/license_verifier_spec.rb`
- `spec/services/licenses/rotate_tokens_spec.rb`
- affected API request specs under `spec/requests/api/`

Acceptance criteria:

- A token captured before rotation receives `invalid_key` immediately after the rotation transaction commits.
- The newly issued token passes verify, heartbeat, instance magic, and daily results.
- A failed global rotation leaves every affected row on its prior token/version; partial rotation is not visible.
- Per-user rotation cannot touch another user's licenses or non-subscription licenses.
- No token appears in logs, errors, audit metadata, HTML, or test failure messages.

Validation:

- Run the focused encoder, verifier, rotation, sync, and API request specs.
- Run `bin/rails db:migrate` against a populated local/test database and verify existing licenses read as version 1.
- Run `bin/rails zeitwerk:check`.
- Review migration lock/backfill behavior, rollback, and old-process compatibility.

Rollback:

- The additive columns can remain during a code rollback.
- Tokens already rotated cannot safely be restored because previous raw tokens are intentionally not retained; affected users must receive/use the current token.

Commit: `Sprint 2: add atomic versioned license rotation`

### Sprint 3 - Simple manual Pandora grants and Stripe supersession

Repository: Rails (`main`)

Goal: reduce manual access to a simple user + Pandora interval + days workflow while making Stripe precedence durable and race-safe.

Tasks:

1. Add additive manual-subscription fields needed for clear audit semantics:
   - positive `granted_days`;
   - `payment_status` such as `complimentary`, `pending`, or `paid`;
   - nullable `paid_at` and non-negative `amount_cents`;
   - `superseded_at` and optional `superseded_by_pay_subscription_id`;
   - `superseded` status in addition to active/expired/cancelled.
2. Backfill existing rows as paid using their existing amount/paid date and calculate `granted_days` from their stored period without changing access dates.
3. Add database/model constraints for non-negative money, positive days, valid date ordering, and coherent paid/superseded fields.
4. Implement `ManualSubscriptions::Grant` as the only new admin creation path:
   - require a user, active Pandora subscription plan, and bounded positive day count;
   - calculate `starts_at` from the later of `Time.current` or the user's latest non-superseded manual end;
   - set `ends_at = starts_at + granted_days.days`;
   - default to `$0` complimentary when no payment details are supplied;
   - permit optional amount, paid date, reference, method, and notes;
   - reject creation while an active Stripe subscription exists.
5. Update `Licenses::SubscriptionLicenseSync` to supersede active/pending manual grants before applying Stripe-backed license state.
6. Update `Licenses::ManualSubscriptionSync` to re-check for an active Stripe subscription at job execution time and no-op/supersede instead of overwriting Stripe access.
7. Keep `Billing::ActiveSubscriptionFinder` explicitly Stripe-first and exclude superseded manual records.
8. Cover out-of-order jobs: manual grant, Stripe subscription creation, delayed manual job, Stripe update, and cancellation.

Primary files:

- `db/migrate/*_simplify_manual_subscriptions.rb`
- `db/schema.rb`
- `app/models/manual_subscription.rb`
- `app/services/manual_subscriptions/grant.rb`
- `app/services/licenses/manual_subscription_sync.rb`
- `app/services/licenses/subscription_license_sync.rb`
- `app/models/concerns/licenses/pay_subscription_callbacks.rb`
- `app/services/billing/active_subscription_finder.rb`
- `app/jobs/manual_subscriptions/sync_job.rb`
- `spec/models/manual_subscription_spec.rb`
- `spec/services/manual_subscriptions/grant_spec.rb`
- `spec/services/licenses/manual_subscription_sync_spec.rb`
- `spec/services/licenses/subscription_license_sync_spec.rb`
- `spec/services/billing/active_subscription_finder_spec.rb`
- `spec/models/pay_subscription_callbacks_spec.rb`

Acceptance criteria:

- The primary grant contract is exactly user, Pandora plan/interval, and days.
- Repeated grants extend from the existing manual end rather than losing remaining time.
- Complimentary and pending grants contribute `$0` to total paid.
- A later Stripe subscription supersedes the manual grant and remains authoritative even if an older manual job runs afterward.
- Manual grants never create one-time/lifetime access and never grant non-Pandora products.

Validation:

- Run the focused model/service/job specs.
- Run migration up/down checks on representative existing manual rows.
- Verify transaction and locking behavior for two simultaneous grants to the same user.

Rollback:

- Keep new nullable/additive fields during code rollback.
- A superseded grant is not automatically restored; an admin can issue a new bounded manual grant if business policy requires it.

Commit: `Sprint 3: simplify manual Pandora grants`

### Sprint 4 - Preserve Stripe price history and exact Pandora pricing

Repository: Rails (`main`)

Goal: make price replacement auditable and allow legacy subscriptions/invoices to resolve after the canonical Pandora price changes.

Tasks:

1. Add `billing_plan_prices` with billing plan, Stripe price ID (unique), amount cents, currency, interval/count, active/current flag, created/retired timestamps, and safe metadata.
2. Backfill each existing `billing_plans.stripe_price_id` into price history without deleting the existing canonical columns.
3. Update `Billing::PlanCreator` so a replacement Stripe price is created first, persisted in history, marked current, and only then retires the previous history row/remote price. Retry must converge on the same current price.
4. Update `BillingPlan.for_price_id`, `Billing::PriceKeyResolver`, `Billing::ConfiguredPrices`, and invoice labeling to resolve both current and historical Stripe prices.
5. Define one product tier (`pandora_pro`) and exact pricing constants: monthly `7900`, annual discount `35`, annual `61620`.
6. Replace float-based annual price and discount calculations in production-facing pricing paths with integer/decimal-safe calculations. Formatting may convert only at the final display boundary.
7. Ensure historical charges retain the amount/interval captured by their price-history row even after the current plan price changes.

Primary files:

- `db/migrate/*_create_billing_plan_prices.rb`
- `db/schema.rb`
- `app/models/billing_plan_price.rb`
- `app/models/billing_plan.rb`
- `app/services/billing/plan_creator.rb`
- `app/services/billing/price_key_resolver.rb`
- `app/services/billing/configured_prices.rb`
- `app/services/billing/invoice_plan_labeler.rb`
- `app/services/billing/pricing_catalog.rb`
- `spec/factories/billing_plan_prices.rb`
- `spec/models/billing_plan_price_spec.rb`
- `spec/services/billing/plan_creator_spec.rb`
- `spec/services/billing/configured_prices_spec.rb`
- `spec/services/billing/invoice_plan_labeler_spec.rb`
- `spec/services/billing/pricing_catalog_spec.rb`

Acceptance criteria:

- A current and a retired price ID both resolve to Pandora and their original amounts.
- Re-running price creation does not create duplicate local history or duplicate Stripe prices for the same definition.
- The displayed and persisted annual price is exactly `$616.20`, and the displayed discount is exactly `35%`.
- A Stripe failure leaves the prior current price usable and local state coherent.

Validation:

- Run focused model and billing service specs with Stripe stubs for create, retrieve, deactivate, retry, and failure.
- Run migration/backfill against representative current and retired plans.
- Run `bin/rails zeitwerk:check`.

Rollback:

- Keep price history during code rollback; it is additive and preserves evidence.
- Do not delete a newly created Stripe price during rollback. Mark it inactive and restore the prior current mapping if no subscription has transitioned.

Commit: `Sprint 4: preserve billing plan price history`

### Sprint 5 - ActiveAdmin subscription audit and operational actions

Repository: Rails (`main`)

Goal: provide one straightforward place to audit subscribed users and perform safe per-user/manual/global operations.

Tasks:

1. Add a small durable `admin_audit_events` table/model with actor, action, optional target, safe JSON metadata, request ID, and timestamps. Do not store tokens or raw Stripe objects.
2. Add `Admin::SubscriptionAudits::Query` and presenter/value objects that preload and normalize:
   - User and Pay customer/subscription data;
   - current/historical plan-price mapping;
   - Pay charges and refunds;
   - relevant invoice success/failure webhook snapshots;
   - manual grants;
   - promotion/referral metadata;
   - Pandora licenses and rotation metadata.
3. Add `app/admin/subscription_audits.rb` as a read-oriented ActiveAdmin section:
   - index users with Stripe or manual subscription history;
   - concise columns for source, status, Pandora interval, period start/end, settled net, refunds, manual access, and license status;
   - filters/search for email, source, status, interval, and ending period;
   - paginated, eager-loaded queries.
4. Add a detail page with clearly separated panels: subscription, payment totals, invoice/payment history, promotions/referrals, manual grants, licenses, and admin events.
5. Show gross/refunds/net in integer-cent-safe currency formatting and label unavailable local snapshot fields instead of guessing.
6. Add a simple manual-grant form with required user/plan/days fields and an optional payment-details section. Replace or make read-only the current broad creation form in `app/admin/manual_subscriptions.rb`.
7. Add a per-user "Rotate subscription licenses" action with affected-count confirmation.
8. Add a `master_admin`-only "Rotate all active/trial licenses" action with high-friction confirmation that states old tokens stop working after commit.
9. Enforce authorization in controllers/commands, write an admin audit event in the same transaction as each grant/rotation, and protect double submissions.
10. Add EN/ES ActiveAdmin copy. Use native ActiveAdmin patterns; do not introduce Mosaic assets or a new frontend runtime.

Primary files:

- `db/migrate/*_create_admin_audit_events.rb`
- `db/schema.rb`
- `app/models/admin_audit_event.rb`
- `app/services/admin/subscription_audits/query.rb`
- `app/services/admin/subscription_audits/presenter.rb`
- `app/services/admin/subscription_audits/invoice_snapshot.rb`
- `app/admin/subscription_audits.rb`
- `app/admin/manual_subscriptions.rb`
- `app/admin/users.rb` only if a cross-link is useful
- `app/helpers/active_admin_helper.rb` or the existing admin currency helper
- `config/locales/active_admin.en.yml`
- `config/locales/active_admin.es.yml`
- `spec/models/admin_audit_event_spec.rb`
- `spec/services/admin/subscription_audits/query_spec.rb`
- `spec/requests/admin_subscription_audits_spec.rb`
- focused request specs for grant and rotation authorization

Acceptance criteria:

- An operator can answer who has access, why, for what period, what was paid/refunded, what discount was applied, and whether the current Pandora license is valid without inspecting Rails console or raw JSON.
- `admin` cannot perform global rotation; `master_admin` can. Trader, partner, and full-trader sessions cannot reach any ActiveAdmin action.
- Individual rotation affects only the selected user's active/trial subscription licenses.
- The page source, CSV, logs, and audit events contain no `encrypted_key` or raw token.
- Failed/unpaid events are shown but excluded from settled paid totals.

Validation:

- Run model, query/presenter, and ActiveAdmin request specs for all roles and both locales.
- Test gross/refund/net math, mixed currencies, missing snapshots, failed invoices, promotion metadata, referral metadata, complimentary grants, pending grants, and superseded grants.
- Run a focused browser smoke of index, detail, grant validation, confirmation dialogs, success/error states, keyboard focus, and narrow viewport.
- Browser QA: required.

Rollback:

- The audit table can remain if UI/routes are rolled back.
- Admin operations already committed remain valid and visible in the audit log.

Commit: `Sprint 5: add subscription audit admin tools`

### Sprint 6 - Remove privileged-role entitlement bypasses

Repository: Rails (`main`)

Goal: make all product access depend on real trial/subscription/manual entitlement regardless of user role, while preserving ActiveAdmin authorization.

Tasks:

1. Remove role-based license provisioning and verification from:
   - `app/models/user.rb` role-change callback/access helper;
   - `app/services/access/privileged_role_policy.rb`;
   - `app/services/licenses/privileged_access.rb`;
   - `app/services/licenses/license_verifier.rb`;
   - `app/services/licenses/accessible_expert_advisors.rb`.
2. Remove privileged allow branches from add-on, course, EA, marketplace, download, presenter, and controller paths discovered by a fresh repository-wide search, including:
   - `app/services/licenses/addon_access.rb`;
   - `app/services/licenses/granted_addons.rb`;
   - `app/services/addons/eligibility.rb`;
   - `app/services/courses/accessible_courses.rb`;
   - `app/services/expert_advisors/bundle_resolver.rb`;
   - `app/services/expert_advisors/index_presenter.rb`;
   - `app/services/expert_advisors/show_presenter.rb`;
   - `app/services/marketplace/asset_access.rb`;
   - `app/services/marketplace/show_presenter.rb`;
   - `app/controllers/dashboards_controller.rb`;
   - `app/controllers/expert_advisors_controller.rb`;
   - `app/controllers/marketplace_controller.rb`.
3. Remove the privileged checkout block so admin/master-admin users may buy Pandora like any other user.
4. Preserve `ApplicationController#authenticate_admin_user!`, `admin_user?`, `master_admin?`, and `Admin::Users::RoleGuard` behavior for ActiveAdmin security.
5. Add a one-time idempotent revocation operation for existing `source: "role_access"` licenses; the seed reconciliation Sprint will invoke it only after Pandora catalog verification.
6. Replace/delete privileged behavior specs with regression coverage proving every role receives identical entitlement decisions for the same billing state.

Acceptance criteria:

- Changing a user to admin, master_admin, or full_trader creates no product license and grants no catalog access.
- A privileged role without a subscription/manual grant receives the same `license_not_found`/access-denied result as a trader.
- A subscribed admin can use Pandora and still access ActiveAdmin.
- No `role_access` license remains active after the explicit revocation operation.

Validation:

- Run the affected service and request specs for licenses, EAs, courses, marketplace, add-ons, downloads, and checkout.
- Run a repository search proving no entitlement call site still invokes `Access::PrivilegedRolePolicy.full_access?` or `Licenses::PrivilegedAccess`.
- Run `bin/rails zeitwerk:check` after deleting constants/files.
- Perform the security review for role boundaries, ownership, secret/log safety, and licensing scope.

Rollback:

- Code rollback can restore bypass logic, but revoked role-issued tokens are not restored automatically. This is intentional; re-provisioning them would contradict the confirmed product policy.

Commit: `Sprint 6: remove role-based product access`

### Sprint 7 - Pandora-only application and commerce surfaces

Repository: Rails (`main`)

Goal: expose only Pandora monthly/annual subscriptions and make stale one-time/direct checkout paths fail closed while preserving historical records.

Tasks:

1. Restrict all active pricing/catalog queries to the two Pandora subscription plans.
2. Simplify `app/views/dashboards/plans.html.erb` to one Pandora card with monthly/annual interval controls, current/scheduled state, promotion support, and normal subscribe/change actions.
3. Remove privileged-included messaging, old tier cards, one-time/lifetime CTAs, add-on upsells, and marketplace purchase entry points from user-visible surfaces.
4. Update `Marketing::NeonLandingPricing`, the Neon landing pricing section, dashboard navigation/sidebar, and EN/ES copy to describe only Pandora subscriptions at $79 monthly / $616.20 annually.
5. Make direct checkout reject inactive, non-Pandora, or one-time plans even if a stale ID/key is posted.
6. Make marketplace availability/navigation empty or unavailable for new commerce while preserving admin/history access to old marketplace records.
7. Keep legal/refund copy sufficient for legacy one-time purchases, but remove claims that new one-time/lifetime products are currently offered.
8. Remove one-time seat/lifetime feature copy from active product presentation without dropping historical entitlement-source values.
9. Update request/presenter/marketing tests to use Pandora as the production product. Generic factories may still create synthetic plans for isolated domain tests.

Primary files:

- `app/controllers/dashboards_controller.rb`
- `app/services/billing/pricing_catalog.rb`
- `app/services/billing/dashboard_plan.rb`
- `app/services/marketing/neon_landing_pricing.rb`
- `app/services/marketplace/availability.rb`
- `app/views/dashboards/plans.html.erb`
- `app/views/layouts/dashboard.html.erb`
- `app/views/templates/neon/pages/home.html.erb`
- relevant marketplace views/partials only where needed to remove active commerce links
- `config/locales/dashboard.en.yml`
- `config/locales/dashboard.es.yml`
- `config/locales/en.yml`
- `config/locales/es.yml`
- `spec/requests/home_pricing_cta_spec.rb`
- `spec/requests/plan_persistence_spec.rb`
- `spec/requests/subscription_upgrade_spec.rb`
- `spec/services/marketing/neon_landing_pricing_spec.rb`
- `spec/services/billing/pricing_catalog_spec.rb`
- affected marketplace/request specs

Acceptance criteria:

- Landing and dashboard show exactly Pandora monthly and annual options with exact prices/discount.
- A posted old plan key, one-time plan key, stale marketplace product, or retired Stripe price cannot open a new checkout.
- Existing Stripe subscription management, promotion/referral checkout metadata, cancellation, and billing portal remain functional.
- No active page promises lifetime/forever access.

Validation:

- Run focused pricing, checkout, subscription-change, landing, and marketplace request/service specs.
- Run `npm run build:css` because ERB/Tailwind extraction changes.
- Run browser smoke for EN/ES, desktop/mobile, interval switch, promotion prefill, checkout button state, subscribed state, and direct stale URLs.
- Browser QA: required.

Rollback:

- Reactivating UI alone is insufficient because old Stripe prices/products may be inactive. Rollback must restore both application filtering and catalog state through the documented catalog rollback operation.

Commit: `Sprint 7: make Pandora the only purchasable product`

### Sprint 8 - Seed-driven catalog convergence and renewal migration

Repository: Rails (`main`)

Goal: make the existing one-script deployment create/verify Pandora first, migrate subscriptions at renewal, and retire everything else safely and idempotently.

Tasks:

1. Replace production/full-QA seed catalog definitions with only:
   - `pandora_pro_monthly`, `7900` cents;
   - `pandora_pro_annual`, `61620` cents;
   - Pandora Box EA and its two subscription entitlements.
2. Remove the Pandora $599 one-time product and every other product/add-on/plan/EA from desired seed definitions. Keep synthetic test data in factories, not in production-mirror catalog definitions.
3. Refactor `Seeds::Runner.seed_prod_mirror!` and shared seed helpers into this fail-safe order:
   1. create/update Pandora Stripe product and monthly/annual prices;
   2. persist current and retired price history;
   3. upsert Pandora EA and both entitlements;
   4. verify the complete desired catalog and exact amounts;
   5. inventory active Pay subscriptions, manual grants, one-time licenses, and role licenses;
   6. idempotently schedule every active legacy subscription to the interval-matched Pandora price at `current_period_end`;
   7. verify each schedule and record safe migration metadata;
   8. retire stale local plans/products/add-ons/EAs and remote prices/products from new purchase use;
   9. revoke unexpected active one-time and role-issued licenses and expire non-Pandora subscription licenses;
   10. verify the final catalog/access state.
4. Implement a dedicated retry-safe reconciliation service rather than embedding opaque Stripe logic directly in `db/seeds/shared.rb`.
5. Reuse/extend `Billing::StripeSubscriptionSchedule`; never mutate price immediately or apply proration. Preserve quantity and current phase until `current_period_end`.
6. If an unmanaged/conflicting Stripe schedule exists, fail before retirement and report the subscription processor ID; do not silently overwrite it.
7. Persist migration markers on Pay subscription metadata so a second seed run observes the existing intended schedule and does not create another.
8. Emit a compact seed summary with desired plan IDs, counts of scheduled subscriptions, retired records, revoked licenses, and blockers. Do not log emails, tokens, raw Stripe payloads, or signed URLs.
9. Add `catalog:pandora:verify` (or equivalent) and call it from the existing deployment preparation after `db:seed`, so `script/setup_production.sh` remains the single deployment entry point.
10. Preserve the current behavior that a failed prepare/seed/verification stops before Puma/Sidekiq restart.
11. Add failure-injection specs proving that Pandora creation or schedule failure does not retire the old catalog, and rerun specs proving the complete reconciliation is idempotent.

Primary files:

- `db/seeds/shared.rb`
- `db/seeds/runner.rb`
- `db/seeds/production.rb` only if orchestration needs a clear entry point
- `app/services/billing/pandora_catalog_reconciler.rb`
- `app/services/billing/legacy_subscription_migrator.rb`
- `app/services/billing/stripe_subscription_schedule.rb`
- `app/services/catalog/retire_legacy_access.rb`
- `lib/tasks/catalog.rake`
- `script/setup_common.sh`
- `spec/seeds/runner_spec.rb`
- `spec/seeds/marketplace_seed_spec.rb`
- `spec/services/billing/pandora_catalog_reconciler_spec.rb`
- `spec/services/billing/legacy_subscription_migrator_spec.rb`
- `spec/services/billing/stripe_subscription_schedule_spec.rb`
- focused retirement/revocation specs

Acceptance criteria:

- A clean seed creates exactly the two active Pandora plans and one active Pandora EA entitlement set.
- A seed against the current production-shaped catalog creates/verifies Pandora and schedules renewals before any stale catalog row is retired.
- The known annual subscription remains on its current price until its current period ends, then changes to `$616.20/year`.
- Monthly legacy subscriptions, if present, move to `$79/month` at their own period ends.
- Running `db:seed` and the verification task twice produces no duplicate prices, schedules, products, entitlements, grants, or revocations.
- Any Stripe/catalog blocker aborts before destructive retirement and leaves a clear retry path.
- Historical rows and retired price mappings remain queryable in the admin audit.

Validation:

- Run seed, reconciler, schedule, and retirement specs including failure/retry cases.
- Run `RAILS_ENV=test bin/rails db:seed` with the production-mirror profile twice and compare resulting counts/keys.
- Rehearse against staging/test-mode Stripe with a representative annual subscription and verify the schedule effective date/price.
- Run `bash -n script/setup_common.sh script/setup_production.sh` and any existing shell lint.
- Run the catalog verification task after the second seed.

Rollback:

- Before a scheduled transition: release/cancel the managed subscription schedule, restore prior current-plan mappings, and reactivate the prior local/Stripe price only through the rollback service/runbook.
- After a transition: do not silently swap back or create proration; schedule an explicit future correction or handle the subscription manually.
- Retired historical rows remain present, making reactivation possible without reconstructing IDs.

Commit: `Sprint 8: reconcile Pandora catalog on deploy`

### Sprint 9 - Contracts, release rehearsal, and final production gate

Repository: Rails (`main`)

Goal: align project documentation with the new behavior and prove the cross-repository rollout is safe before production execution.

Tasks:

1. Update `docs/database_model_reference.md` for token versions, manual grant/supersession fields, price history, admin audit events, Pandora-only entitlements, and unchanged API JSON contracts.
2. Update `README.md` for:
   - the two Pandora prices and 35% calculation;
   - seed reconciliation order and idempotency;
   - staging rehearsal;
   - post-deploy verification;
   - subscription-schedule rollback;
   - manual grant and token rotation operator rules;
   - the requirement that the compatible Pandora EA ship before rotation.
3. Add a concise production runbook/checklist if the README would become unclear. It must use the existing deployment script and avoid secrets/customer data.
4. Confirm MQL5 contract docs from Sprint 1 and Rails contract docs describe the same v1/v2 payload behavior.
5. Run the full relevant Rails Review Gate and resolve deterministic failures caused by the work.
6. Review both repository statuses/diffs and ensure only intended tracked files are committed; preserve MQL5 untracked user files.
7. Record the exact operator sequence, but do not deploy or rotate tokens as part of this Sprint without separate authorization.

Production gate checklist:

- Compatible Pandora EA compiled with zero warnings/errors and distributed.
- Rails migrations reviewed as additive/rollback-compatible with the old running process.
- Focused and broad RSpec checks pass.
- `bin/rails zeitwerk:check` passes.
- Relevant RuboCop and Brakeman checks pass or have documented unrelated baseline findings.
- CSS build and focused browser QA pass for admin, landing, plans, billing, and stale direct URLs.
- Production-mirror seeds and catalog verification pass twice.
- Test-mode Stripe rehearsal proves one annual renewal schedule moves to the new annual price at `current_period_end`.
- Failure rehearsal proves no stale catalog retirement occurs when Stripe creation/scheduling fails.
- Post-deploy checks cover app health, Sidekiq, recent logs, catalog verification, ActiveAdmin audit data, current subscription periods, and schedule references.
- Global token rotation remains manual and unperformed until an operator confirms customer client compatibility.

Validation commands (adapt to local availability and run narrow checks first):

```bash
bundle exec rspec spec/models spec/services spec/requests spec/seeds
bin/rails zeitwerk:check
bin/rubocop
bin/brakeman --no-pager
npm run build:css
git diff --check
```

Also run the focused browser runner and the MQL5 MetaEditor compile command documented in each repository.

Acceptance criteria:

- Rails and MQL5 documentation agree on token compatibility and rollout order.
- The documented deployment is still one script and has an automatic post-seed verification gate.
- Rollback limits are explicit for Stripe schedules, catalog retirement, manual supersession, and irreversible token rotation.
- No unresolved security, billing, data-loss, browser, or client-compatibility blocker remains.

Rollback:

- Documentation-only changes can be reverted independently; do not revert facts that already describe deployed schema/behavior.

Commit: `Sprint 9: document Pandora subscription rollout`

## Cross-Sprint Test Matrix

| Scenario | Expected result |
| --- | --- |
| Existing v1 Pandora token before rotation | Continues to work |
| Rotated v2 token on compatible Pandora client | Works |
| Previous token after rotation commit | `invalid_key` on every licensing endpoint |
| Global rotation by admin | Forbidden |
| Global rotation by master admin | All active/trial licenses rotate atomically |
| Individual rotation | Only selected user's active/trial subscription licenses rotate |
| Manual grant with user + plan + days | Extends from later of now/current manual end |
| Complimentary/pending manual grant | Grants time, contributes `$0` paid |
| Stripe subscription after manual grant | Manual grant becomes superseded; Stripe license wins |
| Delayed manual sync after Stripe sync | Cannot overwrite Stripe license |
| Privileged role without payment/grant | No product access |
| Privileged role with Pandora subscription | Pandora access plus existing admin authorization where applicable |
| Old one-time/direct plan checkout | Rejected |
| Current monthly checkout | `$79.00/month` |
| Current annual checkout | `$616.20/year`, displayed as 35% savings |
| Existing annual subscription | Old price through current period, new annual price next period |
| Refunded charge | Gross and refund shown; net reduced |
| Failed/unpaid invoice | Shown in history, excluded from settled total |
| Seed run twice | Same two active plans, one Pandora EA, no duplicate schedule or Stripe price |
| Stripe failure during seed | Old catalog remains active; deployment stops before restart |

## Operational Notes And Residual Risks

- Token rotation is intentionally irreversible without issuing another token. Never perform it as a seed, migration callback, deploy hook, or role-change callback.
- Users running an old Pandora build that cannot parse four fields will fail locally after rotation even though Rails is correct. This is why Sprint 1 release is a hard gate.
- Stripe subscription schedules are external state and cannot be transactionally rolled back with PostgreSQL. The reconciler must use idempotency, persisted markers, verification, and a documented release/cancel path.
- Pay/Stripe object JSON varies by gem/API version. The admin audit adapter must be fixture-tested against the locally stored shapes and show "unavailable" rather than infer unsupported fields.
- Mixed-currency totals must never be summed into one number. Group totals by currency; the expected catalog currency is USD.
- Old product/catalog records remain for audit. "Remove" means no longer active, purchasable, entitled, or advertised, not destructive deletion of financial history.
- The external MQL5 repository contains untracked user files. Execution must never clean, add, or overwrite them.

## Completion Definition

The plan is complete only when all nine Sprints have passed their validation, each has exactly one Sprint-specific commit in its repository, the compatible Pandora EA has been released, staging/test-mode Stripe rehearsal has passed, the seed-driven production gate is green, and the operator has a verified but still manual choice to perform token rotation.
