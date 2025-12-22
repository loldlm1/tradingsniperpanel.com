# Database Model Reference
Short, API-flavored map of the persisted data model so agents and developers can reason about queries and payloads without digging through migrations.

## Domain map
- Users authenticate via Devise and can originate from OAuth (`provider`, `uid`, `oauth_data`). `role` enum: `trader`, `partner`, `admin`.
- ExpertAdvisors describe each EA/tool (`ea_type`, `documents` JSON, `allowed_subscription_tiers`, `trial_enabled`); referenced by Licenses and UserExpertAdvisors.
- Licenses tie a User to an ExpertAdvisor with status (`trial`, `active`, `expired`, `revoked`), expiry fields, and an `encrypted_key`. BrokerAccounts hang off Licenses.
- UserExpertAdvisors is a soft-deletable join for entitlement tracking (`subscription_tier`, `pay_subscription_id`, `expires_at`, `deleted_at`).
- Referrals via the `refer` gem: referral_codes/visits/referrals tables connect referrers/referees; PartnerProfile leverages this.
- Partner program: PartnerProfile (one per partner User) → PartnerMembership (downline users, with `depth` and optional `referral_id`) → PartnerCommission rows (per charge/subscription, status, amounts, `commission_kind`) → optional PartnerPayoutRequest.
- Billing (Stripe via Pay gem): Pay::Customer, Pay::Subscription, Pay::Charge, Pay::PaymentMethod, Pay::Webhook keep processor state; `customer.owner_type` is `User`.

## Tables and key fields
- `users`: `email` (uniq), `encrypted_password`, `name`, `preferred_locale`, `time_zone`, `provider`/`uid`, `oauth_data` JSON, `terms_accepted_at`, `role` enum. Associations: `pay_customers`, `licenses`, `user_expert_advisors`, `partner_profile`, refer gem (`referrer`, `referral_codes`, `referrals`).
- `expert_advisors`: `name`, `description`, `ea_type` enum (`ea_robot`, `ea_tool`), `documents` JSON (doc keys → paths), `allowed_subscription_tiers` JSON array, `ea_id` (immutable slug/id), `trial_enabled`, `deleted_at`.
- `licenses`: `user_id`, `expert_advisor_id`, `status` (`trial`, `active`, `expired`, `revoked`), `plan_interval`, `expires_at`, `trial_ends_at`, `encrypted_key`, `source`, `last_synced_at`. Unique `user_id + expert_advisor_id`. Scopes: `active_or_trial`.
- `broker_accounts`: `license_id`, `company`, `account_number`, `account_type` enum (`real`, `demo`), optional `name`. Uniqueness: `company + account_number + account_type`.
- `user_expert_advisors`: `user_id`, `expert_advisor_id`, `subscription_tier`, `pay_subscription_id`, `expires_at`, `deleted_at`. Default scope filters `deleted_at`; scope `active` filters out expired/soft-deleted.
- `partner_profiles`: `user_id` (uniq), `discount_percent`, `payout_mode` enum (`once_paid`, `concurrent`), `stripe_coupon_id`, `active`, `started_at`. Scope: `active`.
- `partner_memberships`: `partner_profile_id`, `user_id` (one active at a time), optional `referral_id`, `depth`, `started_at`, `ended_at`. Scope: `active`.
- `partner_commissions`: `partner_profile_id`, `partner_membership_id`, `referred_user_id`, optional `referral_id`, `pay_charge_id`, `pay_subscription_id`, `payout_request_id`, `commission_kind` enum (`initial`, `renewal`), `status` enum (`pending`, `requested`, `paid`, `cancelled`), `amount_cents`, `currency`, `percent_applied`, `occurred_at`, `metadata` JSON. Scope: `pending_or_requested`.
- `partner_payout_requests`: `partner_profile_id`, `status` enum (`pending`, `paid`, `cancelled`), `total_cents`, `requested_at`, `paid_at`, `payment_reference`, `note`.
- `refer_referral_codes`: `referrer_type/id`, `code` (uniq), counters; `refer_referrals`: `referrer_type/id`, `referee_type/id`, optional `referral_code_id`, `completed_at`; `refer_visits`: `referral_code_id`, `ip`, `user_agent`, `referrer`, `referring_domain`.
- Pay tables (from `pay` gem): `pay_customers` (owner polymorphic, `processor`, `processor_id`, `default`, `data`), `pay_subscriptions` (status, current/trial periods, `processor_plan`, `ends_at`, `metadata`), `pay_charges` (amount, currency, `processor_id`, `subscription_id`, `application_fee_amount`, `metadata`), `pay_payment_methods`, `pay_merchants`, `pay_webhooks`.

## Common queries and services
- License access map: `Licenses::AccessibleExpertAdvisors` preloads `ExpertAdvisor.active.includes(:licenses)` and the user’s licenses/broker_accounts, returning per-EA entries with status, key, expiry, and allowed tiers.
- License verification API: `Licenses::LicenseVerifier` checks source, user/email, EA, license record, status, secure compares `encrypted_key`, and validates with `LicenseKeyEncoder`.
- Subscription sync: `Licenses::SubscriptionLicenseSync` resolves tier/interval from the Stripe price, generates/updates licenses per allowed EA, marks referral completed, and expires disallowed licenses.
- Trial provisioning: `Licenses::TrialProvisioner` (via `Licenses::CreateTrialLicensesJob`) issues `trial` licenses for trial-enabled EAs when keys are configured.
- Referrals: `Referrals::AttachReferrer` links a user by referral code, ensures their own code, and assigns partner membership; `Referrals::MarkCompleted` marks referral complete on successful subscription.
- Partner program: `Partners::MembershipManager` ensures partner profiles for partners, assigns memberships based on nearest upstream partner (with `depth`), and reassigns descendants via job. `Partners::CommissionBuilder` builds commissions from Pay charges (looks up net via Stripe, enforces once vs renewals). `Partners::PayoutRequestor` batches pending commissions into a payout request and marks them `requested`.
- Dashboard queries: `DashboardsController` pulls the latest active Pay subscription and last 20 charges; `Dashboard::PartnerController` searches memberships by user name/email (`ILIKE`), loads commissions with includes, aggregates sums for metrics, and counts active subscribers via `Pay::Subscription` join on owner IDs.
- API rate limit: `Api::V1::LicensesController#verify` caches per-email hits (60/min) and upserts BrokerAccounts (retrying on uniqueness conflicts).

## API surface
- `POST /api/v1/licenses/verify` (JSON only): params `source`, `email`, `ea_id`, `license_key`, optional `broker_account` payload (`name`, `company`, `account_number`, `account_type`). Success returns `ok`, `plan_interval`, `trial`, `expires_at`, optional `broker_account`. Errors: `user_not_found`, `ea_not_found`, `license_not_found`, `invalid_key`, `expired`, `trial_disabled`, `invalid_source`, `invalid_payload`, or `rate_limited`.

## Data flow highlights
- New user: Devise creates record; callbacks ensure referral code, partner profile (if role partner), enqueue `Licenses::CreateTrialLicensesJob`.
- Checkout/upgrade: `DashboardsController#checkout` resolves `price_key` → Stripe price, applies referral discount (via `Billing::ApplyReferralDiscount` + `Partners::DiscountResolver`/coupon), and redirects to Stripe Checkout; webhooks or subscription sync keep licenses aligned.
- Partner payouts: partners request payouts via `Dashboard::PartnerController#request_payout`, which groups pending commissions and marks them requested; `PartnerPayoutRequest#mark_paid!/mark_cancelled!` transition state and update related commissions.
