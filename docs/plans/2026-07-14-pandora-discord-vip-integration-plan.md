# Plan: Pandora Discord VIP Subscription Integration

**Generated**: 2026-07-14
**Status**: Sprints 1-6 complete; Sprint 7 release candidate ready for production
**Estimated Complexity**: High

## Overview

Build a server-authoritative Discord integration for Pandora Box subscribers. A
localized public link will preserve the existing sign-up and Pandora checkout
journey, successful subscribers will be invited to connect Discord from the
Mosaic dashboard and activation email, and the Rails app will add or remove the
`Pandora VIP` Discord role according to the same paid-access truth used by the
application.

The Rails app will use Discord's REST API directly. It will not run a separate
Discord gateway bot, request privileged gateway intents, read messages, manage
channels, or use Discord roles as a source of application entitlement. Stripe,
Pay, and active manual Pandora grants remain authoritative; Discord is a
downstream benefit.

### Target Journey

```text
Public Discord link: /join/pandora
  -> existing EN/ES locale resolver
  -> sign up or sign in when needed
  -> Pandora plans page, monthly preselected and annual available
  -> Stripe Checkout
  -> dashboard Discord activation page
  -> Discord OAuth2: identify + guilds.join
  -> automatic server join
  -> background Pandora VIP role synchronization
  -> user accepts Discord membership screening when required
  -> ELITE category becomes visible through the Pandora VIP role

Stripe/Pay or manual grant changes
  -> existing callbacks/jobs
  -> Discord eligibility policy
  -> idempotent add/remove Pandora VIP role job
  -> hourly reconciliation repairs missed or manually drifted role state
```

## Scope

### In Scope

- Add a permanent localized entry route at `/join/pandora`.
- Reuse the existing desired-plan cookie and Devise sign-up/sign-in behavior.
- Preselect Pandora monthly while preserving the annual option and 35% savings.
- Redirect a successful new Pandora Checkout to a dedicated dashboard Discord
  activation page.
- Add Discord OAuth2 authorization-code flow with the exact scopes `identify`
  and `guilds.join`.
- Automatically add an authorized Discord user to guild
  `1505303505915744276`.
- Persist one active Discord identity per Rails user and enforce one active
  Rails connection per Discord identity.
- Grant and revoke Discord role `1526657965828997371` according to Pandora
  eligibility.
- Treat active Stripe Pandora subscriptions and active manual Pandora grants,
  including complimentary grants, as eligible.
- Exclude free trials and subscriptions that are `past_due`, `unpaid`,
  `incomplete_expired`, expired, or fully canceled.
- Preserve VIP through a scheduled cancellation until the paid period ends.
- Restore VIP automatically when payment recovers and Pay reports active paid
  access again.
- Remove VIP before completing an unlink; require unlink completion before a
  different Discord identity can be connected.
- Add event-driven synchronization plus hourly reconciliation.
- Add an activation CTA to the subscription-started email.
- Show a persistent dashboard CTA to existing eligible subscribers who have
  not connected Discord; do not send a bulk migration email.
- Add EN/ES copy for the funnel, Discord states, errors, emails, and Pandora
  benefits: recorded courses, live sessions, new presets, and better support.
- Add minimal ActiveAdmin operational visibility and safe retry/reconciliation
  controls.
- Add deployment configuration, documentation, QA state setup, monitoring, and
  rollback instructions.

### Out of Scope

- No separate Discord.js, Ruby gateway, websocket, or always-online bot
  process.
- No Discord slash commands, message reading, message-content intent, member
  gateway intent, presence intent, or chat moderation.
- No channel/category creation, channel permission synchronization, server
  onboarding configuration, or category ID storage.
- No user kick or ban when Pandora access ends; expired users remain in the
  public Discord community.
- No changes to staff, administrator, `COMMANDER`, `ELITE SNIPER`, or other
  Discord roles.
- No use of the integration-managed `Trading Sniper Panel` role as a subscriber
  role and no need to store its role ID.
- No automatic matching of existing Discord members to Rails users.
- No bulk activation email to existing subscribers in the initial rollout.
- No Discord OAuth access-token or refresh-token persistence.
- No new payment provider, subscription plan, job backend, frontend runtime,
  gem, or Node dependency.
- No production deployment, token rotation, server permission mutation, or
  live customer role mutation without separate operational authorization.

### Fixed Decisions

- **Public invite**: `https://discord.gg/tWJNnu4ArJ`.
- **Discord application/client ID**: `1526565454355632138`.
- **Discord guild ID**: `1505303505915744276`.
- **Pandora VIP role ID**: `1526657965828997371`.
- **Production OAuth redirect**:
  `https://tradingsniperpanel.com/discord/callback`, without a trailing slash.
- **Permissions**: bot has `Manage Roles` and `Create Instant Invite`; the bot
  role is above `Pandora VIP`.
- **Category ownership**: Discord administrators manage the ELITE category and
  staff-role access. Rails manages only `Pandora VIP` for app-linked users.
- **Eligibility**: current paid Stripe Pandora access or an active manual
  Pandora grant; trials do not qualify.
- **Failed renewal**: no extra Discord-only grace period. Remove when paid
  entitlement ends or Pay/Stripe reports a failed/inactive state; re-add on
  recovery.
- **Entry UX**: `/join/pandora`, monthly preselected, explicit plan confirmation
  before Stripe.
- **Activation UX**: dashboard activation plus subscription-started email CTA.
- **Existing subscribers**: dashboard CTA only during initial rollout.
- **Identity policy**: one active Rails user to one Discord identity and one
  active Discord identity to one Rails user.
- **Unlink policy**: remove VIP first; do not clear the persisted identity until
  removal succeeds or Discord confirms the member/role is already absent.
- **Reconciliation**: immediate event jobs plus hourly repair.
- **Public footer**: continues using `SUPPORT_DISCORD_URL`; it is independent of
  VIP integration enablement.

### Assumptions

- Rails 8.0.4, Ruby 3.4.5, Pay 11.4.1, Stripe 18.0.1, Sidekiq 8.1.0,
  sidekiq-cron 2.3.1, RSpec, PostgreSQL, Propshaft, importmap, Stimulus, and
  Tailwind v4 remain unchanged.
- The existing `Billing::ActiveSubscriptionFinder`,
  `Billing::SubscriptionPlanResolver`, and `Billing::SubscriptionStatus` remain
  the basis for paid access instead of creating an independent Discord billing
  interpretation.
- The active Pandora billing tier remains `Billing::PandoraPricing::TIER` with
  monthly and annual keys.
- Discord membership screening may leave a newly added member `pending`; the
  dashboard will explain that the user must accept server rules.
- Category/channel permission sync remains a manual Discord administration
  responsibility. Rails needs no channel IDs when access is role-based.
- The current production application callback route can be added without
  changing the already registered Discord redirect URI.
- A separate Discord test application/server is the preferred staging target.
  If unavailable, provider calls must remain mocked locally and production
  rollout must use a narrowly controlled staff canary after all deterministic
  validation passes.

## Current-System Findings

- `ApplicationController` already resolves locale in this order: explicit URL,
  session, user preference, GeoIP, `Accept-Language`, then English fallback.
- The existing desired-plan signed cookie persists an allowed Pandora price key
  across Devise sign-up/sign-in and redirects to `dashboard/plans`.
- `DashboardsController#checkout` already creates Stripe subscription Checkout
  sessions and centralizes referral/promotion behavior.
- Pay subscription create/update/delete webhooks synchronize local
  `Pay::Subscription` rows, whose `after_commit` callback already enqueues
  subscription-license synchronization.
- Manual subscriptions already enqueue an idempotent synchronization job and
  share the active-subscription finder.
- `BillingNotificationsMailer#subscription_started` is already localized and
  tracked idempotently by invoice/event key.
- Sidekiq and sidekiq-cron are already installed and production uses Sidekiq as
  the Active Job adapter.
- The authenticated surface uses Mosaic; the closest sources for the Discord
  connection page are `mosaic-html/settings.html` and
  `mosaic-html/feedback.html`.
- The footer already conditionally renders `SUPPORT_DISCORD_URL`.
- During planning, the local `.envrc` was confirmed untracked, Git-ignored, and
  mode `0600`. Production and staging secret placement must still be verified
  independently during release preparation.

## Architecture And Contracts

### Entitlement Boundary

`Discord::VipEligibility` will be the only component allowed to answer whether
a user should hold `Pandora VIP`. It will:

1. Resolve the current access source through
   `Billing::ActiveSubscriptionFinder`.
2. Resolve the plan through `Billing::SubscriptionPlanResolver`.
3. Require the resolved tier to equal `Billing::PandoraPricing::TIER`.
4. Require paid-active status through `Billing::SubscriptionStatus` for Stripe.
5. Accept active, non-superseded manual Pandora grants, including complimentary
   grants, because they are already authoritative product access.
6. Return a structured result containing only safe source/status/reason data.

Discord role presence must never grant licenses, courses, downloads, checkout
status, or any other application entitlement.

### Discord Connection Persistence

Create `discord_connections` with one durable row per Rails user. Proposed
columns and constraints:

- `user_id`: required foreign key and unique index.
- `discord_user_id`: nullable string with a unique index for non-null values.
  Store Discord snowflakes as strings to avoid numeric/serialization coupling.
- `discord_username`: nullable current username for user confirmation.
- `discord_global_name`: nullable current display name.
- `linked_at`: nullable timestamp.
- `disconnect_requested_at`: nullable timestamp.
- `disconnected_at`: nullable timestamp.
- `membership_pending`: nullable boolean; `nil` means Discord did not provide a
  definitive state.
- `vip_role_state`: required string constrained to `unknown`, `pending`,
  `granted`, or `removed`.
- `sync_status`: required string constrained to `idle`, `queued`, `syncing`, or
  `failed`.
- `sync_started_at`: nullable timestamp used as a short lease so concurrent jobs
  cannot mutate the same Discord member simultaneously.
- `last_synced_at`: nullable timestamp.
- `last_error_code`: nullable stable internal/provider code; never a token,
  response body, username, email, or raw exception message.
- `last_error_at`: nullable timestamp.
- Rails timestamps.

Coherence rules:

- A non-null `discord_user_id` requires `linked_at`.
- Successful unlink clears Discord identity/profile fields, releases the unique
  identity for a future link, sets `disconnected_at`, and records role state as
  removed.
- A pending/failed unlink retains the Discord identity so Rails does not lose
  the ability to retry role removal.
- OAuth access and refresh tokens are used only in memory during the callback
  and are never written to PostgreSQL, logs, HTML, cookies, jobs, or telemetry.

### Discord HTTP Boundary

Use a small `Discord::Client` built on Ruby/Rails-native HTTP support with an
injectable transport. Do not add a Discord SDK or rely on Faraday as an
undeclared transitive dependency.

Required operations:

- Exchange authorization code at `/api/v10/oauth2/token` using
  `application/x-www-form-urlencoded`.
