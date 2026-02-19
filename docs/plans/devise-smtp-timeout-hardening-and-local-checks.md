# Plan: Devise SMTP Timeout Hardening and Local Checks

## Goal
Prevent password-reset requests from returning `500` when SMTP is slow/unavailable, and provide a reliable local/staging preflight workflow to validate SMTP credentials before deploy.

## Definition of Done
- Devise notifications are enqueued asynchronously (`deliver_later`) so reset-password HTTP requests do not block on SMTP.
- SMTP delivery config supports explicit timeout controls.
- A Rails task exists to validate SMTP connectivity/auth credentials from app env vars.
- README includes clear local/staging commands to test SMTP safely before production deploy.
- Specs cover the async Devise notification behavior.

## Constraints
- Keep current mail templates and sender behavior unchanged.
- Preserve existing Sidekiq/ActiveJob setup.
- Avoid broad mailer refactors outside Devise + SMTP diagnostics.

## Steps
1. Update `User` Devise notification delivery to use background jobs.
2. Add SMTP timeout settings in production mailer config (env-driven).
3. Add `smtp:check` rake task to verify SMTP handshake/auth using current env.
4. Extend `.envrc.example` and README with SMTP preflight instructions.
5. Add/adjust model specs for Devise async delivery.
6. Run targeted specs and record PASS/FAIL.

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
