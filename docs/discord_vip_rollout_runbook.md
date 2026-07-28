# Discord VIP Rollout Runbook

This runbook covers the shared Chu Sniper Trailing and Pandora Box Discord VIP
integration from feature-off deployment through staging validation, production enablement, monitoring,
credential rotation, and rollback. It prepares operations only; it does not
authorize a production deploy, a live role cleanup, or customer communication.

## Fixed Contracts

- Public community invite: `https://discord.gg/tWJNnu4ArJ`.
- Discord application/client ID: `1526565454355632138`.
- Production guild ID: `1505303505915744276`.
- Production configured VIP role ID: `1526657965828997371` (the existing role
  is named `Pandora VIP` for compatibility).
- Production callback: `https://tradingsniperpanel.com/discord/callback` with
  no trailing slash and no locale segment.
- OAuth scopes: exactly `identify guilds.join`.
- The Discord bot role must have `Manage Roles`, remain above the configured
  VIP role,
  and may retain `Create Instant Invite`. The bot never needs message, presence,
  or privileged gateway intents.
- Discord administrators own the ELITE category permission overwrites. Rails
  manages only the configured VIP role and never changes staff or other member
  roles.

## Authority And Data Flow

Paid Stripe/Pay Chu or Pandora access or an active manual grant for either tier
is the only source of VIP eligibility. Trials, failed/inactive subscriptions,
expired manual grants, and Discord role presence are not application entitlement.

```text
/join/pandora -> localized sign-up/sign-in -> Chu or Pandora plan confirmation
  -> Stripe Checkout -> verified Pay webhook/manual grant
  -> dashboard Discord OAuth -> guild join -> queued role sync

Pay/manual changes -> event-driven sync job
Hourly Sidekiq cron -> reconciliation job -> repair missed or drifted role state
```

One Rails user may link one Discord identity, and a Discord identity may belong
to only one Rails user. OAuth tokens are used in memory for the callback and
are never persisted. Unlink removes VIP before clearing the stored identity.
Users remain in the public Discord after VIP removal; Rails never kicks or
bans them.

## Environment Contract

Configure names only through the environment source used by the deployment
scripts. Never commit values or copy them into tickets, logs, screenshots, or
documentation.

- `DISCORD_INTEGRATION_ENABLED`
- `DISCORD_CLIENT_ID`
- `DISCORD_CLIENT_SECRET`
- `DISCORD_BOT_TOKEN`
- `DISCORD_GUILD_ID`
- `DISCORD_VIP_ROLE_ID`
- `DISCORD_REDIRECT_URI`
- `SUPPORT_DISCORD_URL`

The server setup scripts generate `/etc/tradingsniperpanel/*.env` from the
environment-specific `.envrc`. Do not edit generated `/etc` files directly.
After changing credentials or the feature flag, rerun the established setup
entry point so both Puma and Sidekiq receive the same values.

Before a staging setup can change packages, databases, assets, or services, the
staging script performs a redacted release preflight. The source file must be
owned by the staging application user with mode `0600`; Stripe private/public
keys must be test-mode; the public invite must match the fixed community URL;
and enabled Discord settings must use a non-production application, guild, VIP
role, and exact callback derived from `APP_HOST_PROTOCOL` and `APP_HOST`. When
the production `.envrc` is readable on the same host, the preflight also rejects
matching Discord and Stripe provider values. A failure prints only variable
names or safe reason codes and happens before environment rendering, migrations,
asset builds, or service restarts.

Production must reject an enabled configuration unless the callback exactly
matches the fixed production URI. Staging should use a separate Discord
application, guild, callback, bot token, and test VIP role. Never point a
staging canary at the production guild.

## Feature-Off Deployment

1. Record the database backup reference and the pre-deploy commit.
2. Keep `DISCORD_INTEGRATION_ENABLED=false`.
3. Run the normal staging or production setup script. It must apply the additive
   `discord_connections` migration, build assets, and restart Puma/Sidekiq.
4. Confirm `/up`, public pages, sign-in, dashboard, Stripe webhooks, and Sidekiq
   are healthy.
5. Confirm `bin/rails discord:vip:audit` reports safe counts only.
6. Confirm `/discord/callback` exists and no localized callback route exists.
7. Confirm the public footer invite still works while dashboard automation is
   disabled.

Feature-off deployment does not remove a role that was already granted. That
separation is intentional so disabling automation is fast and reversible.

## Deterministic Local And Staging QA States

The QA builder refuses production, uses obviously fake Discord snowflakes,
captures background jobs with the Active Job test adapter, and never calls
Discord or Stripe:

