# Sniper Advanced Panel Companion Licensing

Chu subscriptions and manual grants include a separate Sniper Advanced Panel
license. Pandora includes both through its existing Chu entitlement. There are
still two purchasable products and four plans; there are now three active EAs
and ten entitlement rows. No new Stripe product, price, or database migration
is required.

## Compatibility

- Restore the historical `sniper_advanced_panel` record; keep its ID and the
  existing `docs_eas/sniper_advanced_panel/sniper_advanced_panel_ea.zip` archive.
- Users copy the Panel key from its own dashboard page. A CHU key remains
  invalid for the Panel EA identity.
- Newly created keys use v1: `email,ea_id,expires_at`. Existing token versions
  and rotation timestamps are preserved, including on repaired licenses.
- The shared older MQL guard accepts exactly three fields. Confirm the actual
  shipped Panel's EA ID, source, encryption, and v1 API through an MT5 demo
  activation before claiming binary compatibility. The older example under
  `license_eas/` uses different identifiers and is not the shipped source.
- Do not rotate a Panel key to v2+ until its client is confirmed to support the
  fourth field. The existing rotation service retains exact-key invalidation;
  this rollout does not downgrade versions or bypass verification.
- Subscription seats remain shared, and each EA/broker session counts toward
  the cap. Panel retains separate magic numbers and daily results. CHU remains
  excluded from daily-results ingestion.

## Deployment

Use the production entry point and backup process in
`docs/chu_sniper_trailing_subscription_rollout_runbook.md`. Record the previous
commit, database backup reference, and aggregate catalog/license counts. Keep
all private backup artifacts and logs outside tracked source.

The updated setup script performs these data steps before assets and restart:

```bash
RAILS_ENV=production bin/rails db:prepare
RAILS_ENV=production bin/rails db:seed
RAILS_ENV=production DRY_RUN=false bin/rails licenses:backfill_chu_subscription_licenses
RAILS_ENV=production DRY_RUN=false bin/rails licenses:backfill_panel_subscription_licenses
RAILS_ENV=production bin/rails catalog:subscriptions:verify
```

The Panel task defaults to dry-run, supports `BATCH_SIZE` and optional `USER_IDS`,
and retries per user. It requires a complete canonical entitlement set and
current paid Stripe or manual access. It does not grant access based on roles,
old licenses, expired subscriptions, or future manual grants. It never rewrites
Chu/Pandora keys. Repeating an apply must report no newly created or repaired
Panel licenses once synchronized.

Verify Puma, Sidekiq, Nginx, `/up`, and catalog verification after deployment.
Check a non-sensitive aggregate of active license counts and backfill failures.
On a controlled account, confirm the separate Panel key/download, CHU key
preservation, and the existing MT5 demo activation/heartbeat. Never print keys,
private account identities, or provider payloads in release evidence.

## Rollback

The code and data change is additive; no schema rollback is needed. Keep the
forward-compatible catalog while investigating. If Panel access must be
withdrawn, expire its subscription licenses and disable its entitlement in a
reviewed forward change; preserve CHU/Pandora keys and Stripe history.

Deploying an older commit through its setup script will retire the restored
Panel again. It also restores the older exact entitlement matrix. Do not run
that seed as an incidental code rollback after users receive Panel access.
