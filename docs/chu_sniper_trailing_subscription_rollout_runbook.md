# Chu Sniper Trailing Subscription Rollout Runbook

This is the current operator runbook for the two-product subscription catalog.
It covers the additive Chu Sniper Trailing launch alongside the existing
Pandora Box tier, the idempotent license backfill, deployment verification,
staging rehearsal, observation, and rollback. It prepares operations only; it
does not authorize a production deploy, customer communication, Stripe live
catalog mutation, Discord role cleanup, or EA publication.

The historical Pandora procedure remains in
`docs/pandora_subscription_rollout_runbook.md`. Discord provider setup and
role operations remain in `docs/discord_vip_rollout_runbook.md`.

## Fixed Catalog Contract

| Product | Tier | Stripe product | Monthly | Annual | Includes |
| --- | --- | --- | ---: | ---: | --- |
| Chu Sniper Trailing | `chu_sniper_trailing` | `Chu Sniper Trailing` | `$19.99` (`1999` cents) | `$155.92` (`15592` cents) | Chu EA/tool, Discord VIP |
| Pandora Box | `pandora_pro` | `Pandora Box EA` | `$79.00` (`7900` cents) | `$616.20` (`61620` cents) | Pandora Box EA, Chu EA/tool, Discord VIP |

Canonical plan keys are `chu_sniper_trailing_monthly`,
`chu_sniper_trailing_annual`, `pandora_pro_monthly`, and
`pandora_pro_annual`. Each product's monthly and annual prices share one
Stripe product; Chu and Pandora use distinct Stripe products. Annual amounts
use integer cents and the existing 35% discount (`monthly_cents * 12 * 65 /
100`). Do not use floating point arithmetic.

The persisted entitlement matrix is six rows:

| Subscription plan pair | EA entitlements |
| --- | --- |
| Chu monthly and annual | `chu_sniper_trailing` only |
| Pandora monthly and annual | `pandora_box` and `chu_sniper_trailing` |

Both canonical tiers have a shared five-seat subscription cap and are eligible
for the configured Discord VIP role. Discord never grants Rails access. Chu is
an `ea_tool`, has no trial, no required add-ons, and does not submit daily
results. The existing Chu archive remains the source asset:
`docs_eas/chu_sniper_trailing/Chu_Sniper_Trailing.zip`.

## Preconditions And Safe Snapshots

Before a staging rehearsal or production deploy, record safe references only:

1. Pre-deploy commit and release tag.
2. Database backup references for the primary, cache, queue, and cable stores
   using the existing operational backup process.
3. A catalog snapshot containing plan keys, amounts, intervals, product IDs,
   active flags, EA IDs, and entitlement counts. Do not export license keys,
   Stripe secrets, customer payloads, account numbers, or Discord credentials.
4. Current active subscription/manual-grant aggregate counts and the count of
   Pandora licenses before the backfill. Preserve Pandora license IDs and key
   fingerprints, never raw keys.
5. Stripe test/live mode and webhook delivery status. Live product/price
   creation is a separately authorized operator action; this code does not
   create real Stripe objects from a local checkout.
6. The read-only MQL project has the `chu_sniper_trailing` profile, empty
   required-add-on list, disabled daily results, and the shared verify,
   heartbeat, and instance-magic paths. Compile it only after the Rails backend
   verifier is green.

## Deployment Order And Fail-Closed Hook

`script/setup_common.sh` is the authoritative deploy sequence for both staging
and production. Before assets or service restart it runs, in order:

```bash
RAILS_ENV=<staging-or-production> bin/rails db:prepare
RAILS_ENV=<staging-or-production> bin/rails db:seed
RAILS_ENV=<staging-or-production> DRY_RUN=false \
  bin/rails licenses:backfill_chu_subscription_licenses
RAILS_ENV=<staging-or-production> bin/rails catalog:subscriptions:verify
RAILS_ENV=<staging-or-production> npm run build:css
RAILS_ENV=<staging-or-production> bin/rails assets:precompile
```

The setup script stops on any non-zero command. Preparation and seeding run in
separate Rails processes so a new database does not emit duplicate constant
load warnings. The backfill is per-user,
transactional, retryable, and safe to run again; it creates or repairs only a
Chu subscription license for an active Pandora subscriber and never rotates a
Pandora key. The catalog verifier fails closed on missing/wrong amounts,
intervals, product associations, current price history, EA rows, or the exact
six-row entitlement matrix. `catalog:pandora:verify` remains a compatibility
alias for operators, but it is not the deploy authority.