- Fetch `/api/v10/users/@me` with the short-lived Bearer token.
- Add member with `PUT /api/v10/guilds/{guild_id}/members/{discord_user_id}`
  using the bot token and OAuth `access_token`.
- Add VIP with
  `PUT /api/v10/guilds/{guild_id}/members/{discord_user_id}/roles/{role_id}`.
- Remove VIP with
  `DELETE /api/v10/guilds/{guild_id}/members/{discord_user_id}/roles/{role_id}`.

Client behavior:

- Explicit connect/read/write timeouts.
- Parse only expected JSON fields and discard token responses after use.
- Treat add-member `201` and already-member `204` as success.
- Treat role add/remove `204` as success.
- Treat member/role absence during removal as an idempotent successful removal.
- Honor Discord `Retry-After` on `429`; do not hard-code rate limits.
- Classify `401`, `403`, `404`, `429`, malformed response, timeout, and provider
  `5xx` separately.
- Retry only idempotent role operations. The OAuth callback returns a localized
  retryable error rather than persisting tokens for later replay.
- Never log authorization codes, client secrets, bot tokens, access tokens,
  refresh tokens, raw Discord responses, or request authorization headers.

### OAuth And Identity Security

- Generate a cryptographically random, one-time `state` nonce at authorization
  start.
- Store only the nonce, intended local return path, locale, and expiry in the
  server session; never accept an arbitrary external return URL.
- Validate state with constant-time comparison, consume it once, and reject
  missing, expired, replayed, or mismatched callbacks.
- Require a signed-in Rails user to start and complete linking.
- Request exactly `identify guilds.join`; do not request Discord email or guild
  listing scopes.
- Reject a Discord identity already linked to another Rails user using both a
  service-level check and database uniqueness.
- If a user already has a different Discord identity, require completed unlink
  before starting a new connection.
- If Discord returns `pending`, persist it and show membership-screening
  guidance. When Discord returns `204` for an existing member, show generic
  guidance because pending status is unknown.

### Role Synchronization And Concurrency

- `Discord::SyncVipRole` recomputes eligibility at execution time; job arguments
  contain only the connection ID.
- A short persisted sync lease prevents concurrent add/remove operations for
  the same connection. Stale leases are reclaimable after a bounded timeout.
- The service chooses add or remove from current eligibility, never from stale
  webhook payloads or browser input.
- Provider calls happen outside database transactions. State is updated only if
  the connection still points to the same Discord user after the call.
- Pay subscription callbacks, manual subscription sync completion, OAuth link,
  explicit dashboard retry, and hourly reconciliation enqueue the same
  idempotent job.
- Reconciliation iterates connected rows in batches and enqueues per-connection
  jobs; it does not enumerate the entire Discord guild.
- For app-linked users, reconciliation repairs both missing VIP roles for
  eligible users and unauthorized VIP roles for ineligible users.
- The app never touches other Discord roles and never removes `Pandora VIP`
  from unlinked Discord members because it has no authoritative Rails identity
  mapping for them.

### Feature Flag And Failure Mode

Add `DISCORD_INTEGRATION_ENABLED`, defaulting to `false`.

- When false, the public footer invite continues working.
- VIP OAuth routes redirect safely with a localized unavailable message.
- Dashboard activation UI and email CTA are hidden or fall back to existing
  billing behavior.
- Event hooks do not enqueue provider jobs and reconciliation exits without
  external calls.
- When true, boot must fail with an actionable, secret-free configuration error
  if any required Discord variable is missing.
- Disabling the flag stops new automation but does not automatically remove
  roles already granted; the rollout runbook must cover deliberate linked-role
  cleanup when required.

## Named Resources

### Project Instructions And Source References

- `AGENTS.md`
- `docs/database_model_reference.md`
- `docs/pandora_subscription_rollout_runbook.md`
- `.agents/skills/mosaic-html-rails/SKILL.md`
- `mosaic-html/settings.html`
- `mosaic-html/feedback.html`

### Existing Implementation Files Expected To Change

- `.envrc.example`
- `README.md`
- `config/routes.rb`
- `config/initializers/sidekiq_cron.rb`
- `app/models/user.rb`
- `app/models/concerns/licenses/pay_subscription_callbacks.rb`
- `app/jobs/manual_subscriptions/sync_job.rb`
- `app/controllers/dashboards_controller.rb`
- `app/views/dashboards/plans.html.erb`
- `app/views/dashboards/show.html.erb`
- `app/views/layouts/dashboard.html.erb`
- `app/mailers/billing_notifications_mailer.rb`
- `app/views/billing_notifications_mailer/subscription_started.html.erb`
- `app/views/billing_notifications_mailer/subscription_started.text.erb`
- `config/locales/dashboard.en.yml`
- `config/locales/dashboard.es.yml`
- `config/locales/en.yml`
- `config/locales/es.yml`
- `docs/database_model_reference.md`
- `docs/pandora_subscription_rollout_runbook.md`

### New Implementation Files Expected

- `db/migrate/*_create_discord_connections.rb`
- `app/models/discord_connection.rb`
- `config/initializers/discord.rb`
- `app/services/discord/client.rb`
- `app/services/discord/errors.rb`
- `app/services/discord/oauth_state.rb`
- `app/services/discord/vip_eligibility.rb`
- `app/services/discord/link_account.rb`
- `app/services/discord/request_unlink.rb`
- `app/services/discord/sync_vip_role.rb`
- `app/jobs/discord/sync_vip_role_job.rb`
- `app/jobs/discord/reconcile_vip_roles_job.rb`
- `app/controllers/pandora_joins_controller.rb`
- `app/controllers/discord/oauth_callbacks_controller.rb`
- `app/controllers/dashboard/discord_connections_controller.rb`
- `app/services/dashboard/discord_presenter.rb`
- `app/views/dashboard/discord_connections/show.html.erb`
- `app/views/dashboards/shared/_discord_vip_card.html.erb`
- `app/admin/discord_connections.rb`
- `lib/tasks/discord.rake`
- `script/discord_vip_manual_qa_setup.rb`
- `docs/discord_vip_rollout_runbook.md`

Exact migration timestamp and any tiny shared partial names are chosen during
implementation, but the domain ownership and file boundaries above are fixed.

### New And Updated Tests Expected

- `spec/factories/discord_connections.rb`
- `spec/models/discord_connection_spec.rb`
- `spec/services/discord/client_spec.rb`
- `spec/services/discord/oauth_state_spec.rb`
- `spec/services/discord/vip_eligibility_spec.rb`
- `spec/services/discord/link_account_spec.rb`
- `spec/services/discord/request_unlink_spec.rb`
- `spec/services/discord/sync_vip_role_spec.rb`
- `spec/jobs/discord/sync_vip_role_job_spec.rb`
- `spec/jobs/discord/reconcile_vip_roles_job_spec.rb`
- `spec/requests/pandora_joins_spec.rb`
- `spec/requests/discord_oauth_spec.rb`
- `spec/requests/dashboard_discord_connections_spec.rb`
- `spec/requests/discord_admin_spec.rb`
- `spec/models/pay_subscription_callbacks_spec.rb`
- `spec/jobs/manual_subscriptions/sync_job_spec.rb`
- `spec/requests/subscription_upgrade_spec.rb`
- `spec/requests/plan_persistence_spec.rb`
- `spec/mailers/billing_notifications_mailer_spec.rb`
- `spec/requests/landing_template_locale_branding_spec.rb`

### External Documentation

- Discord OAuth2 and authorization-code/state guidance:
  <https://discord.com/developers/docs/topics/oauth2>
- Discord Add Guild Member:
  <https://discord.com/developers/docs/resources/guild#add-guild-member>
- Discord Add Guild Member Role:
  <https://discord.com/developers/docs/resources/guild#add-guild-member-role>
- Discord Remove Guild Member Role:
  <https://discord.com/developers/docs/resources/guild#remove-guild-member-role>
- Discord role hierarchy:
  <https://discord.com/developers/docs/topics/permissions#permission-hierarchy>
- Discord rate limits:
  <https://discord.com/developers/docs/topics/rate-limits>
- Stripe subscription webhooks:
  <https://docs.stripe.com/billing/subscriptions/webhooks>
- Stripe webhook signature, duplicate, ordering, and fast-response guidance:
  <https://docs.stripe.com/webhooks>
- Installed Pay behavior: `Gemfile.lock` and local Pay 11.4.1 source, especially
  `Pay::Subscription.active`, Stripe subscription sync webhooks, and status
  handling.

### Operational Resources

- `SUPPORT_DISCORD_URL`
- `DISCORD_CLIENT_ID`
- `DISCORD_CLIENT_SECRET`
- `DISCORD_BOT_TOKEN`
- `DISCORD_GUILD_ID`
- `DISCORD_VIP_ROLE_ID`
- `DISCORD_REDIRECT_URI`
- New `DISCORD_INTEGRATION_ENABLED`
- Sidekiq production and staging workers.
- Stripe test-mode webhook delivery and Pay synchronization.
- Separate Discord staging/test application, guild, bot role, and VIP role.
- Existing deployment scripts that render `.envrc` to
  `/etc/tradingsniperpanel/{production,staging}.env`.

## Prerequisites

- Confirm production `.envrc` and staging `.envrc` remain untracked and mode
  `0600`; generated systemd environment files remain `0640`.
- Never copy real Discord credentials into `.envrc.example`, plan artifacts,
  tests, screenshots, shell arguments, logs, or external research tools.
- Keep production `DISCORD_INTEGRATION_ENABLED=false` until the release gate.
- Register an exact callback URI for each environment. Production must remain
  `https://tradingsniperpanel.com/discord/callback`; staging must not send a
  callback to production.
- Prefer a separate Discord application/test guild for staging. Its bot role
  must be above its test VIP role and have only the two required elevated
  permissions.
- Confirm Stripe test-mode webhooks and Sidekiq are healthy in staging.
- Record a database backup and pre-deploy commit before the migration reaches
  production.
- Confirm ELITE category channels are synchronized with their category in
  Discord. This is a release checklist item, not application behavior.
- Confirm staff will continue using existing staff roles for manual ELITE
  access rather than assigning `Pandora VIP` as an undocumented exception.

## Sprint 1: Discord Configuration, Persistence, And Provider Boundary

**Goal**: Add a disabled-by-default, testable Discord integration foundation
with safe persistence, explicit configuration, current Pandora eligibility,
and no user-visible behavior or live role mutation.

**Dependencies**: Prerequisites above; no prior sprint.

**Tracked scope**:
`db/migrate/**`, `db/schema.rb`, `app/models/discord_connection.rb`,
`app/models/user.rb`, `config/initializers/discord.rb`, `.envrc.example`,
`app/services/discord/{client,errors,vip_eligibility}.rb`, factories and focused
model/service specs.

**Commit**: `feat: add Discord connection and API foundation`

**Demo/Validation**:

- The app boots with Discord disabled and no Discord secrets.
- Enabling the feature with a missing required variable fails with a safe,
  actionable configuration error.
- A Discord connection can be created, disconnected, and constrained without
  any provider call.
