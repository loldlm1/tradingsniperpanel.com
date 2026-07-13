# Pandora Subscription Rollout Runbook

This runbook covers the Pandora-only subscription catalog, renewal migration,
manual access, and versioned license-token rotation. It does not authorize a
production deploy, customer communication, EA publication, or token rotation.

## Fixed Contracts

- Active plans: `pandora_pro_monthly` at `7900` USD cents per month and
  `pandora_pro_annual` at `61620` USD cents per year.
- The annual amount is `7900 * 12 * 65 / 100`, a 35% discount.
- Both prices belong to one Stripe product named `Pandora Box EA`.
- Existing renewable subscriptions keep their price and quantity through their
  current period, then move to the interval-matched Pandora price without
  proration. Subscriptions already ending are not scheduled to renew.
- Roles never grant product access. Access comes from a current paid Stripe
  subscription or an active manual Pandora grant.
- API request/response JSON is unchanged. Version 1 license payloads contain
  `email,ea_id,expires_at`; version 2 and later add a positive
  `token_version` fourth field.
- Admin rotation increments the token version. Stripe renewal reissues only that
  user's subscription key with the renewed period end while preserving the
  existing token version and admin rotation timestamp.

## Hard Safety Gates

Do not deploy or rotate tokens until all applicable items are confirmed:

- The Pandora EA at MQL5 commit `59b03b0` or later compiles with zero errors
  and zero warnings.
- MQL5 validation uses the documented MetaEditor compile only. Do not add or
  retain auxiliary MQL5 test scripts for this rollout.
- That compatible EA build is distributed and confirmed as the supported
  customer build before any version 2+ token is issued.
- The Rails migrations are reviewed as additive and compatible with the old
  running process.
- A database backup and the pre-deploy Rails commit are recorded through the
  existing operational backup process.
- Staging uses Stripe test mode and contains no production customer data.
- Focused/broad Rails checks, CSS build, browser QA, two seed passes, catalog
  verification, and the annual schedule rehearsal are green.
- No unmanaged Stripe subscription schedule is present for a subscription that
  must migrate. A conflict must stop reconciliation before catalog retirement.

Never print or copy license keys, decrypted payloads, Stripe secrets, raw
provider objects, customer emails, or payment details into commands or logs.

## Staging Rehearsal

1. Set `SEED_PROFILE=prod_mirror` in the staging `.envrc` for the rehearsal.
2. Run the existing single entry point:

```bash
sudo bash /opt/tradingsniperpanel-deploy/setup_staging.sh
```

3. Confirm that the script completes database preparation, `db:seed`, and
   `catalog:pandora:verify` before assets and service restart.
4. Run the same staging deploy a second time. Counts, plan keys, Stripe price
   mappings, entitlements, schedules, and revocations must remain unchanged.
5. In Stripe test mode, confirm a representative annual subscription keeps its
   current item/quantity until `current_period_end` and has a verified next
   phase at `61620` USD cents per year.
6. Rehearse a Stripe creation/scheduling failure. The old catalog must remain
   locally active and the setup script must stop before service restart.
7. Review `Admin -> Subscription Audits` using seeded/non-sensitive QA data and
   complete the focused EN/ES desktop/mobile browser checks.

## Production Deploy

Use only the existing production entry point:

```bash
sudo bash /opt/tradingsniperpanel-deploy/setup_production.sh
```

The preparation order is fail-closed:

1. Apply additive migrations.
2. Create or verify the shared Pandora Stripe product and both prices.
3. Persist current and retired local price history.
4. Upsert the Pandora EA and its monthly/annual entitlements.
5. Verify exact plan keys, amounts, intervals, product identity, and price
   mappings.
6. Inventory Stripe subscriptions, manual grants, one-time licenses, and role
   licenses using counts and stable IDs only.
7. Create or verify renewal schedules and persist safe retry metadata.
8. Retire stale local/Stripe purchase paths and revoke unexpected access.
9. Run `catalog:pandora:verify` again.
10. Build assets and restart services only after every prior step succeeds.