```bash
bin/rails runner script/discord_vip_manual_qa_setup.rb
```

It prints the shared QA password and accounts for these states:

- `ineligible`
- `eligible_unlinked`
- `linked_pending`
- `membership_screening`
- `granted`
- `expired_removed`
- `sync_failed`
- `disconnecting`

Run it twice and confirm the same state count, user IDs, connection IDs, and
labels. Use only the generated QA accounts. When rendering the enabled UI
locally, use fake Discord configuration and do not click Connect, Retry, or
Disconnect. In staging, use the separate test guild before exercising provider
mutations.

## Implementation Readiness Record

As of 2026-07-14, the feature-off implementation is ready for a staging canary:

- The QA builder produced the same eight states and stable record IDs on
  repeated test and development runs.
- Discord-focused, billing-regression, and broad non-system Rails suites passed;
  autoloading, the CSS build, changed-file RuboCop, and diff checks also passed.
- Deterministic Chromium QA passed 21 scenarios covering all eight connection
  states, EN desktop, ES mobile, the public invite, localized Pandora entry,
  monthly-first confirmation, the dashboard CTA, keyboard focus, overflow,
  dark theme, console errors, and local `4xx`/`5xx` responses.
- Brakeman reported no Discord finding. Its two weak-SQL warnings in
  `Dashboard::MainPresenter` and the repository-wide RuboCop baseline are
  pre-existing and outside this rollout; all changed Ruby files pass RuboCop.
- The live Stripe-test/Discord-test-guild canary has not been run. This blocks
  production enablement until a separate staging application, guild, callback,
  bot, and VIP role are authorized and the checklist below passes.
- No production database backup reference exists yet because production
  deployment and enablement are not authorized. Record it with the pre-enable
  commit before deployment. The rollback point is the Sprint 5 commit containing
  this runbook with `DISCORD_INTEGRATION_ENABLED=false`.

Production observation must cover at least one full hourly reconciliation
window after the staff canary, with an identified rollback owner watching app
health, Sidekiq, safe Discord sync errors, and audit counts.

## Staging Live Canary

Complete all deterministic Rails and browser checks before this canary.

1. Confirm the staging source is protected before invoking deployment:

   ```bash
   stat -c '%a %U:%G' /home/admin/tradingsniperpanel.com-staging/.envrc
   sudo bash ~/deploy_scripts/setup_staging.sh
   ```

   Expected mode is `600`, and the setup script must pass its redacted provider
   isolation checks before it can render `/etc/tradingsniperpanel/staging.env`.
2. Verify Stripe test keys and the separate Discord test application/guild.
3. Register the exact staging callback and confirm the bot role is above the
   staging VIP role.
4. Confirm only the staging VIP role grants the staging ELITE category.
5. Deploy with the feature disabled, verify health, then enable it only in the
   staging environment source and restart Puma/Sidekiq through the setup script.
6. Use a staff-owned test account and visit `/join/pandora` in EN and ES;
   exercise one Chu and one Pandora test subscription.
7. Complete sign-up, monthly-default plan confirmation, Stripe test Checkout,
   and return to the Discord activation page.
8. Authorize only `identify` and `guilds.join`; confirm guild membership and the
   staging VIP role.
9. If membership screening is enabled, accept the server rules and confirm the
   staging ELITE category appears.
10. Simulate failed/ended paid access and confirm VIP is removed without kicking
   the member. Recover payment and confirm VIP is restored.
11. Unlink, confirm VIP removal precedes identity clearing, then link a different
   test Discord identity.
12. Confirm the production guild, production VIP role, and production Discord
    application were never touched.

Do not automate or store a personal Discord password. The OAuth consent step is
completed interactively by the test account owner.

## Monitoring And Repair

Operational surfaces:

- `Admin -> Discord VIP` shows safe connection state, eligibility reason,
  membership-pending status, timestamps, and stable error codes. It never shows
  Discord user IDs, profile handles, OAuth tokens, or raw provider responses.
- `bin/rails discord:vip:audit` prints connected, eligible, ineligible, failed,
  and membership-pending counts without provider calls.
- `bin/rails discord:vip:reconcile` enqueues the same reconciliation used by the
  hourly `15 * * * *` Sidekiq cron when the feature is enabled.
- The ActiveAdmin `Sync VIP` action queues only the selected linked account.
- Safe logs use the connection record ID and an error code, not credentials,
  headers, response bodies, email addresses, or Discord identities.

### Error Triage