- Provider client specs cover OAuth exchange, identity lookup, guild join,
  role add/remove, timeout, malformed response, `401`, `403`, `404`, `429`, and
  `5xx` behavior using an injected fake transport.
- Eligibility specs cover Stripe active, scheduled cancellation before/after
  period end, trial, `past_due`, `unpaid`, payment recovery, active manual,
  complimentary manual, superseded manual, wrong tier, and no subscription.

**Rollback point**: The pre-Sprint 1 commit. The additive table may remain
unused during a code rollback; the feature flag remains false and no Discord
state has been mutated.

### Task 1.1: Add The Feature-Gated Configuration Contract

- **Location**: `config/initializers/discord.rb`, `.envrc.example`.
- **Description**:
  - Add `DISCORD_INTEGRATION_ENABLED=false` to the example environment.
  - Read all Discord IDs as strings.
  - Normalize the redirect URI and public invite without logging values.
  - Validate required keys only when enabled.
  - Expose a small immutable configuration object under the Discord domain.
  - Keep `SUPPORT_DISCORD_URL` independent so the footer works when VIP
    automation is disabled.
- **Dependencies**: None.
- **Acceptance criteria**:
  - Disabled development/test boots without Discord secrets.
  - Enabled boot fails closed for each missing variable without echoing any
    configured secret.
  - Redirect URI comparison preserves the exact registered production URI.
- **Validation**:
  - `bin/rails runner 'puts Rails.application.config.x.discord.enabled?'`
    under disabled test configuration.
  - Focused initializer/configuration specs without printing values.
- **Rollback**: Revert initializer and example-variable additions; keep the
  integration disabled.

### Task 1.2: Create The Discord Connection Model And Constraints

- **Location**: `db/migrate/*_create_discord_connections.rb`, `db/schema.rb`,
  `app/models/discord_connection.rb`, `app/models/user.rb`,
  `spec/factories/discord_connections.rb`,
  `spec/models/discord_connection_spec.rb`.
- **Description**:
  - Add the proposed fields, foreign key, partial unique Discord ID index,
    unique user index, status check constraints, and coherence constraint.
  - Add `User#discord_connection` with intentional dependent behavior.
  - Keep provider IDs as strings and do not add token columns.
  - Add scopes for connected, disconnect-pending, failed, and reconciliation
    batches.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - One user cannot have multiple rows.
  - One non-null Discord ID cannot belong to multiple rows.
  - A disconnected row can later connect a different Discord ID.
  - Invalid status or identity/timestamp combinations fail at model and
    database levels.
  - No OAuth or bot credential field exists in the schema.
- **Validation**:
  - `rtk test bundle exec rspec spec/models/discord_connection_spec.rb`
  - `RAILS_ENV=test bin/rails db:migrate`
  - Review `db/schema.rb` indexes and check constraints.
- **Rollback**: Before production data exists, migration rollback is safe in a
  disposable environment. After connections exist, leave the additive table
  during code rollback instead of dropping user linkage data.

### Task 1.3: Implement The Discord REST Client

- **Location**: `app/services/discord/client.rb`,
  `app/services/discord/errors.rb`, `spec/services/discord/client_spec.rb`.
- **Description**:
  - Implement the five required OAuth/guild/role methods against API v10.
  - Inject transport/configuration/clock/logger for deterministic tests.
  - Redact all authentication material.
  - Normalize provider errors into stable internal exceptions with safe codes.
  - Preserve `Retry-After` as structured data for job scheduling.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - Request method, path, authentication scheme, form encoding, and success
    codes match official Discord documentation.
  - No error exposes response authorization headers or token bodies.
  - Role removal is idempotent when the member/role is already absent.
- **Validation**:
  - `rtk test bundle exec rspec spec/services/discord/client_spec.rb`
  - Manual review against the named Discord OAuth, guild, permissions, and rate
    limit documentation.
- **Rollback**: Remove the unused client and errors; no external state exists.

### Task 1.4: Centralize Pandora VIP Eligibility

- **Location**: `app/services/discord/vip_eligibility.rb`,
  `spec/services/discord/vip_eligibility_spec.rb`.
- **Description**:
  - Compose existing billing services rather than duplicating Pay status rules.
  - Return a structured result such as `eligible?`, `source`, `plan_key`, and
    safe reason code.
  - Explicitly exclude trials and failed/inactive Stripe states.
  - Explicitly include active manual Pandora grants regardless of paid versus
    complimentary status.
- **Dependencies**: Current billing services and Task 1.2.
- **Acceptance criteria**:
  - Every fixed eligibility decision has a focused example.
  - Wrong-tier and historical/retired plans cannot grant Discord VIP.
  - No Discord role state participates in the decision.
- **Validation**:
  - `rtk test bundle exec rspec spec/services/discord/vip_eligibility_spec.rb`
- **Rollback**: Remove the unused policy; billing behavior remains unchanged.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] Focused migration, model, client, configuration, and eligibility checks
      pass and evidence is recorded.
- [ ] Migration is reviewed as additive, indexed, constrained, reversible in a
      disposable environment, and compatible with the old running process.
- [ ] Secret/log review confirms no real values or token-shaped fixtures.
- [ ] Residual risks are documented.
- [ ] Exactly one Sprint 1 commit is created with the proposed message.
- [ ] The pre-Sprint 2 rollback point is recorded.
- [ ] Sprint 2 has not started before this gate completes.

## Sprint 2: Idempotent VIP Role Synchronization And Operations

**Goal**: Make Rails automatically converge the `Pandora VIP` role for an
existing connection fixture from current billing state, including Pay/manual
events, failure recovery, hourly reconciliation, and operational visibility.

**Dependencies**: Sprint 1 gate complete; feature remains disabled by default.

**Tracked scope**:
`app/services/discord/sync_vip_role.rb`, `app/jobs/discord/**`,
`app/models/concerns/licenses/pay_subscription_callbacks.rb`,
`app/jobs/manual_subscriptions/sync_job.rb`,
`config/initializers/sidekiq_cron.rb`, `app/admin/discord_connections.rb`,
`lib/tasks/discord.rake`, and focused service/job/callback/admin specs.

**Commit**: `feat: synchronize Pandora VIP Discord access`

**Demo/Validation**:

- An eligible connected fixture receives one idempotent add-role call.
- An ineligible connected fixture receives one idempotent remove-role call.
- Scheduled cancellation keeps the role until paid access ends.
- Renewal failure removes it according to the fixed policy; payment recovery
  re-adds it.
- Manual grant creation/expiry/supersession converges correctly.
- Two simultaneous jobs for one connection cannot issue conflicting provider
  operations.
- Hourly reconciliation enqueues connected rows in batches and exits when the
  feature is disabled.

**Rollback point**: Sprint 1 commit with `DISCORD_INTEGRATION_ENABLED=false`.
If live roles were changed in a non-production test guild, run the confirmed
linked-role cleanup task before reverting.

### Task 2.1: Implement The Leased, Idempotent Role Sync Service

- **Location**: `app/services/discord/sync_vip_role.rb`,
  `spec/services/discord/sync_vip_role_spec.rb`.
- **Description**:
  - Claim a short sync lease atomically; do not keep a database transaction open
    during Discord HTTP.
  - Reload connection and eligibility before selecting add/remove.
  - Record queued/syncing/granted/removed/failed states with safe timestamps and
    stable error codes.
  - After the provider response, update only if the row still refers to the
    same Discord identity.
  - Treat absent member/role on removal as success.
  - Mark `401`/`403` as operational failures without endless immediate retry.
  - Return rate-limit delay to the job and retry transient timeout/`5xx`
    failures safely.
- **Dependencies**: Sprint 1 client, model, and eligibility policy.
- **Acceptance criteria**:
  - Repeated add/remove calls converge without duplicate application state.
  - Stale leases can be reclaimed; live leases prevent concurrency.
  - A subscription status change during an in-flight operation is corrected by
    a follow-up enqueue/reconciliation.
  - Logs contain connection IDs and safe error codes only.
- **Validation**:
  - `rtk test bundle exec rspec spec/services/discord/sync_vip_role_spec.rb`
- **Rollback**: Disable the feature, allow in-flight jobs to finish, and revert
  the service. Use the cleanup task only when role access must be revoked.

### Task 2.2: Add Sync And Hourly Reconciliation Jobs

- **Location**: `app/jobs/discord/sync_vip_role_job.rb`,
  `app/jobs/discord/reconcile_vip_roles_job.rb`,
  `config/initializers/sidekiq_cron.rb`, `spec/jobs/discord/**`.
- **Description**:
  - Add one per-connection job with retry behavior mapped to safe provider
    categories.
  - Re-enqueue according to Discord `Retry-After` for `429` rather than sleep in
    a worker.
  - Add an hourly cron entry that batches connected/pending rows and enqueues
    per-connection jobs.
  - Preserve the existing daily license-expiration cron entry.
  - Make both jobs no-op when integration is disabled or the connection no
    longer has a Discord ID.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - No job argument contains OAuth data, email, username, or provider tokens.
  - Reconciliation does not issue provider calls inline and does not enumerate
    the guild.
  - The existing license cron remains unchanged.
- **Validation**:
  - `rtk test bundle exec rspec spec/jobs/discord`
  - Boot Sidekiq configuration in test and assert both cron definitions.
- **Rollback**: Remove the new cron entry and jobs after disabling the feature;
  keep the existing license cron.

### Task 2.3: Connect Billing And Manual Events To The Same Sync Job

- **Location**:
  `app/models/concerns/licenses/pay_subscription_callbacks.rb`,
  `app/jobs/manual_subscriptions/sync_job.rb`,
  `spec/models/pay_subscription_callbacks_spec.rb`,
  `spec/jobs/manual_subscriptions/sync_job_spec.rb`.
- **Description**:
  - After Pay commits and existing license sync enqueueing, enqueue Discord sync
    only when a current connection exists and the feature is enabled.
  - After manual subscription synchronization completes, enqueue the same
    Discord job for the user's connection.
  - Do not derive desired role state from the webhook event; the job always
    recomputes current authoritative eligibility.
  - Preserve existing duplicate-subscription cancellation and license behavior.
- **Dependencies**: Task 2.2.
- **Acceptance criteria**:
  - Created, updated, deleted, canceled-at-period-end, failed, recovered, and
    manual grant events reach the same idempotent job.
  - Existing license sync tests and behavior remain green.
  - Duplicate/out-of-order callbacks cannot grant an ineligible role.
- **Validation**:
  - `rtk test bundle exec rspec spec/models/pay_subscription_callbacks_spec.rb spec/jobs/manual_subscriptions/sync_job_spec.rb spec/services/licenses/subscription_license_sync_spec.rb spec/services/licenses/manual_subscription_sync_spec.rb`
- **Rollback**: Remove only the Discord enqueue hooks; preserve all existing
  Pay/manual license callbacks.

### Task 2.4: Add Operational Visibility And Safe Maintenance Tasks

- **Location**: `app/admin/discord_connections.rb`, `lib/tasks/discord.rake`,
  `spec/requests/discord_admin_spec.rb`.
