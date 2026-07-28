# Chu Sniper Trailing Backend Contract

Status: additive subscription contract for the Rails application.

This document is the Rails-side contract for the Chu Sniper Trailing product.
The MQL5 profile and transport details remain in the read-only framework at
`/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI`.

## Product identity and prices

| Field | Chu Sniper Trailing | Pandora Box |
| --- | --- | --- |
| Rails tier | `chu_sniper_trailing` | `pandora_pro` |
| Stripe product | `Chu Sniper Trailing` | `Pandora Box EA` |
| Monthly key | `chu_sniper_trailing_monthly` | `pandora_pro_monthly` |
| Annual key | `chu_sniper_trailing_annual` | `pandora_pro_annual` |
| Monthly amount | `1999` USD cents | `7900` USD cents |
| Annual amount | `15592` USD cents | `61620` USD cents |
| Annual rule | `1999 * 12 * 65 / 100` | `7900 * 12 * 65 / 100` |
| Annual discount | 35% | 35% |
| Seat cap | 5 shared subscription seats | 5 shared subscription seats |
| Discord VIP | Eligible | Eligible |

All money is integer cents. The annual Chu result is `$155.92`; no floating
point calculation is permitted. Monthly and annual prices for one product
share one Stripe product. Chu and Pandora use different Stripe products.
Existing Pandora product, price, subscription, and license identifiers remain
stable.

## Entitlement matrix

The catalog owns this matrix. A browser, EA, Discord role, or admin-supplied
tier cannot add an entitlement.

| Subscription tier | Chu EA | Pandora EA |
| --- | --- | --- |
| `chu_sniper_trailing` | Yes | No |
| `pandora_pro` | Yes | Yes |

The intended persisted rows are six `billing_plan_entitlements` records: one
for each of the two Chu plans and two for each of the two Pandora plans.
The two active `expert_advisors` are:

- `chu_sniper_trailing`, `ea_type=ea_tool`, trial disabled;
- `pandora_box`, `ea_type=ea_robot`, trial disabled.

Chu has no required add-ons, no trial, and no daily-results reporting. Its
download is the existing `docs_eas/chu_sniper_trailing/Chu_Sniper_Trailing.zip`
asset; seed reconciliation is checksum-aware and must not overwrite the input
archive.

## Licensing API

Chu uses the existing version 1 JSON endpoints. No Chu-specific endpoint,
field, status, or error code is added:

- `POST /api/v1/licenses/verify`
- `POST /api/v1/licenses/heartbeat`
- `POST /api/v1/licenses/instance_magic`
- `POST /api/v1/broker_accounts/daily_results` remains unsupported for Chu

The request identity includes `source`, `email`, `ea_id`, `license_key`, and a
validated `broker_account` object. Chu requests use
`ea_id=chu_sniper_trailing` and omit required add-ons (or send an empty list as
the existing client permits).

Successful `verify` responses retain `ok`, `expires_at`, `granted_addons`,
`magic_number`, `trial`, `plan_interval`, and the server-side broker account
object. `heartbeat` retains its existing response shape and does not rotate
the magic number. `instance_magic` retains its existing positive,
signed-32-bit-safe allocation contract.

The documented v1 error codes remain unchanged: `invalid_source`,
`invalid_key`, `trial_disabled`, `addons_required`, `user_not_found`,
`ea_not_found`, `license_not_found`, `invalid_payload`, `expired`,
`missing_magic_number`, `invalid_magic_number`, `rate_limited`,
`online_limit_reached`, `internal_error`, and the existing daily-results
codes. License keys, decrypted tokens, secrets, and private customer data must
not appear in responses, HTML, logs, telemetry, or diagnostics.

## Authority and access rules

- Rails subscription/manual records and active license rows are authoritative.
- Discord VIP is a downstream eligibility signal; a Discord role never grants
  Rails entitlement.
- Ownership, plan, expiry, add-on, and seat checks happen server-side.
- Backend-issued runtime magic is positive and signed-32-bit-safe.
- Current Pandora users receive a Chu license through a separate, idempotent
  backfill. The backfill never rotates, revokes, or rewrites a Pandora key.
- A failed or partial backfill is retryable per user and must not be replaced
  with the ordinary all-EA reconciler.

## Catalog and processor rules

- Only complete monthly/annual pairs are purchasable. A partial Chu pair must
  not hide a complete Pandora pair, and a partial pair must not expose a dead
  checkout option.
- Known plan keys are resolved by the catalog, not by splitting on the first
  underscore. Unknown legacy values retain a safe non-canonical fallback.
- Product access rank is used for cross-tier comparisons; raw prices are not a
  tier hierarchy.
- Stripe products/prices are created or reused idempotently. Price history is
  retained for invoices, audits, and rollback.
- Manual grants use the same canonical plan keys and effective period rules as
  Stripe subscriptions.

## Rollback boundary

Before the first Chu sale, disable Chu checkout and deactivate new prices if a
catalog issue is found. After a Chu sale, keep the forward-compatible catalog,
resolver, and v1 API deployed; disable new sales rather than running the old
Pandora-only retirement routine. Never delete Stripe history or rotate Pandora
keys as a rollback shortcut.
