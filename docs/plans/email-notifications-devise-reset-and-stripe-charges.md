# Plan: Email Notifications Devise Reset and Stripe Charges

## Goal
Implement reliable transactional email delivery for key Stripe charge outcomes (new subscription, upgrade, one-time purchase, renewal payment failed), while verifying Devise reset-password mail delivery and aligning sender/SMTP configuration with `SUPPORT_EMAIL`.

## Definition of Done
- Devise reset-password flow is covered by a request spec that verifies delivery count, sender, and reset URL host/protocol.
- `ApplicationMailer` default sender uses `Rails.configuration.x.branding.support_email`.
- Production SMTP settings are environment-driven and documented for GoDaddy Microsoft 365 mailbox credentials.
- New billing notification mailer/templates exist for:
  - subscription started
  - subscription upgraded
  - one-time purchase confirmed
  - subscription renewal payment failed
- Renewal payment failed notifications are deduplicated by Stripe `invoice.id`.
- Upgrade notifications trigger only for `billing_reason=subscription_update` and `amount_paid > 0`.
- No BCC is used.
- Targeted specs pass.

## Constraints
- Keep controllers thin and implement behavior in service objects/jobs/callback hooks.
- Preserve existing Pay/Stripe sync behavior and webhook idempotency.
- Use `deliver_later` for app mail notifications.
- Keep copy in I18n (`en`/`es`) and avoid inline user-facing strings.

## Steps
1. Add/reset-password verification spec and mail sender baseline changes.
2. Add SMTP configuration + environment/docs updates.
3. Add billing email delivery ledger for idempotent dedupe.
4. Add billing notifications mailer, views, and locale keys.
5. Wire subscription/upgrade/renewal-failed notifications from Stripe webhook events.
6. Wire one-time purchase notification from one-time purchase sync flow.
7. Add/update specs for new behavior and replay safety.
8. Run targeted specs and record results.

## Open Questions
- None.

## Execution Log (PASS/FAIL)
- PASS: Created active plan doc `docs/plans/email-notifications-devise-reset-and-stripe-charges.md` before coding.
- PASS: Added `spec/requests/devise_reset_password_mailer_spec.rb` to verify reset-password delivery, sender, and reset URL host.
- PASS: Added `spec/mailers/billing_notifications_mailer_spec.rb` to verify billing mailer sender uses `SUPPORT_EMAIL` via `ApplicationMailer`.
- PASS: Added `spec/services/billing/stripe_invoice_notification_processor_spec.rb` for subscription started/upgraded/renewal-failed classification and dedupe.
- PASS: Kept `Pay::Stripe::Webhooks::PaymentFailed` subscription alongside custom billing email webhook subscriber so Pay state sync remains intact.
- PASS: `bin/rails db:migrate`
- PASS: `bundle exec rspec spec/requests/devise_reset_password_mailer_spec.rb spec/services/billing/stripe_invoice_notification_processor_spec.rb spec/services/licenses/one_time_purchase_sync_spec.rb`
- PASS: `bundle exec rspec spec/services/billing`
- PASS: `bundle exec rspec spec/mailers/billing_notifications_mailer_spec.rb spec/requests/devise_reset_password_mailer_spec.rb spec/services/billing/stripe_invoice_notification_processor_spec.rb spec/services/licenses/one_time_purchase_sync_spec.rb`