- **Description**:
  - Add read-only connection status, eligibility, last sync, membership pending,
    and safe error code visibility for admins.
  - Add an authorized manual resync action; do not expose tokens or raw provider
    responses.
  - Add non-mutating `discord:vip:audit` and enqueue-only
    `discord:vip:reconcile` tasks.
  - Add a deliberately guarded linked-role cleanup task requiring an exact
    confirmation phrase for rollback. It may remove only `Pandora VIP` from
    currently linked Discord IDs and must never kick members or alter staff
    roles.
- **Dependencies**: Tasks 2.1-2.3.
- **Acceptance criteria**:
  - Traders cannot access admin status or maintenance actions.
  - Admin output uses counts, Rails IDs, timestamps, and safe codes only.
  - Cleanup refuses to run without the exact confirmation phrase.
- **Validation**:
  - `rtk test bundle exec rspec spec/requests/discord_admin_spec.rb`
  - `bin/rails discord:vip:audit` with fake/local rows and the feature disabled.
- **Rollback**: Remove admin/task entry points; disabling the integration stops
  new provider work.

### Sprint 2 Gate

- [ ] All Sprint 2 tasks complete.
- [ ] Role sync, concurrency, rate-limit, callback, reconciliation, and admin
      validation passes and evidence is recorded.
- [ ] No live production Discord role was mutated.
- [ ] Existing license synchronization behavior remains green.
- [ ] Residual risks are documented.
- [ ] Exactly one Sprint 2 commit is created with the proposed message.
- [ ] The pre-Sprint 3 rollback point is recorded.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Secure Discord OAuth Linking, Joining, And Unlinking

**Goal**: Let a signed-in user securely connect one Discord identity, join the
configured guild, receive asynchronous VIP synchronization, view connection
state, retry failures, and unlink without leaving VIP on the old account.

**Dependencies**: Sprint 2 gate complete; a test Discord application/guild is
required for the live staging demo, but deterministic tests use an injected
fake client.

**Tracked scope**:
`config/routes.rb`, `app/services/discord/{oauth_state,link_account,request_unlink}.rb`,
`app/controllers/discord/oauth_callbacks_controller.rb`,
`app/controllers/dashboard/discord_connections_controller.rb`,
`app/services/dashboard/discord_presenter.rb`,
`app/views/dashboard/discord_connections/show.html.erb`, localized dashboard
copy, and OAuth/link/unlink request/service specs.

**Commit**: `feat: add secure Discord account linking`

**Demo/Validation**:

- A signed-in eligible staging user starts OAuth, grants `identify` and
  `guilds.join`, joins the test guild, returns to the dashboard, and receives
  the test VIP role through Sidekiq.
- A Discord account already linked elsewhere is rejected without overwriting
  either row.
- State mismatch, replay, expiry, denial, token exchange failure, identity
  failure, and guild-join failure produce localized recoverable states.
- Unlink enters pending state, removes VIP, clears the current identity only
  after success, and then allows a different Discord identity to connect.

**Rollback point**: Sprint 2 commit with the feature disabled. Preserve
`discord_connections` data for later retry/audit rather than deleting identity
history during a code rollback.

### Task 3.1: Add Localized Routes And One-Time OAuth State

- **Location**: `config/routes.rb`, `app/services/discord/oauth_state.rb`,
  `spec/services/discord/oauth_state_spec.rb`.
- **Description**:
  - Add authenticated dashboard routes for show, authorize, retry sync, and
    unlink inside the optional locale scope.
  - Add the exact non-localized callback route `/discord/callback` outside the
    locale scope so it matches the registered URI.
  - Generate, store, expire, consume, and constant-time validate one-time state.
  - Preserve locale and a fixed internal return target through the session.
- **Dependencies**: Sprint 1 configuration.
- **Acceptance criteria**:
  - The callback URI generated by Rails exactly equals the configured URI.
  - State cannot be replayed and cannot redirect outside the application.
  - Anonymous users cannot initiate or complete linking.
- **Validation**:
  - `rtk test bundle exec rspec spec/services/discord/oauth_state_spec.rb`
  - `bin/rails routes | rg 'join|discord'`
- **Rollback**: Remove new routes and state service; no billing route changes.

### Task 3.2: Implement OAuth Callback, Identity Linking, And Guild Join

- **Location**: `app/services/discord/link_account.rb`,
  `app/controllers/discord/oauth_callbacks_controller.rb`,
  `spec/services/discord/link_account_spec.rb`,
  `spec/requests/discord_oauth_spec.rb`.
- **Description**:
  - Exchange the code, fetch Discord identity, enforce one-to-one ownership,
    and call Add Guild Member synchronously with short timeouts.
  - Persist only Discord identity/profile fields and membership-pending state.
  - Discard access/refresh tokens immediately after join.
  - Enqueue role sync only after the connection commits.
  - Reject account replacement until the previous connection is fully
    unlinked.
  - Treat an already-present guild member as successful.
- **Dependencies**: Task 3.1 and Sprint 1 client/model.
- **Acceptance criteria**:
  - No provider token appears in PostgreSQL, Active Job arguments, logs, flash,
    rendered HTML, cookies, or exceptions.
  - Database uniqueness handles concurrent duplicate linking safely.
  - Failed guild join does not create a falsely connected record.
  - Callback denial and provider errors return to the Discord dashboard with a
    localized retry path.
- **Validation**:
  - `rtk test bundle exec rspec spec/services/discord/link_account_spec.rb spec/requests/discord_oauth_spec.rb`
  - Search changed code/test output for token fields and authorization headers.
- **Rollback**: Disable integration and remove OAuth entry routes; retain rows
  for users already linked until explicit cleanup/unlink.

### Task 3.3: Implement Safe Unlink And Manual Retry

- **Location**: `app/services/discord/request_unlink.rb`,
  `app/controllers/dashboard/discord_connections_controller.rb`,
  `spec/services/discord/request_unlink_spec.rb`,
  `spec/requests/dashboard_discord_connections_spec.rb`.
- **Description**:
  - Mark unlink requested and enqueue a removal operation.
  - Clear Discord identity only after role removal succeeds or absence is
    confirmed.
  - Retain safe failed state for `401`/`403`/timeout so support can retry.
  - Add an explicit dashboard retry action that only enqueues the current
    connection.
  - Protect unlink and retry with Devise authentication and CSRF-safe non-GET
    routes.
- **Dependencies**: Task 3.2 and Sprint 2 sync service.
- **Acceptance criteria**:
  - Unlink does not leave an old connected identity silently holding VIP.
  - Double unlink and double retry are idempotent.
  - A new Discord account cannot connect until old-role removal completes.
- **Validation**:
  - `rtk test bundle exec rspec spec/services/discord/request_unlink_spec.rb spec/requests/dashboard_discord_connections_spec.rb`
- **Rollback**: Disable new unlink requests; operations already queued may
  finish. Preserve failed rows for operational repair.

### Task 3.4: Add The Functional Mosaic Connection Page

- **Location**: `app/services/dashboard/discord_presenter.rb`,
  `app/views/dashboard/discord_connections/show.html.erb`,
  `config/locales/dashboard.en.yml`, `config/locales/dashboard.es.yml`.
- **Description**:
  - Start from the closest comment-bounded panel in
    `mosaic-html/settings.html`/`feedback.html`.
  - Preserve Mosaic panel structure, comments, utility stacks, dark mode, focus
    behavior, and responsive rhythm.
  - Present ineligible, eligible-unlinked, OAuth error, pending join, queued
    sync, granted, removed, failed, disconnecting, and membership-screening
    guidance states.
  - Show only safe Discord username/display name and connection state.
  - Provide Connect, Retry, Open Discord, View Plans, Contact Support, and
    Disconnect actions according to state.
- **Dependencies**: Tasks 3.2-3.3.
- **Acceptance criteria**:
  - Every state has EN/ES copy and a useful recovery path.
  - No secret, OAuth code, access token, raw provider error, or hidden server
    identifier is rendered.
  - Membership-screening guidance explains that users may need to accept rules
    before seeing ELITE.
- **Validation**:
  - Focused request specs for all presenter/page states.
  - `npm run build:css`
  - Manual source-parity review against the selected Mosaic block.
- **Rollback**: Remove the dashboard route/view after disabling integration;
  preserve connection rows and role state.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks complete.
- [ ] OAuth state, ownership, link, guild join, unlink, retry, and page-state
      validation passes and evidence is recorded.
- [ ] A test-guild live OAuth canary passes when a separate test app is
      available; otherwise the missing live-provider check is recorded as a
      release blocker, not silently skipped.
- [ ] No OAuth access/refresh token is persisted or logged.
- [ ] Browser QA status for the functional connection page is recorded.
- [ ] Residual risks are documented.
- [ ] Exactly one Sprint 3 commit is created with the proposed message.
- [ ] The pre-Sprint 4 rollback point is recorded.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Localized Conversion Funnel, Dashboard Activation, And Email

**Goal**: Deliver the complete low-friction user journey from the public
Discord link through localized sign-up, Pandora confirmation, Stripe Checkout,
dashboard activation, and email fallback, while keeping existing subscribers
visible without bulk email.

**Dependencies**: Sprint 3 gate complete; current Neon marketing and Mosaic
dashboard boundaries remain intact.

**Tracked scope**:
`config/routes.rb`, `app/controllers/pandora_joins_controller.rb`,
`app/controllers/dashboards_controller.rb`, `app/views/dashboards/{plans,show}.html.erb`,
`app/views/dashboards/shared/_discord_vip_card.html.erb`,
`app/views/layouts/dashboard.html.erb`, billing mailer files, EN/ES locale files,
and related request/mailer tests.

**Commit**: `feat: add localized Pandora Discord onboarding`

**Demo/Validation**:

- An anonymous request to `/join/pandora` resolves EN/ES with the existing
  locale policy, stores only the valid monthly Pandora hint, and reaches sign
  up.
- After sign-up/sign-in, the plans page opens monthly with annual still
  available and all Discord VIP benefits visible.
- New Stripe Checkout success returns to the Discord activation page.
- Existing active subscribers see the dashboard activation card until linked.
- Subscription-started email links to the localized activation page when the
  integration is enabled and retains existing billing behavior when disabled.

**Rollback point**: Sprint 3 commit. Turning the feature flag off restores the
existing billing email CTA and hides funnel-specific Discord activation without
removing the public footer invite.

### Task 4.1: Add The Locale-Aware `/join/pandora` Entry

- **Location**: `config/routes.rb`,
  `app/controllers/pandora_joins_controller.rb`,
  `spec/requests/pandora_joins_spec.rb`,
  `spec/requests/plan_persistence_spec.rb`.
- **Description**:
  - Add the route inside the optional locale scope so `/join/pandora` invokes
    the existing GeoIP/session/user/header resolution and `/es/join/pandora`
    remains explicit.
  - For an anonymous user, redirect to localized sign-up with the valid monthly
    Pandora price key so existing signed-cookie persistence handles the rest.
  - For a signed-in ineligible user, redirect to plans with monthly selected.
  - For an eligible user, redirect directly to dashboard Discord activation.
  - For a connected eligible user, show current Discord status rather than
    restarting OAuth.
