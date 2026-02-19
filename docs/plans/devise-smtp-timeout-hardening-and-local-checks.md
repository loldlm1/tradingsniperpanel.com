# Plan: Devise SMTP Timeout Hardening and Local Checks

## Goal
Prevent password-reset requests from returning `500` when SMTP is slow/unavailable, and provide a reliable local/staging preflight workflow to validate SMTP credentials before deploy.

## Definition of Done
- Devise notifications are enqueued asynchronously (`deliver_later`) so reset-password HTTP requests do not block on SMTP.
- SMTP delivery config supports explicit timeout controls.
- A Rails task exists to validate SMTP connectivity/auth credentials from app env vars.
- README includes clear local/staging commands to test SMTP safely before production deploy.
- Development and staging default app flows do not send real SMTP emails.
- SMTP real-send checks remain explicit opt-in via task only.
- Specs cover the async Devise notification behavior.

## Constraints
- Keep current mail templates and sender behavior unchanged.
- Preserve existing Sidekiq/ActiveJob setup.
- Avoid broad mailer refactors outside Devise + SMTP diagnostics.
- Do not enable real SMTP delivery for regular requests in non-production environments.

## Steps
1. Update `User` Devise notification delivery to use background jobs.
2. Add SMTP timeout settings in production mailer config (env-driven).
3. Add `smtp:check` rake task to verify SMTP handshake/auth using current env.
4. Extend `.envrc.example` and README with SMTP preflight instructions.
5. Add/adjust model specs for Devise async delivery.
6. Ensure `smtp:check` works in development by reading SMTP env vars directly, without enabling regular app email delivery.
7. Run targeted specs and record PASS/FAIL.
8. Ensure non-production default behavior remains non-SMTP for regular requests, while keeping explicit SMTP test tasks functional.

## Open Questions
- None (requirements confirmed in user message).

## Execution Log (PASS/FAIL)
- PASS: Created active plan doc `docs/plans/devise-smtp-timeout-hardening-and-local-checks.md` before coding.
- PASS: Identified current synchronous Devise delivery path and SMTP production config in `app/models/user.rb` and `config/environments/production.rb`.
- PASS: Updated `app/models/user.rb` to override `send_devise_notification` and enqueue Devise emails with `deliver_later`.
- PASS: Updated `config/environments/production.rb` SMTP settings with env-driven `open_timeout`/`read_timeout`.
- PASS: Added `lib/tasks/smtp.rake` with `smtp:check` (auth/connectivity) and `smtp:send_test` (real send) preflight tasks.
- PASS: Updated `.envrc.example` with `SMTP_OPEN_TIMEOUT` and `SMTP_READ_TIMEOUT`.
- PASS: Updated `README.md` SMTP section with local/staging/production preflight commands.
- PASS: Added model coverage in `spec/models/user_spec.rb` for async Devise notification delivery.
- PASS: `bundle exec rails -T smtp && bundle exec rspec spec/models/user_spec.rb` (15 examples, 0 failures).
- PASS: Follow-up diagnosis: local `smtp:check` reported missing settings because it relied on Action Mailer config that is intentionally blank in development.
- PASS: Updated `lib/tasks/smtp.rake` to resolve settings from env + ActionMailer config and apply runtime SMTP settings for `smtp:send_test`.
- PASS: Validation command `SMTP_ADDRESS=127.0.0.1 SMTP_PORT=2525 ... bundle exec rails smtp:check` now fails on connect (`ECONNREFUSED`) instead of “missing SMTP settings”.
- PASS: `bundle exec rails -T smtp && bundle exec rspec spec/models/user_spec.rb` (15 examples, 0 failures) after follow-up patch.
- PASS: Added `config/environments/staging.rb` so staging is managed in-repo and defaults to no real mail delivery (`delivery_method=:test`, `perform_deliveries=false`).
- PASS: Updated `lib/tasks/smtp.rake` so `smtp:send_test` explicitly enables runtime deliveries only for that task execution.
- PASS: Updated docs in `README.md` and `.envrc.example` to clarify non-production default mail behavior and SMTP preflight semantics.
- PASS: Verification command `bundle exec rails runner 'puts ... ActionMailer::Base ...'` confirmed development defaults (`:test`, `false`, `false`).
- PASS: Verification command `bundle exec rails runner -e staging 'puts ... ActionMailer::Base ...'` confirmed staging defaults (`:test`, `false`, `false`).
- PASS: `bundle exec rails -T smtp` and `bundle exec rspec spec/models/user_spec.rb` (15 examples, 0 failures) after non-production mail delivery changes.