Do not run a separate manual production seed before or after this script unless
recovering a documented failed deployment.

## Post-Deploy Checks

1. Confirm the application health endpoint/public page responds normally.
2. Confirm Puma and Sidekiq are active through the existing systemd units.
3. Review recent Rails and Sidekiq logs for reconciliation, webhook, queue, and
   provider errors without exposing payloads.
4. Run `bin/rails catalog:pandora:verify` under the production environment.
5. Confirm exactly two active plans, one active Pandora EA, two Pandora
   entitlements, and no active marketplace/add-on checkout product.
6. In `Admin -> Subscription Audits`, review each current subscription's period
   start/end, current price, invoice/payment totals, promotions, refunds,
   license status, token version, and safe schedule references.
7. Confirm the known annual subscription still uses its old price for the
   current period and changes to `$616.20/year` only at its period end.
8. Observe Stripe webhooks, Pay synchronization, Sidekiq retries, and error logs
   through at least one normal billing event before closing the release window.

## Schedule And Catalog Rollback

Stripe schedules and PostgreSQL changes are not one transaction. Stop and
inventory the affected subscriptions before changing either side.

Before a scheduled transition becomes effective:

1. Use the stored `pandora_catalog_schedule_id` for the local Pay subscription
   and release it with `Billing::StripeSubscriptionSchedule#release`.
2. Clear only the matching Pandora migration metadata after Stripe confirms the
   schedule is released. Preserve unrelated Pay/Stripe metadata.
3. If old checkout must be restored, reactivate the exact prior Stripe product
   and prices first, then restore the corresponding local `BillingPlan` and
   `BillingPlanPrice` current mappings from retained history.
4. Restore application filtering and presentation only after provider and local
   catalog state agree. Re-enabling UI alone is not a rollback.
5. Re-run focused billing checks and catalog verification before restarting
   services.

After a transition becomes effective, do not silently swap the price back or
create proration. Schedule a prospective correction for a future period or
handle the subscription manually with an auditable customer-approved action.

Manual grants are never deleted for rollback. Cancel or supersede them while
preserving the original period, payment status, notes, recorder, and audit event.

Token rotation is intentionally irreversible: the previous encrypted key is
not retained. Recover by issuing another new token, never by attempting to
restore the prior token.

## Manual Pandora Grant

1. Open `Admin -> Manual Subscriptions -> New`.
2. Select the user, Pandora monthly or annual plan, and grant days (`1..730`).
3. Leave payment fields empty for a complimentary grant, record a non-zero
   pending amount without a paid date, or record a positive paid amount/date.
4. Submit once. The request ID makes a retry idempotent and creates a safe
   `manual_subscription.granted` audit event.
5. Confirm the resulting start/end dates and license in
   `Admin -> Subscription Audits`.

An active Stripe subscription blocks a new manual grant. If Stripe becomes paid
after a manual grant, Stripe access wins and remaining manual access is marked
`superseded` with the Pay subscription reference.

## License Token Rotation

1. Confirm the compatible Pandora EA is distributed and customer compatibility
   is accepted. Compilation alone is not enough.
2. Confirm licensing secrets are configured without printing them.
3. For one user, open `Admin -> Subscription Audits -> <user>` and rotate the
   active/trial subscription licenses. Admin or master-admin authorization is
   required.
4. For all active/trial licenses, a master admin must use the dedicated
   confirmation page and type `ROTATE ALL`.
5. Confirm the `licenses.subscription_rotated` or `licenses.all_rotated` audit
   event, affected count, token versions, and rotation timestamp.
6. Verify the new token succeeds and the prior token returns `invalid_key` on
   verify, heartbeat, instance-magic, and daily-results requests.
7. Ask the user to refresh the EA detail page and use `Copy`; the page is
   non-cacheable, shows the complete key and token version, and copies the full
   current value including the changed suffix.

Never put either rotation action in seeds, migrations, deployment scripts,
background maintenance, or role-change callbacks.