- **Dependencies**: Existing plan persistence and Sprint 3 dashboard route.
- **Acceptance criteria**:
  - Unknown/retired plan values cannot be injected through the shared route.
  - Locale and referral cookie behavior are preserved.
  - The route never sends a user directly to Stripe without plan confirmation.
- **Validation**:
  - `rtk test bundle exec rspec spec/requests/pandora_joins_spec.rb spec/requests/plan_persistence_spec.rb spec/services/locale_resolver_spec.rb`
- **Rollback**: Remove the entry route/controller; existing home pricing links
  remain unchanged.

### Task 4.2: Redirect Successful New Checkout To Discord Activation

- **Location**: `app/controllers/dashboards_controller.rb`,
  `spec/requests/subscription_upgrade_spec.rb`.
- **Description**:
  - Change only new subscription Checkout success URL to the localized
    dashboard Discord page when enabled.
  - Preserve cancel URL, promotion/referral application, client reference,
    subscription metadata, plan changes, downgrade schedules, and error paths.
  - Do not trust a success redirect as proof of payment; the page reads current
    Pay/manual eligibility and can display a short activation-pending state
    until webhooks arrive.
  - Clear desired-plan state only after authoritative access is present.
- **Dependencies**: Task 4.1 and Sprint 3 page.
- **Acceptance criteria**:
  - Stripe Checkout params change only in the success destination.
  - A forged `checkout=success` query cannot grant eligibility or Discord role.
  - Disabled integration keeps the current dashboard success URL.
- **Validation**:
  - `rtk test bundle exec rspec spec/requests/subscription_upgrade_spec.rb`
- **Rollback**: Restore the existing dashboard success URL; role automation can
  remain enabled independently.

### Task 4.3: Add Persistent Dashboard Activation And Navigation

- **Location**: `app/views/dashboards/show.html.erb`,
  `app/views/dashboards/shared/_discord_vip_card.html.erb`,
  `app/views/layouts/dashboard.html.erb`,
  `app/services/dashboard/main_presenter.rb` or the smallest established
  presenter extension, `config/locales/dashboard.en.yml`,
  `config/locales/dashboard.es.yml`, dashboard request specs.
- **Description**:
  - Add a Mosaic-aligned Discord activation card for eligible users who are
    unlinked, pending, or failed.
  - Add `Discord VIP` under the existing Settings navigation group instead of
    introducing a new template family or broad sidebar redesign.
  - Keep the card unobtrusive or summarized after successful role grant.
  - Show the public Discord invite to ineligible/expired users without implying
    VIP access.
  - Preserve responsive sidebar hooks, keyboard focus, dark mode, and EN/ES
    length.
- **Dependencies**: Sprint 3 presenter and page.
- **Acceptance criteria**:
  - Existing active subscribers discover the connection without email.
  - Expired users see a renewal CTA and public-community link, not a VIP claim.
  - The card does not render for disabled integration.
- **Validation**:
  - Focused dashboard/sidebar/request specs.
  - `npm run build:css`
- **Rollback**: Remove the card/navigation child; the dedicated route can remain
  reachable from email or direct link.

### Task 4.4: Advertise Discord VIP Benefits On Pandora Plans

- **Location**: `app/views/dashboards/plans.html.erb`,
  `config/locales/dashboard.en.yml`, `config/locales/dashboard.es.yml`, relevant
  pricing/request specs.
- **Description**:
  - Add recorded courses, live sessions, new presets, and better support to the
    Pandora included-feature copy in both languages.
  - Keep current monthly/annual pricing, refund notice, promotion behavior, and
    single-card layout.
  - Do not claim that a Discord role itself grants application courses or
    licenses.
- **Dependencies**: None beyond current catalog.
- **Acceptance criteria**:
  - Monthly remains preselected for the shared-link journey.
  - Annual discount remains visible and selectable.
  - Copy fits mobile and Spanish layouts without overflow.
- **Validation**:
  - Pricing request specs and locale-key parity checks.
  - `npm run build:css`
- **Rollback**: Revert copy only; billing catalog remains unchanged.

### Task 4.5: Add The Subscription-Started Email Activation CTA

- **Location**: `app/mailers/billing_notifications_mailer.rb`,
  `app/views/billing_notifications_mailer/subscription_started.html.erb`,
  `app/views/billing_notifications_mailer/subscription_started.text.erb`,
  `config/locales/en.yml`, `config/locales/es.yml`,
  `spec/mailers/billing_notifications_mailer_spec.rb`.
- **Description**:
  - When enabled, make Discord activation the primary CTA and retain invoice
    access as the secondary action.
  - Keep localization based on the user's stored preference and preserve the
    existing idempotent subscription-started delivery tracker.
  - When disabled, preserve the existing billing CTA.
  - Do not send any one-time bulk email to existing subscribers.
- **Dependencies**: Sprint 3 dashboard route.
- **Acceptance criteria**:
  - HTML and text variants contain localized activation links only when enabled.
  - No bot token, client secret, OAuth state, or Discord user ID appears in
    mailer params or output.
  - Existing invoice link and delivery deduplication remain intact.
- **Validation**:
  - `rtk test bundle exec rspec spec/mailers/billing_notifications_mailer_spec.rb spec/services/billing/stripe_invoice_notification_processor_spec.rb`
- **Rollback**: Disable integration or restore the prior billing primary CTA;
  no email backfill is needed.

### Sprint 4 Gate

- [ ] All Sprint 4 tasks complete.
- [ ] Shared-link, locale, sign-up persistence, checkout, dashboard, pricing,
      email, accessibility, and CSS validation passes and evidence is recorded.
- [ ] Stripe success query parameters are confirmed non-authoritative.
- [ ] EN/ES desktop and mobile Browser QA status is recorded.
- [ ] No bulk existing-subscriber email was sent.
- [ ] Residual risks are documented.
- [ ] Exactly one Sprint 4 commit is created with the proposed message.
- [ ] The pre-Sprint 5 rollback point is recorded.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: QA Fixtures, Documentation, Security Review, And Release Readiness

**Goal**: Make the feature safely testable, observable, deployable, and
reversible, complete the full validation gates, and prepare—but do not perform—
production enablement.

**Dependencies**: Sprint 4 gate complete; test-mode Stripe and a separate
Discord test application/guild for the full live canary.

**Tracked scope**:
`script/discord_vip_manual_qa_setup.rb`,
`docs/discord_vip_rollout_runbook.md`, `README.md`,
`docs/database_model_reference.md`,
`docs/pandora_subscription_rollout_runbook.md`, and any focused test corrections
required by final validation. No dependency upgrades.

**Commit**: `docs: add Discord VIP rollout and QA runbook`

**Demo/Validation**:

- QA setup creates fake/local states for ineligible, eligible-unlinked,
  linked-pending, granted, expired/removed, sync-failed, and disconnecting users
  without calling Discord or storing real tokens.
- Full focused Rails, lint, autoloading, security, CSS, and deterministic browser
  checks pass.
- Staging test-mode walkthrough covers shared link, sign-up, plan confirmation,
  Stripe Checkout, OAuth, guild join, membership screening guidance, role grant,
  failed renewal/removal simulation, payment recovery/regrant, unlink, and
  relink.
- Runbook documents feature-off deploy, enablement, observation, token rotation,
  role cleanup, and rollback.

**Rollback point**: Sprint 4 commit plus `DISCORD_INTEGRATION_ENABLED=false`.
The documentation/QA script can be reverted independently; production remains
disabled until a separate release authorization.

### Task 5.1: Add Deterministic QA State Setup

- **Location**: `script/discord_vip_manual_qa_setup.rb` and focused script specs
  if the local pattern warrants them.
- **Description**:
  - Follow existing QA setup script conventions.
  - Create fake users, Pandora plans/subscriptions/manual grants, and local
    Discord connection states with obviously non-production snowflakes.
  - Never call Discord or Stripe and never use values from `.envrc`.
  - Print only QA user credentials already intended for local/staging use and
    safe Rails record IDs/state labels.
- **Dependencies**: Completed model/UI.
- **Acceptance criteria**:
  - Re-running the script is idempotent.
  - Every important UI state is directly reachable for browser QA.
  - Production environment execution is refused.
- **Validation**:
  - Run twice in development/test and compare stable counts/states.
- **Rollback**: Delete only QA rows created by the script or reset the
  disposable QA database; never run against production.

### Task 5.2: Document Architecture, Operations, And Rollback

- **Location**: `docs/discord_vip_rollout_runbook.md`, `README.md`,
  `docs/database_model_reference.md`,
  `docs/pandora_subscription_rollout_runbook.md`.
- **Description**:
  - Document env names without values, application/role/guild contracts,
    one-to-one identity policy, eligibility states, callback route, job flow,
    monitoring, and error codes.
  - Reaffirm that Discord role state is downstream and never grants Rails
    product access.
  - Document separate staging app/server, server role hierarchy, ELITE category
    sync, membership screening, Sidekiq cron, and support checks.
  - Document feature-off deployment, feature enablement, post-enable observation,
    bot/client secret rotation impact, guarded linked-role cleanup, and code/data
    rollback.
  - State that generated `/etc/tradingsniperpanel/*.env` files are not edited
    directly.
- **Dependencies**: Final implementation shape.
- **Acceptance criteria**:
  - A maintainer can diagnose `401`, `403`, `404`, `429`, timeout, membership
    pending, webhook lag, and stale sync without viewing secrets.
  - Rollback distinguishes disabling automation from removing already granted
    roles.
- **Validation**:
  - Review documentation links and commands.
  - `git diff --check`
- **Rollback**: Documentation revert only; no runtime effect.

### Task 5.3: Run The Full Rails And Security Gates

- **Location**: Entire scoped implementation and tests.
- **Description**:
  - Run focused checks first, fix deterministic failures, and rerun the exact
    failed command before expanding.
  - Review authorization, ownership, OAuth state, secret/log safety, callback
    authenticity inherited from Pay, job idempotency, rate limiting, migration
    safety, and role scope.
- **Dependencies**: Tasks 5.1-5.2.
- **Acceptance criteria**:
  - All changed behavior is covered at the smallest appropriate layer.
  - No test performs a real Discord or Stripe call.
  - No new gem/package or generated dependency file appears.
- **Validation**:
  - `rtk test bundle exec rspec spec/models/discord_connection_spec.rb spec/services/discord spec/jobs/discord spec/requests/pandora_joins_spec.rb spec/requests/discord_oauth_spec.rb spec/requests/dashboard_discord_connections_spec.rb spec/requests/discord_admin_spec.rb`
  - `rtk test bundle exec rspec spec/models/pay_subscription_callbacks_spec.rb spec/jobs/manual_subscriptions/sync_job_spec.rb spec/services/licenses/subscription_license_sync_spec.rb spec/services/licenses/manual_subscription_sync_spec.rb spec/requests/subscription_upgrade_spec.rb spec/requests/plan_persistence_spec.rb spec/mailers/billing_notifications_mailer_spec.rb`
  - `rtk test bundle exec rspec spec/models spec/services spec/jobs spec/requests spec/mailers`
  - `bin/rails zeitwerk:check`
  - `bin/rubocop`
  - `bin/brakeman --no-pager`
  - `npm run build:css`
  - `git diff --check`