Do not run a separate Pandora-only seed or retirement routine after Chu sales
exist. Do not delete Stripe products/prices or rewrite processor history.

## Staging Rehearsal

Use a staging database with fake/seeded users and Stripe test mode. Keep the
Discord integration disabled until its separate canary is authorized.

1. Set `SEED_PROFILE=prod_mirror` in the staging `.envrc` and verify the file
   is owned by the staging app user with mode `0600`.
2. Confirm staging Stripe, Discord, OAuth, and host values are isolated from
   production. Never print the values.
3. Run the normal setup entry point twice:

   ```bash
   sudo bash /opt/tradingsniperpanel-deploy/setup_staging.sh
   sudo bash /opt/tradingsniperpanel-deploy/setup_staging.sh
   ```

4. In the first run, capture only aggregate output from the seed, backfill, and
   verifier. The second run must produce unchanged plan/EA/entitlement counts
   and no unnecessary key rotations.
5. Exercise the backfill explicitly with a dry run and an apply/rerun using
   seeded users. The task accepts `BATCH_SIZE` and a comma-separated `USER_IDS`
   filter for a bounded rehearsal:

   ```bash
   DRY_RUN=true BATCH_SIZE=100 bin/rails licenses:backfill_chu_subscription_licenses
   DRY_RUN=false BATCH_SIZE=100 bin/rails licenses:backfill_chu_subscription_licenses
   DRY_RUN=false BATCH_SIZE=100 bin/rails licenses:backfill_chu_subscription_licenses
   ```

6. Run both verifier names and confirm the alias reaches the same authoritative
   check:

   ```bash
   bin/rails catalog:subscriptions:verify
   bin/rails catalog:pandora:verify
   ```

7. Exercise one Chu and one Pandora test subscription through Stripe test mode,
   webhook sync, license verify/heartbeat/instance-magic, five-seat limits,
   Discord eligibility, and a future manual grant. Use fake credentials and
   redacted IDs only. Do not use a real card, customer, account number, or
   production Discord guild.
8. Run the focused Rails/request suite, CSS build, browser smoke, and MQL
   compile listed in the final validation section.

Staging rehearsal status for this checkout is an operator gate, not an implied
completion claim. Record the backup reference, staging commit, aggregate
counts, webhook result, and rollback owner in the release ticket before live
enablement.

## Post-Deploy Observation

For the agreed observation window, record aggregate counts and redacted stable
references only:

- `GET /up`, public EN/ES pricing, and authenticated plan pages return healthy
  responses with both complete products.
- Puma, Sidekiq, and Nginx/systemd units remain active; inspect recent logs for
  seed, backfill, webhook, license, Discord, and queue errors without payloads.
- The catalog verifier reports four active canonical plans, two active EAs, six
  exact subscription entitlements, and no unexpected stale access.
- Backfill progress has no failed user IDs; rerun failures by bounded user list
  and investigate before enabling new sales.
- Stripe webhook processing, checkout/plan transitions, online-seat conflicts,
  license error codes, Discord retry state, downloads, and support reports show
  no unexpected drift, duplicate charge, duplicate commission, or unauthorized
  access.

Keep an owner and end time for the observation window. A provider failure must
remain visible and retryable; never rescue-and-forget it.

## Rollback And Recovery

### Before The First Chu Sale

1. Stop new Chu checkout by deactivating both Chu Stripe prices and, through a
   controlled catalog/admin change, marking both Chu billing-plan rows inactive.
   Confirm `Billing::SubscriptionCatalog.purchasable_scope` excludes both Chu
   keys; deactivating a remote Stripe price alone is not a sufficient UI gate.
2. Preserve the new Stripe product/price records and the Chu archive; do not
   delete history.
3. Restore the tagged application revision only after the database and catalog
   snapshot agree, then run the compatibility verifier and a read-only health/
   licensing smoke.

### After Any Chu Sale

1. Keep the multi-product catalog, resolver, v1 licensing API, and entitlement
   code deployed so existing Chu customers remain valid.
2. Disable new Chu sales through the catalog/Stripe activation gate. Do not
   revert to the old Pandora-only seed or retire Chu rows.