| Code/state | Meaning | Checks and response |
| --- | --- | --- |
| `unauthorized` / `401` | Bot token or OAuth client credentials rejected | Verify the correct environment received the rotated value; restart Puma and Sidekiq. Never print the credential. |
| `forbidden` / `403` | Missing `Manage Roles`, bot below VIP, or guild policy denial | Check bot role permissions and hierarchy in the intended guild. Retry only after Discord configuration is corrected. |
| `not_found` / `404` | Wrong guild/role/member reference or member no longer present | Verify configured IDs. Role removal treats an already absent member/role as complete; role grant requires a present member. |
| `rate_limited` / `429` | Discord rate limit | Let the job honor `retry_after`; do not bulk-click admin retries. |
| `transport_error` | Timeout, DNS, socket, or network failure | Check egress/DNS and provider status; retry is automatic for transient failures. |
| `server_error` | Discord `5xx` | Observe automatic retries and provider status; avoid manual retry storms. |
| `invalid_response` | Unexpected provider payload | Keep the feature enabled only if existing sync remains safe; investigate client compatibility without logging the payload. |
| `internal_error` | Unexpected application failure | Inspect the exception trace with sensitive filtering, fix deterministically, and requeue only affected connection IDs. |
| membership pending | User has not completed Discord screening | Ask the user to open Discord and accept the server rules; role sync alone cannot complete screening. |
| stale queued/syncing | Job lag or an expired lease | Check Sidekiq health and queues; hourly reconciliation safely reclaims stale work. |

## Production Enablement

Production enablement requires separate authorization after the staging canary.
When staging cannot be isolated from the live Discord provider, the documented
production-first override may be used instead: deploy feature-off, verify the
runtime and zero-mutation audit, recheck the live ELITE permissions, then enable
the flag only for the coordinated staff canary below.

1. Record a fresh database backup, deployed commit, and rollback owner.
2. Confirm the feature-off deployment is healthy and the audit output is
   understood.
3. Confirm the production callback, application ID, guild ID, VIP role ID, bot
   permissions, role hierarchy, membership screening, and ELITE category
   overwrites with a Discord administrator.
4. Enable the flag in the production `.envrc`, regenerate runtime environment
   through the normal production setup script, and restart Puma/Sidekiq.
5. Use a staff-owned account with no active Stripe subscription. If a safe
   production test entitlement is needed, have an administrator create a short
   complimentary Chu or Pandora manual grant for that account; never use a customer
   account or a real test card in live Checkout.
6. Run one staff canary through the dashboard Discord link, OAuth consent for
   only `identify` and `guilds.join`, guild join, membership screening, role
   grant, all six ELITE channels, manual revoke/expiry removal, re-grant
   recovery, unlink, and relink. Confirm no unrelated role changes.
7. Observe logs, Sidekiq retries, Admin connection state, and audit counts for at
   least one hourly reconciliation window.
8. Share `/join/pandora` only after the canary and observation window pass.

No bulk activation email is part of the initial rollout. Existing eligible
subscribers discover Discord through the persistent dashboard card.

## Credential Rotation

- Bot token rotation pauses guild join/role operations until the new value is
  installed in both Puma and Sidekiq. Existing links remain stored and do not
  require OAuth again; reconciliation repairs them after recovery.
- OAuth client-secret rotation affects new callback code exchanges. Existing
  linked role sync uses the bot token and continues if that credential remains
  valid.
- Application/client ID rotation requires a new OAuth application contract and
  callback review; treat it as a new integration, not a routine secret change.
- Guild or VIP role ID changes require Discord permission review and a controlled
  reconciliation. Never use cleanup against an unverified replacement role.

After any rotation, restart through the deployment script, run the audit, link
one staging/staff account, and observe one reconciliation cycle. Do not log old
or new values.

## Rollback And Cleanup

Fast rollback:

1. Set `DISCORD_INTEGRATION_ENABLED=false` in the authoritative environment
   source and rerun the setup script.
2. Confirm new OAuth starts, event sync, admin resync, and hourly reconciliation
   no longer mutate Discord.
3. Keep `discord_connections` rows for audit and later repair. Do not drop the
   additive table during an application rollback.
4. Confirm Chu/Pandora billing, licenses, courses, and the public Discord invite
   continue independently.

Disabling automation does not remove already granted roles. If product policy
requires role removal, obtain separate live-mutation authorization, verify the
guild/role IDs, take a fresh audit, and use the guarded command:

```bash
CONFIRM='REMOVE LINKED PANDORA VIP' bin/rails discord:vip:cleanup_linked_roles
```

The command removes only the configured VIP role (currently named Pandora VIP)
from linked users. It does not kick users, clear other roles, or delete connection rows. Any failure
leaves a safe failed state for targeted repair. Never run it merely to disable
the feature.