- **Rollback**: Fix failures inside the current sprint; do not advance or commit
  while the gate is red.

### Task 5.4: Run Deterministic Browser QA And Live Staging Canary

- **Location**: Local/staging runtime; temporary `.qa/web` harness must remain
  untracked and be removed before commit unless the repository later adopts it
  intentionally.
- **Description**:
  - Run project-native request/mailer tests first.
  - Use the token-efficient web QA harness for a focused Chromium flow, with
    Firefox fallback only if Chromium is unavailable.
  - Cover EN/ES, desktop/mobile, keyboard focus, loading/error/success states,
    console, and network failures using local QA states.
  - Use a separate Discord test app/server and Stripe test mode for the live
    provider canary. Never automate or store a real personal Discord password.
  - Confirm the production guild is never touched during staging QA.
- **Dependencies**: Tasks 5.1 and 5.3.
- **Acceptance criteria**:
  - Local deterministic flow has no unexpected `4xx/5xx`, JS exceptions,
    horizontal overflow, inaccessible primary action, or untranslated durable
    copy.
  - Live staging OAuth uses the correct staging callback and grants/removes only
    the test VIP role.
  - Membership-screening guidance is correct when the test guild enables it.
- **Validation**:
  - `bash /home/loldlm/.codex/skills/token-efficient-web-qa/scripts/qa-env-check.sh`
  - If no existing harness is available:
    `bash /home/loldlm/.codex/skills/token-efficient-web-qa/scripts/qa-bootstrap.sh --dir .qa/web --url http://127.0.0.1:3000 --package-manager npm`
  - `bash /home/loldlm/.codex/skills/token-efficient-web-qa/scripts/qa-run.sh --dir .qa/web --url http://127.0.0.1:3000 --browsers chromium`
  - Record `Browser QA: PASS`, `FAIL`, or `Not run` with the exact limitation.
  - Complete the staging checklist in
    `docs/discord_vip_rollout_runbook.md` using fake/test accounts only.
- **Rollback**: Remove temporary QA artifacts; if staging roles were granted,
  run the guarded test-guild cleanup and disable the staging feature flag.

### Task 5.5: Complete The Release Readiness Review

- **Location**: Scoped diff, deployment environment contract, and runbook.
- **Description**:
  - Review git status, all scoped diffs, migration, env example, routes, jobs,
    locales, mailers, and generated assets.
  - Confirm production credentials were not copied into the repo.
  - Confirm production remains disabled and that enabling requires a separate
    operational authorization.
  - Record the production rollback point, database backup reference, and
    observation window plan.
- **Dependencies**: Tasks 5.1-5.4.
- **Acceptance criteria**:
  - Rails Review Gate is PASS.
  - Browser QA gate is recorded.
  - Staging live-provider gate is PASS or explicitly blocks production enablement.
  - No unrelated user changes are included.
- **Validation**:
  - `rtk git status --short`
  - `rtk git diff --stat`
  - Scoped diff review and secret-pattern review without printing `.envrc`.
- **Rollback**: Do not enable production. Revert Sprint 5 only if its
  documentation/QA artifacts are defective; earlier functional sprints remain
  feature-gated.

### Sprint 5 Gate

- [ ] All Sprint 5 tasks complete.
- [ ] Focused and broad Rails validation passes and evidence is recorded.
- [ ] Security, migration, secrets, rate-limit, and role-scope review passes.
- [ ] Browser QA status is recorded with artifact paths only for failures.
- [ ] Live staging provider canary passes or production enablement is blocked.
- [ ] Production remains disabled pending separate authorization.
- [ ] Residual risks and operational ownership are documented.
- [ ] Exactly one Sprint 5 commit is created with the proposed message.
- [ ] The final rollback point is recorded.

## Sprint 6: Staging Parity, Automated QA, And Manual Canary Handoff

**Goal**: Harden the staging release contract, deploy the completed Discord VIP
feature to the isolated staging environment, run all safe automated checks, and
hand off only the interactive Stripe-test and Discord-test consent steps for
manual QA before any production authorization.

**Dependencies**: Sprint 5 commit `488142d`; SSH access to the staging VPS; a
separate Discord staging application, guild, bot, and VIP role; Stripe test-mode
credentials; and an authoritative staging `.envrc` owned by `admin` with mode
`0600`.

**Tracked scope**: `script/setup_common.sh`, `script/setup_staging.sh`,
`docs/discord_vip_rollout_runbook.md`, and this plan. No production environment
change, provider credential rotation, dependency upgrade, or live production
role mutation.

**Commit**: `ops: harden Discord staging rollout and QA`

**Demo/Validation**:

- The staging deploy script rejects unsafe secret-file permissions, live Stripe
  keys, production Discord identifiers, an incorrect callback, or an invalid
  public invite without printing values.
- `sudo bash ~/deploy_scripts/setup_staging.sh` deploys the pinned staging
  branch and verifies Puma, Sidekiq, Nginx, direct app access, and allowlisted
  proxy access.
- Staging boots with the intended feature flag, migrations and assets are
  current, Sidekiq cron is loaded, `/up` and the Discord routes respond, and the
  safe Discord audit contains counts only.
- Deterministic staging QA data is idempotent and focused Chromium QA covers the
  non-provider funnel and dashboard states without using real personal
  credentials.
- The final handoff clearly separates automated PASS evidence from the manual
  Stripe Checkout and Discord OAuth/provider-mutation canary.

**Rollback point**: Sprint 5 commit `488142d`, staging
`DISCORD_INTEGRATION_ENABLED=false`, and the normal staging setup entry point.
Preserve `discord_connections`; never run production cleanup.

### Task 6.1: Enforce The Staging Release Environment Contract

- **Location**: `script/setup_common.sh` and `script/setup_staging.sh`.
- **Description**:
  - Require the staging `.envrc` to be owned by the application user and have
    mode `0600` before it is rendered to `/etc/tradingsniperpanel/staging.env`.
  - Require the Stripe test and Discord integration variable names needed by
    the live staging canary.
  - Validate test-mode Stripe key prefixes, the exact public invite, the exact
    staging callback derived from `APP_HOST_PROTOCOL` and `APP_HOST`, and
    non-production Discord application/guild/VIP role identifiers.
  - Report only variable names and pass/fail reasons; never print secret values.
- **Dependencies**: None beyond the completed Sprint 5 implementation.
- **Acceptance criteria**:
  - Safe dummy staging values pass a shell-level preflight.
  - Unsafe file mode, live Stripe keys, production Discord IDs, or callback
    mismatch fail before environment rendering, migrations, assets, or service
    restart.
- **Validation**:
  - `bash -n script/setup_common.sh script/setup_staging.sh`
  - Focused temporary-file probes for both accepted and rejected contracts.
  - Redacted VPS preflight against `.envrc`; output contains no values.
- **Rollback**: Revert only the preflight change if it rejects a valid staging
  contract; keep the feature disabled until the validation is corrected.

### Task 6.2: Deploy And Verify Staging Runtime Parity

- **Location**: `admin@82.39.186.26`, external
  `~/deploy_scripts/setup_staging.sh`, staging repository, systemd, Nginx,
  PostgreSQL, Redis, and `/etc/tradingsniperpanel/staging.env`.
- **Description**:
  - Confirm the external deploy script matches the repository script and the
    staging branch is clean at the expected sprint commit.
  - Run the normal setup entry point and capture only non-sensitive status
    evidence.
  - Verify service health, migrations, assets, runtime environment file mode,
    Sidekiq cron, Discord routes, `/up`, and recent sanitized errors.
- **Dependencies**: Task 6.1 preflight passes and the Sprint 6 commit is
  available to the staging branch.
- **Acceptance criteria**:
  - Puma, Sidekiq, Redis, PostgreSQL, and Nginx are active after deployment.
  - Direct and proxied health checks pass with the expected staging host.
  - Staging is isolated from production database names and Discord identifiers.
  - No secret value is printed or committed.
- **Validation**:
  - `sudo bash ~/deploy_scripts/setup_staging.sh`
  - `systemctl is-active` for the staging web/Sidekiq services and dependencies.
  - Staging Rails runner checks for migration status, cron schedule, route
    recognition, Discord configuration shape, and safe audit output.
- **Rollback**: Set only staging `DISCORD_INTEGRATION_ENABLED=false`, rerun the
  staging setup script, and restore commit `488142d` if application rollback is
  required. Preserve additive data and leave production untouched.

### Task 6.3: Run Automated Staging QA And Prepare Manual Canary

- **Location**: Staging Rails runtime, temporary local `.qa/web` harness, and
  `docs/discord_vip_rollout_runbook.md`.
- **Description**:
  - Run the deterministic QA builder twice in staging and confirm stable state
    counts and record IDs without provider calls.
  - Run focused Chromium checks against the allowlisted staging URL for public
    EN/ES entry, authentication boundaries, dashboard states, accessibility,
    console errors, and unexpected `4xx`/`5xx` responses.
  - Record the precise interactive sequence the user will complete with a
    staff-owned Stripe-test account and Discord-test identity.
  - Do not automate Discord credentials, OAuth consent, Stripe Checkout card
    entry, or production provider mutations.
- **Dependencies**: Task 6.2 runtime checks pass.
- **Acceptance criteria**:
  - Deterministic data setup is idempotent and automated browser QA is PASS, or
    a precise staging-only blocker is recorded and production remains blocked.
  - Manual instructions include expected evidence for VIP grant, screening,
    failed renewal removal, recovery, unlink, and production-isolation checks.
- **Validation**:
  - `bin/rails runner script/discord_vip_manual_qa_setup.rb` twice in staging.
  - Focused Chromium runner against the staging base URL using only generated
    QA accounts.
  - `bin/rails discord:vip:audit` before and after automated QA.
- **Rollback**: Remove only generated staging QA rows or reset the disposable
  staging database when explicitly intended; disable the staging feature flag
  if provider mutation cannot be proven isolated.

### Sprint 6 Gate

- [x] All Sprint 6 tasks complete under the authorized production-first override.
- [x] Staging `.envrc` and generated runtime env permissions pass.
- [x] Stripe test mode and non-production Discord isolation fail closed without value
      disclosure.
- [x] Production-first setup, services, health, migrations, assets, cron, routes,
      logs, and safe audit pass.
- [x] Deterministic local shell QA and focused Chromium public-funnel QA pass;
      provider credentials and production customer state were not automated.
- [x] Manual staff canary instructions are ready.
- [x] Production enablement completed only after explicit authorization and a
      fresh Discord permission graph PASS.
- [x] Exactly one Sprint 6 commit is created with the proposed message and the
      rollback point is recorded.