3. Let valid licenses expire normally, or revoke only newly created Chu rows
   through an approved, audited user-scoped operation. Never bulk-rotate or
   delete Pandora keys.
4. For Stripe transition failures, release only managed schedules through the
   existing cancellation service and preserve current periods and quantities.
5. For Discord failures, pause/retry role synchronization independently; Rails
   entitlement remains authoritative.
6. Restore application code from the tagged release, rerun the product-aware
   verifier, and retain the backup/catalog evidence for incident review.

## Final Validation Commands

Run the narrowest checks first, then the release gate:

```bash
bundle exec rspec spec/models spec/requests spec/services spec/jobs spec/lib
bin/rails zeitwerk:check
bundle exec rubocop
bundle exec brakeman --no-pager
npm run build:css
```

Run the compact Chromium smoke against a local isolated database or staging
URL. Cover public Neon pricing and signed-out plan handoff, authenticated
Mosaic plans in EN/ES, no-subscription/Chu/Pandora/current/scheduled/manual
states, desktop/mobile widths, keyboard/focus, console, and network failures.
Use only seeded/fake credentials and retain screenshots/traces only on failure.

For the read-only MQL handoff, from
`/home/loldlm/mql5_projects/metatrader_5_market_data_framework` run:

```bash
chu_entrypoint="$(winepath -w "$(pwd)/MQL5/Experts/HFT_Grid_AI/Chu_Sniper_Trailing.mq5")"
chu_build_log="$(winepath -w "$(pwd)/MQL5/Experts/HFT_Grid_AI/BUILD.log")"
wine MetaEditor64.exe /portable /compile:"$chu_entrypoint" /log:"$chu_build_log"
```

Treat warnings and errors as failures, inspect the fresh `BUILD.log`, and
remove it after recording the result. Do not edit the MQL repository or retain
the build log in Git.

## Release Record

### Current Checkout Validation Record

- Local disposable Rails rehearsal: passed seed/reconciliation, both verifier
  task names, Chu backfill dry-run/apply/rerun, and aggregate catalog checks.
- Fail-closed verifier rehearsal: passed wrong-amount, wrong-product, and
  missing-entitlement failure cases without printing secrets or license keys.
- Rails validation: passed 107 focused and 876 broad non-system RSpec examples,
  `bin/rails zeitwerk:check`, `npm run build:css`, setup-script shell syntax,
  and `git diff --check`.
- Browser QA: passed five isolated Chromium scenarios for EN/ES public pricing,
  signed-out Chu plan handoff, and no-subscription/Chu/Pandora dashboard states
  at desktop, tablet, and mobile widths. No horizontal overflow, console
  errors, or failed network requests were observed; no artifacts were retained.
- MQL handoff: the fresh MetaEditor compile log reported `0 errors, 0
  warnings`. Wine returned status `1`, so the compile log was treated as the
  authoritative result; the prior `.ex5` was restored and the temporary log
  removed without source changes.
- Baseline-only quality findings: full RuboCop reports 671 existing offenses;
  the branch-targeted set reports 36 existing offenses in `db/seeds/shared.rb`.
  Brakeman reports two existing weak-SQL warnings in
  `app/services/dashboard/main_presenter.rb`, and its binstub also rejects the
  installed scanner version as not latest. No new finding maps to this sprint.
- Staging Stripe/Pay, Discord provider, backup/restore, and live rollback
  rehearsal: not run from this checkout because no staging credentials or
  production access were used. Complete those operator gates before enablement.
- Backup and Stripe catalog snapshot: not captured here; record redacted
  references in the release ticket immediately before a staging/live deploy.
- Observation owner/window: release operator; monitor the first 24 hours after
  enablement and record the end time, aggregate signals, and next action.
- Residual risk: provider and infrastructure behavior remains unverified;
  owner is the release operator, signal is the verifier/webhook/license/Discord
  aggregate dashboards, and the next action is the staging rehearsal.

Before closing the release, record:

- Sprint commits and release tag.
- Backup and Stripe catalog snapshot references.
- Staging rehearsal result and any skipped live-provider checks.
- Final verifier, backfill, Rails, security, CSS, browser, and MQL evidence.
- Observation owner/window, residual risk, signal, and next action.
- Rollback decision and the exact feature/catalog gate used.