### Sprint 6 Execution Record (2026-07-15)

- PASS: SSH access, clean `staging` branch at Sprint 5 commit `488142d`, and
  matching external/repository staging setup scripts.
- PASS: The staging source `.envrc` is now owned by `admin` with mode `0600`;
  the permanent public Discord invite is exported correctly; Stripe keys are
  test-mode; and the staging host, port, Redis URL, and four PostgreSQL database
  names differ from production.
- PASS: The current generated staging runtime environment remains feature-off,
  does not contain the new Discord provider credentials, and the existing web,
  Sidekiq, Nginx, PostgreSQL, and Redis services remain active.
- BLOCKED: The staging Discord client ID, client secret, bot token, guild ID,
  VIP role ID, and callback currently match production. The redacted Sprint 6
  preflight rejects this configuration before deployment.
- NOT RUN: `sudo bash ~/deploy_scripts/setup_staging.sh`, automated staging
  browser QA, and the live provider canary. Production was not changed.
- Required resume condition: replace the six staging Discord values with a
  separate test application/guild contract, register the exact staging
  callback, place the test bot role above the test VIP role, and grant only the
  test VIP role access to the staging ELITE category.

### Sprint 6 Production-First Canary Override (2026-07-15)

The user explicitly authorized a production-side staff canary instead of
creating separate staging Discord resources. This is a live-provider rollout,
not staging QA, and it replaces the blocked staging provider step only under
the following gates:

1. Force the authoritative production source flag to
   `DISCORD_INTEGRATION_ENABLED=false` before deployment.
2. Record a fresh PostgreSQL backup and pre-deploy commit.
3. Push and deploy the already validated Sprint 1-5 commits with the feature
   disabled; verify migrations, assets, Puma, Sidekiq, cron, routes, `/up`,
   logs, and a zero-mutation Discord audit.
4. Keep the feature disabled until the user is ready to perform the coordinated
   manual staff canary. No existing subscriber should be invited to test.
5. Enable production through the normal setup script only for the canary, link
   one authorized staff account, and immediately verify live guild join, VIP
   grant, screening, removal, recovery, unlink, and safe audit/log evidence.
6. Observe at least one hourly reconciliation window before broader rollout.
   Disable the source flag and rerun production setup immediately if any gate
   fails; do not run role cleanup unless explicitly authorized.

The production Discord guild and role are live. Automated QA must not create
fake provider identities, call Discord, exercise cancellation against customer
accounts, or run the deterministic QA builder in production.

Production feature-off deployment evidence:

- PASS: Fresh custom-format backups for the primary, cache, queue, and cable
  PostgreSQL databases were verified at
  `/home/admin/backups/tradingsniperpanel/20260715T120427Z-pre-discord-vip-488142d`.
- PASS: Commits `75977d8` through `488142d` were fast-forwarded to `main` and
  deployed through `sudo bash ~/deploy_scripts/setup_production.sh` with the
  authoritative and generated feature flags false.
- PASS: Production runs commit `488142d`; migrations, assets, Puma, Sidekiq,
  Redis, PostgreSQL, Nginx, `/up`, the public invite, Discord routes, hourly
  cron, and safe audit checks pass. There are zero Discord connections and zero
  queued Discord jobs.
- PASS: Read-only Discord API checks confirm bot authentication, `Manage Roles`,
  `Create Instant Invite`, bot hierarchy above Pandora VIP, the configured VIP
  role, and one VIP-visible protected category.
- PASS (2026-07-15): A fresh read-only Discord API permission graph confirms the
  bot authentication, `Manage Roles`, `Create Instant Invite`, role hierarchy,
  the single `𝐄𝐋𝐈𝐓𝐄` category, and all six child channels including
  `『🧠』𝙿𝚜𝚒𝚌𝚘𝚕𝚘𝚐𝚒𝚊`. Every child is synchronized with the category and visible to
  `Pandora VIP`; no channel or role mutation was performed by the check.
- PASS: Production source and generated runtime flags are now `true` after the
  authorized `sudo bash ~/deploy_scripts/setup_production.sh` run. The deployed
  commit remains `488142d`; Puma, Sidekiq, Nginx, PostgreSQL, Redis, `/up`,
  migrations, assets, routes, hourly cron, and the safe audit all pass. There
  are zero linked Discord connections and zero queued Discord jobs.
- PASS: Public Chromium smoke covers the home footer invite, EN/ES Pandora entry
  links, unauthenticated Discord dashboard boundary, and mobile overflow. All
  application checks pass; the only observed browser warnings are third-party
  Tawk embed CORS/load warnings and are unrelated to Discord.
- READY: The interactive staff canary remains intentionally manual. No OAuth
  consent, Stripe Checkout entry, live customer role mutation, or cancellation
  was automated.

## Production Enablement Gate

This gate is outside implementation commits and requires explicit production
authorization.

1. Confirm all six sprint gates and commits, including either the manual
   staging canary evidence or the explicit production-first staff-canary
   override recorded in Sprint 6.
2. Confirm a fresh database backup and pre-enable application commit.
3. Deploy schema/code with `DISCORD_INTEGRATION_ENABLED=false` through the
   existing production setup script.
4. Confirm Puma, Sidekiq, health endpoint, routes, assets, and logs are healthy.
5. Confirm production `.envrc` has the seven configured Discord values plus the
   feature flag, remains `0600`, and no value is printed.
6. Confirm bot role hierarchy and both required permissions again.
7. Confirm ELITE channels are synchronized with the private category and staff
   roles are intentional.
8. Set `DISCORD_INTEGRATION_ENABLED=true`, rerun the normal production setup,
   and verify service restart.
9. Use one authorized internal active Pandora account as the first canary.
10. Verify OAuth state, guild join, membership screening guidance, VIP grant,
    dashboard state, and no unrelated role mutation.
11. Observe Rails/Sidekiq safe error codes, Discord rate limits, Pay webhooks,
    and reconciliation through at least one hourly cycle.
12. Do not send a bulk existing-subscriber email. Existing users discover the
    dashboard CTA naturally.

If the canary fails, disable the feature first. If granted VIP access must also
be withdrawn, run the guarded linked-role cleanup according to the runbook;
never kick members or delete staff roles.

## Sprint 7: Canary UX Contrast And Public Discord Readability

**Goal**: Close the successful production canary with accessible dark-theme
Discord states and correct public onboarding readability without granting a
paid/staff Discord role to free community members.

**Dependencies**: Sprint 6 commit `136a744`; the completed staff canary on the
authorized internal account; production Discord integration enabled; and the
existing human-owned Discord category/role contract.

**Tracked scope**: The two app-owned Discord dashboard views, focused request
coverage, this plan/runbook, and a one-time Discord permission-overwrite repair
for the `FREE PASS` role on two public onboarding channels. No entitlement,
OAuth, billing, database, job, role-assignment, dependency, or schema change.

**Commit**: `fix: close Discord VIP canary follow-ups`

**Rollback point**: Sprint 6 commit `136a744`; restore the two prior ERB class
stacks and the exact captured Discord overwrite bitsets for the two public
channels. Do not disable Pandora VIP or mutate subscriber connections for a
presentation/public-channel rollback.

### Task 7.1: Record Canary And Permission Evidence

- **Description**:
  - Verify the staff canary completed grant, removal, recovery, and unlink
    without a provider error or residual identity.
  - Calculate effective Discord permissions for `@everyone`, `FREE PASS`,
    `ELITE SNIPER`, and `Pandora VIP` before choosing a remediation.
- **Acceptance criteria**:
  - The Rails connection is safely disconnected, the identity is cleared, the
    VIP role state is removed, and the test manual grant is cancelled.
  - Evidence proves `FREE PASS` can view but cannot read message history in
    `Bienvenidos` and `Hazte-VIP`, while `ELITE SNIPER` would expose ELITE and
    therefore must not be assigned to public users.

### Task 7.2: Strengthen Dark-Theme Discord Contrast

- **Location**: `app/views/dashboards/shared/_discord_vip_card.html.erb`,
  `app/views/dashboard/discord_connections/show.html.erb`, and focused request
  specs.
- **Description**: Increase dark-theme contrast for state badges, explanatory
  copy, and the public Discord secondary action while preserving the Mosaic
  layout, DOM IDs, actions, I18n copy, and light-theme behavior.
- **Validation**: Focused request specs, `npm run build:css`, and authenticated
  light/dark Chromium QA at desktop and mobile widths.

### Task 7.3: Repair Public Onboarding Read History

- **Location**: Production Discord `WELCOME` channels `Bienvenidos` and
  `Hazte-VIP`.
- **Description**: Preserve each existing `FREE PASS` overwrite and clear only
  the `Read Message History` deny bit. Do not add `ELITE SNIPER`, change any
  role membership, alter other permissions, or touch ELITE overwrites.
- **Validation**:
  - A fresh read-only graph reports `View Channel` and `Read Message History`
    for `FREE PASS` on both channels.
  - ELITE remains hidden from `@everyone` and `FREE PASS`, and visible through
    `Pandora VIP`.

### Task 7.4: Deploy And Close The Canary

- **Description**: Create exactly one Sprint 7 commit, push `main`, deploy with
  the normal production setup entry point, and verify commit parity, clean
  worktrees, services, `/up`, feature flag, cron, queues, safe audit, and recent
  errors.
- **Manual check**: Join once with a new/free Discord identity and confirm the
  two onboarding channels show their existing history without ELITE access.

### Sprint 7 Execution Record (2026-07-15)

- PASS: The authorized canary account is ineligible after the test, its manual
  Pandora grant is cancelled, its Discord identity is cleared, its connection
  is disconnected, `vip_role_state=removed`, and no safe error code remains.
- PASS: Read-only Discord evidence identified the narrow fault: `FREE PASS`
  explicitly denied `Read Message History` only in `Bienvenidos` and
  `Hazte-VIP`. The owner cleared only that deny in both channels; no role was
  assigned. `ELITE SNIPER` remains restricted to the protected ELITE category.
- PASS: The dark dashboard card and Discord status page now use Mosaic utilities
  present in the deployed vendor bundle. Chromium confirms the dark status and
  secondary action at `9.36:1`, readable title/body copy, unchanged light-theme
  presentation, no desktop/mobile overflow, and no console or network failures.
- PASS: Focused request coverage reports `31 examples, 0 failures`, and the
  Tailwind/ActiveAdmin CSS build completes with only the existing Sass
  deprecation warnings.
- PASS: A fresh live graph now reports `FREE PASS` view/history on both public
  channels, `@everyone`/`FREE PASS` hidden from ELITE, and `Pandora VIP` and
  `ELITE SNIPER` retaining ELITE visibility. The bot performed no mutation.
- READY: The code, tests, CSS build, browser QA, and live permission contract
  are complete for the single Sprint 7 commit and normal production deploy.

### Sprint 7 Gate

- [x] Dark-theme labels and actions meet practical contrast expectations.
- [x] `FREE PASS` can view and read both public onboarding channels.
- [x] ELITE remains hidden from `@everyone` and `FREE PASS`.
- [x] No role membership or non-target permission changes were made by the app;
      the owner changed only the two documented channel overwrites.
- [x] Focused specs, CSS build, and Browser QA pass; the production health,
      audit, and log checks are the immediate post-push release gate.
- [ ] Exactly one Sprint 7 commit is pushed and deployed.

## Testing Strategy

### Unit And Domain

- Discord configuration enablement and missing-key behavior.
- Connection validation, uniqueness, scopes, status transitions, sync lease,
  and unlink coherence.
- OAuth state generation, expiry, one-time consumption, secure comparison, and
  safe return paths.
- Discord client request encoding, authentication type, response mapping,
  timeout, `401`, `403`, `404`, `429`, `5xx`, and malformed JSON.
- VIP eligibility across every fixed Stripe/manual state.
- Link, unlink, and role sync commands, including concurrent/racy cases.

### Database And Migration

- Additive migration on populated local/test data.
- Foreign key, unique user, partial unique Discord ID, status check, and
  coherence constraints.
- Old-process compatibility while the new table is unused.
- Disposable-environment rollback before data; production code rollback leaves
  the table in place after connections exist.

### Request And Security Integration

- Authentication and CSRF behavior for authorize, retry, and unlink.
- OAuth callback success, denial, missing code, missing/mismatched/expired/
  replayed state, duplicate Discord identity, existing connection, and provider
  failure.
- `/join/pandora` for anonymous, signed-in ineligible, eligible-unlinked, and
  connected users in EN/ES.
- Checkout success destination without changing discounts, metadata, or cancel
  behavior.
- Forged success query cannot change entitlement.
- Admin authorization for visibility/resync and denial for traders.
- No cross-user ID parameter can load or mutate another connection.

### Jobs And External Integration

- Enqueueing separate from job execution.
- Pay lifecycle and manual grant triggers.
- Current-state recomputation despite duplicate/out-of-order events.
- Retry and `Retry-After` behavior without worker sleeping.
- Sync lease and stale lease recovery.
- Hourly batch reconciliation and disabled-feature no-op.
- No real network calls in automated tests.

### Mailer And Localization

- Subscription-started HTML/text CTA with enabled/disabled behavior.
- Invoice link and delivery deduplication preserved.
- User preferred locale preserved.
- EN/ES key parity and interpolation checks.
- No secret or Discord identity leakage in mailer params/output.

### Browser And Accessibility

- Anonymous shared-link flow through sign-up and monthly plan selection.
- Eligible user activation states and public-community fallback.
- Desktop `1280x900`, tablet `768x900`, and mobile `375x812`.
- Keyboard focus, semantic headings/buttons/links, accessible confirmations,
  visible error recovery, and touch targets.
- Light/dark themes and longer Spanish copy.
- Console/network sweep with no unexpected failures.
- Stripe and Discord consent are tested in staging/test mode; personal login
  credentials are never committed or automated.

### Performance And Reliability

- Reconciliation batches database rows and enqueues jobs rather than calling
  Discord inline.
- Per-connection lease prevents duplicate concurrent HTTP work.
- No external calls occur in database transactions or ordinary dashboard page
  requests.
- OAuth callback contains only the required synchronous exchange/identify/join
  operations with strict timeouts.
- Provider rate limits are header-driven and invalid-request loops stop on
  permanent authentication/permission errors.

### Operational

- Feature-off deploy and feature-on restart.
- Sidekiq/cron visibility.
- Safe admin state and maintenance commands.
- Test-guild add/remove/recovery canary.
- Production internal canary and one-hour reconciliation observation.
- Bot token/client secret rotation procedure.
- Guarded linked-role cleanup and feature-disable rollback.

## Risks And Mitigations

| Risk | Impact | Mitigation | Validation Signal |
| --- | --- | --- | --- |
| OAuth CSRF or callback replay | Wrong Discord account linked to a Rails session | One-time expiring state, constant-time comparison, authenticated initiation/callback, fixed internal redirect | Mismatch, expiry, replay, and anonymous request specs |
| Discord account shared across Rails users | Subscription sharing and role ownership conflict | Service check plus unique non-null `discord_user_id` index | Concurrent duplicate-link spec fails one transaction safely |
| OAuth/bot token leakage | Full integration compromise | Never persist OAuth tokens; env-only bot/client secrets; redacted logs/errors/tests | Schema review, secret search, log/mailer/request specs |
| Bot role below VIP or permission removed | Grant/removal returns `403` | Startup/runbook checks, stable permission error code, admin visibility, no endless retry | Test-guild canary and `403` service spec |
| Membership screening | User joined and role granted but cannot see/talk in ELITE | Persist pending when available and show accept-rules guidance | `201 pending` client/request specs and staging canary |
| Stripe webhook delay after Checkout | Activation page initially sees no paid subscription | Treat redirect as UX hint only, show processing state, rely on Pay webhook and hourly repair | Forged-success and delayed-webhook request/job specs |
| Duplicate or out-of-order Pay events | Stale job adds role after expiration | Recompute eligibility at job execution; never trust webhook payload state | Active-to-failed and failed-to-recovered ordering specs |
| Concurrent role jobs | Add/remove race leaves wrong role | Per-connection sync lease, identity recheck after HTTP, follow-up enqueue/reconciliation | Concurrent service/job specs |
| Discord `429` | Worker churn or blocked API | Honor `Retry-After`, re-enqueue, no hard-coded buckets or worker sleep | `429` client/job specs |
| Discord `401`/`403` loop | Invalid request accumulation and potential temporary API restriction | Mark permanent operational error, stop rapid retry, surface admin/runbook action | Retry policy specs and admin state |
| Manual subscription expires without row update | Role remains because no callback fires at the exact timestamp | Hourly reconciliation computes current time from authoritative scopes | Time-travel manual expiry reconciliation spec |
| Staff manually removes VIP from eligible linked user | Eligible user loses access | Hourly reconciliation re-adds app-owned role | Drift-repair spec |
| Staff manually grants VIP to ineligible linked user | Unpaid linked user retains access | Hourly reconciliation removes app-owned role; staff uses separate roles | Ineligible drift-repair spec |
| Unlinked Discord user has manually assigned VIP | App cannot prove ownership | Reconciliation touches only app-linked IDs; manual server administration remains responsible | Batch scope spec and runbook |
| Unlink provider failure | Old account may retain VIP or identity may be lost | Keep identity and mark failed/pending until role removal succeeds | Timeout/`403` unlink specs |
| Staging uses production bot/guild | Test mutates real community roles | Separate staging app/server and hard release gate | Environment/runbook check before live QA |
| Feature flag disabled after grants | Automation stops but granted roles remain | Explicitly document distinction and guarded linked-role cleanup | Rollback rehearsal in test guild |
| Category channel not synchronized | VIP role exists but some ELITE channels stay hidden or exposed | Manual Discord category/channel release checklist; no channel API scope | Server settings review during release gate |
| Discord username changes | Dashboard shows stale presentation | Identity remains keyed by immutable Discord ID; refresh safe names on successful OAuth reconnect | Model/service spec and documented limitation |
| Broad admin visibility leaks PII | Support surfaces reveal account data | Show minimal username/display name, Rails IDs, state, timestamps, safe codes; no raw API data | Admin request/view review |

## Rollback Plan

### Sprint 1

- Revert foundation code while feature remains false.
- Before real data, roll back migration in disposable environments.
- After real connections, leave the additive table and indexes in place during
  code rollback.

### Sprint 2

- Disable integration to stop enqueueing/reconciliation.
- Remove the new cron entry and Discord callbacks without touching existing
  license callbacks.
- If test/live VIP roles must be withdrawn, use the guarded linked-role cleanup;
  never kick members or mutate other roles.

### Sprint 3

- Disable OAuth routes/UI and keep connection rows for audit/cleanup.
- Allow already queued unlink/removal jobs to finish when safe.
- Do not clear identities manually if old VIP removal is unconfirmed.

### Sprint 4

- Restore prior Checkout success URL and subscription-started billing CTA.
- Remove shared join route, dashboard card, nav item, and benefit copy if needed.
- Footer public Discord invite remains independent.

### Sprint 5

- Revert documentation/QA-only defects without weakening the feature flag or
  provider-isolation gates.
- Preserve the Sprint 4 implementation and keep production disabled.

### Sprint 6 And Production

- Disable `DISCORD_INTEGRATION_ENABLED` first and restart through the normal
  deployment script.
- Observe and drain/stop new Discord jobs.
- Decide explicitly whether already granted roles may remain temporarily. If
  not, run guarded linked-role cleanup and verify counts/errors.
- Revert application commit(s) in reverse sprint order without dropping the
  populated table.
- Restore the pre-enable application revision. Migration rollback is not part
  of an emergency production rollback unless every connection is safely
  exported/removed and a separate data-migration plan is approved.
- If a credential is suspected leaked, reset the bot token/client secret in the
  Discord Developer Portal, update the appropriate environment source file,
  rerun the normal setup script, and verify with a staff canary.

## Execution Order And Gate

Before Sprint 1 implementation, the executor must read the installed `$planner`
`references/execution-state.md`, initialize active-plan execution state, and
record transitions after validation, commit, blocker, sprint advance, and
completion.

1. Implement Sprint 1 only.
2. Run and record all Sprint 1 validation.
3. Create exactly one Sprint 1 commit with the proposed message and record its
   rollback point.
4. Start Sprint 2 only after the Sprint 1 gate passes.
5. Repeat the same complete/validate/one-commit/rollback-point gate for Sprints
   2 through 6.
6. Do not combine sprint commits, start later work early, skip failed checks, or
   enable production during implementation.
7. Production enablement requires separate explicit authorization after every
   sprint and release-readiness gate passes.

## Completion Checklist

- [x] Every sprint has passed its validation gate, including the recorded Sprint
      6 production-first override.
- [x] Every sprint has exactly one sprint-specific commit.
- [x] Current paid/manual eligibility is the only VIP authority.
- [x] OAuth tokens are never persisted and secrets never leave environment
      storage.
- [x] One-to-one Discord ownership is enforced at service and database levels.
- [x] Scheduled cancellation, expiry, failed renewal, recovery, manual grants,
      unlink, and drift repair are covered.
- [x] `/join/pandora` preserves EN/ES, sign-up, plan selection, referral, and
      Stripe behavior.
- [x] Dashboard and email activation are localized and accessible.
- [x] No Discord role other than `Pandora VIP` is mutated.
- [x] No user is kicked when access ends.
- [x] Focused and broad Rails, CSS, lint, security, migration, and Browser QA
      gates pass.
- [x] Staging test Stripe and Discord isolation are enforced by a fail-closed
      preflight; live provider validation uses the authorized production-first
      staff-canary override because separate staging Discord resources were not
      supplied.
- [x] Feature-off production parity and public automated QA pass before the
      manual live provider canary begins.
- [x] Production feature flag remained false until separately authorized.
- [x] Runbook, monitoring, credential rotation, cleanup, and rollback
      instructions are current.
