# Plan: Mailer Branding and Template Modernization

**Status**: Implemented, audit PASS
**Generated**: 2026-03-09
**Estimated Complexity**: Medium
**Skills**: planner, rails-expert, frontend-design

## Overview
- Replace the current barebones email presentation with a shared branded mailer system for both Devise and billing emails.
- Standardize sender identity so inboxes show the product brand instead of the raw mailbox local-part like `admin`.
- Improve deliverability by pairing code changes with an operational checklist for authenticated sending and safer content patterns.

## Definition of Done
- All user-facing emails use a branded sender display name derived from an agreed source of truth.
- Devise emails and billing emails share a reusable HTML and text email system with modern branded styling and localized copy.
- Subject lines are owned by app locale files and consistently include or reflect the agreed product brand.
- Existing auth and billing flows keep working with updated specs for sender, subject, rendered body, and key links.
- The rollout includes a deliverability checklist covering DNS/authentication and mailbox reputation items outside Rails code.

## Locked Decisions
- Scope includes every current user-facing mailer in the app: Devise notifications plus billing notifications.
- English and Spanish mail subjects and bodies ship together in the first pass.
- Email branding should use a hybrid env-backed policy rather than hardcoded strings.
- Recommended branding rule:
  - Sender display name: `APP_NAME (APP_SHORT_NAME)` when `APP_SHORT_NAME` is present and different; otherwise `APP_NAME`.
  - Subject branding: use `APP_SHORT_NAME` when present for compact trust-first subjects, with `APP_NAME` still available in body/footer copy.
- Visual direction is conservative and trust-first rather than decorative or marketing-heavy.
- Emails should be reply-enabled and route replies back to the real support mailbox.
- First rollout should stay operationally simple:
  - keep the existing SMTP provider and auth flow
  - verify minimum deliverability prerequisites already in place
  - do not expand into a Microsoft 365 replatform or complex mail infrastructure project
- First rollout should avoid extra email rendering gems unless implementation friction proves high; prefer standard Action Mailer layouts, partials, and explicit inline-safe markup.

## Constraints
- Keep Rails conventions: thin mailers, shared layouts/partials, I18n-driven copy, and targeted specs.
- Preserve multipart email support so HTML and plain text alternatives are both available.
- Avoid inline one-off strings in templates; use locale keys and branding helpers/config.
- Do not assume design alone fixes spam placement; code changes must be paired with SMTP/domain verification work.
- Keep implementation compatible with the existing `branding` initializer and environment-driven app identity.
- Keep the visual system email-client-safe: restrained styling, no dependency on web fonts, and markup that survives Gmail and Outlook.

## Current State
- [`app/mailers/application_mailer.rb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/mailers/application_mailer.rb) sets `from` to the raw support email only, so a mailbox like `admin@...` is what many inboxes display.
- [`config/initializers/devise.rb`](/home/loldlm/rails_projects/tradingsniperpanel.com/config/initializers/devise.rb) sets `mailer_sender`, but Devise still uses its default mailer class and default English subject keys from [`config/locales/devise.en.yml`](/home/loldlm/rails_projects/tradingsniperpanel.com/config/locales/devise.en.yml).
- [`app/views/layouts/mailer.html.erb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/layouts/mailer.html.erb) and [`app/views/layouts/mailer.text.erb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/layouts/mailer.text.erb) are effectively empty wrappers.
- Billing mailers already have HTML and text templates, but the HTML is plain paragraphs and links rather than a branded componentized layout.
- Devise mailer views exist only as simple HTML templates under [`app/views/devise/mailer`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/devise/mailer); there are no matching text templates today.
- When `.envrc` is sourced, branding resolves to `APP_NAME=Global Trading Society`, `APP_SHORT_NAME=GTS`, and `SUPPORT_EMAIL=admin@tradingsniperpanel.com`; when env is not loaded, Rails falls back to initializer defaults. That environment consistency matters for rollout and testing.
- Current automated coverage is minimal: one request spec checks Devise reset email sender/host, and one mailer spec checks billing sender.
- There are no existing mailer previews and no current explicit mail headers for branded display names or reply handling.

## Sprint 1: Branding Source of Truth
**Goal**: Lock down how sender names, subject prefixes, and shared brand metadata are derived.
**Demo/Validation**:
- A single helper/config object can answer sender display name, sender mailbox, reply-to, and subject branding for mailers.
- Team can preview the exact branded `From:` format to be used in Devise and billing mailers.

### Task 1.1: Define outbound email brand policy
- **Location**: `config/initializers/branding.rb`, `app/helpers/application_helper.rb`, possible `app/services/branding/*`
- **Description**: Expose explicit helpers for sender display name, support mailbox, reply-to, subject prefix, and footer brand details from the existing env-backed branding config.
- **Dependencies**: None
- **Acceptance Criteria**:
  - One agreed source of truth exists for sender display name and subject prefix behavior.
  - The display name differs from the raw mailbox local-part and is stable across mailers.
  - Hybrid branding is derived from `APP_NAME` and `APP_SHORT_NAME` with sane fallbacks.
  - Env fallback behavior is explicit so development/staging/production do not silently diverge.
- **Validation**:
  - Helper/service specs for the derived email identity values.

### Task 1.2: Decide deliverability-related mail headers
- **Location**: `app/mailers/application_mailer.rb`, possible shared concern/service
- **Description**: Add explicit handling for `from`, `reply_to`, and any safe headers that improve trust without misrepresenting the sender.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - `From:` uses branded display name plus mailbox.
  - `reply_to` points to the real support mailbox for all reply-enabled emails unless a mailer has a documented exception.
  - Any extra headers are intentional and compatible with the mail provider in use.
- **Validation**:
  - Mailer specs assert headers on representative emails, including display name rather than only raw `mail.from`.

## Sprint 2: Shared Email Template System
**Goal**: Build a reusable branded mailer layout and partial structure that supports HTML and text versions cleanly.
**Demo/Validation**:
- One billing email and one Devise email render through the same branded shell.
- Text alternative remains readable and complete.

### Task 2.1: Create the shared HTML mailer shell
- **Location**: `app/views/layouts/mailer.html.erb`, `app/views/mailers/_*.html.erb`, possible asset helpers
- **Description**: Introduce a cohesive email layout with restrained brand lockup, clear callout section, primary CTA style, support footer, and conservative email-client-safe markup.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Layout is table-safe or otherwise email-client-safe for major inboxes.
  - Design direction is modern, polished, and trust-first rather than decorative.
  - Footer supports legal/contact fields already available through branding config.
  - Layout gracefully handles missing optional support channels.
  - Styling is compatible with Gmail and Outlook without relying on external font loading.
- **Validation**:
  - Render specs or preview-style mailer specs for representative emails.

### Task 2.2: Create the shared text template system
- **Location**: `app/views/layouts/mailer.text.erb`, `app/views/devise/mailer/*.text.erb`, `app/views/billing_notifications_mailer/*.text.erb`
- **Description**: Ensure every user-facing email has a clean plain-text alternative with the same critical information and CTA URLs.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Devise emails gain text templates where missing.
  - Billing emails keep text output aligned with the new branded structure.
  - HTML-only content does not hide critical instructions.
- **Validation**:
  - Mailer specs assert multipart emails and verify text-part content.

## Sprint 3: Devise and Billing Integration
**Goal**: Bring all mailers under the shared branded system with localized subject ownership.
**Demo/Validation**:
- Reset-password and billing confirmation emails show branded sender, branded subject, and modern shared layout.
- Locale switching still drives the copy and links correctly.

### Task 3.1: Introduce a custom Devise mailer
- **Location**: `app/mailers/`, `config/initializers/devise.rb`, `app/models/user.rb`
- **Description**: Replace the default Devise mailer with a custom Devise mailer wired through `config.mailer`, preserving Devise behavior while applying the shared branding and layout system.
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**:
  - Devise mailer follows Devise's supported customization path and preserves template lookup for `devise/mailer`.
  - Shared branding behavior is applied via `config.parent_mailer`, shared module inclusion, or another documented approach that does not fight Devise internals.
  - Reset, confirmation, unlock, email-changed, and password-changed flows use shared branding behavior.
  - Async delivery from `User#send_devise_notification` still works unchanged from the caller side.
- **Validation**:
  - Request or mailer specs for reset-password and at least one additional Devise notification.

### Task 3.2: Move subject copy into app locales and brand-aware formatting
- **Location**: `config/locales/en.yml`, `config/locales/es.yml`, possible removal/reduction of `config/locales/devise.en.yml`
- **Description**: Define explicit localized subject lines and subject-prefix rules so subjects no longer rely on Devise defaults and consistently reflect the chosen hybrid brand.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Devise subjects are localized and brand-aware.
  - Billing subjects align with the same branding convention.
  - Subject copy avoids spammy patterns such as excessive caps, symbols, or vague sender/subject mismatch.
  - The chosen format stays concise enough for Gmail and Outlook subject display.
- **Validation**:
  - Specs assert subject lines for EN and ES examples where relevant.

### Task 3.3: Refactor billing templates onto the shared shell
- **Location**: `app/mailers/billing_notifications_mailer.rb`, `app/views/billing_notifications_mailer/*`
- **Description**: Rebuild billing emails to use reusable content sections while preserving current transactional details and localized routing.
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**:
  - Existing billing notifications preserve plan, amount, invoice, receipt, and support data.
  - CTA hierarchy is visually clearer and consistent with Devise emails.
  - HTML and text parts remain in sync.
- **Validation**:
  - Mailer specs for all billing notification types or shared examples covering each variant.

## Sprint 4: Deliverability Hardening and Verification
**Goal**: Reduce avoidable spam signals and document the operational work needed outside the Rails app.
**Demo/Validation**:
- Team can run an end-to-end test email and verify headers, links, and rendered content.
- Deliverability checklist is attached to the rollout plan.

### Task 4.1: Add deliverability checklist and smoke-test path
- **Location**: `lib/tasks/smtp.rake`, `docs/`, plan file
- **Description**: Document the minimum deliverability checks that should already be true for the current SMTP provider: SPF, DKIM, DMARC awareness, sender-domain alignment, mailbox reputation, and content QA steps.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Plan distinguishes app-code work from lightweight verification of provider/domain setup.
  - Existing SMTP test tasks are included in verification steps.
  - Team knows which inbox checks to run before rollout without expanding the project into a mail-ops overhaul.
- **Validation**:
  - Manual verification checklist and sample commands documented.

### Task 4.2: Expand automated coverage for outbound email behavior
- **Location**: `spec/requests/devise_reset_password_mailer_spec.rb`, `spec/mailers/billing_notifications_mailer_spec.rb`, new mailer/render specs
- **Description**: Increase tests around sender identity, multipart structure, subject localization, and shared layout rendering.
- **Dependencies**: Sprints 2-3
- **Acceptance Criteria**:
  - Representative Devise and billing emails assert `from`, subject, HTML body, and text body.
  - Tests cover at least one non-default locale path.
  - Regressions like raw `admin` sender display are caught at the header-formatting level.
- **Validation**:
  - Targeted RSpec mailer/request runs for affected specs.

## Potential Risks and Gotchas
- Spam placement is often caused more by SPF/DKIM/DMARC alignment and domain reputation than by template quality alone.
- Some email clients strip CSS aggressively, so the layout must favor email-safe markup and restrained styling.
- Using `APP_SHORT_NAME` in some places and `APP_NAME` in others can create inconsistent sender/subject/body branding if the policy is not explicit.
- Devise subject overrides can be easy to partially wire, leaving some notifications on default copy unless every flow is accounted for.
- If the deployment environment is not actually loading the same env vars as local `.envrc`, sender identity may differ between environments even after code changes.
- `SMTP_ENABLE_STARTTLS_AUTO=true` and a correct `SMTP_DOMAIN` help transport security and HELO/domain configuration, but they do not by themselves guarantee inbox placement.

## Rollback Plan
- Keep the custom mailer integration isolated so the app can temporarily fall back to the previous minimal templates if a rendering regression is found.
- Preserve the existing SMTP smoke-test tasks and validate default sender behavior before and after deploy.
- Roll back subject/template changes independently from DNS/provider changes if the issue is operational rather than code-level.

## Documentation Notes
- Rails Action Mailer supports shared layouts and multipart delivery when both `.html.erb` and `.text.erb` templates exist for a mail action.
- Devise's supported customization path is to configure `config.mailer` with a custom mailer class and keep the Devise mailer template path intact.
- Devise subject lines are designed to be overridden through I18n keys, which fits the planned EN/ES branding cleanup.

## Remaining Questions
- None. The plan is aligned enough to start implementation.

## Execution Summary
- PASS: Added env-backed outbound email branding helpers in [`config/initializers/branding.rb`](/home/loldlm/rails_projects/tradingsniperpanel.com/config/initializers/branding.rb) and [`app/mailers/application_mailer.rb`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/mailers/application_mailer.rb), including branded `From:` formatting and reply-enabled `reply_to`.
- PASS: Added a custom [`DeviseMailer`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/mailers/devise_mailer.rb), configured Devise to use `ApplicationMailer` as the parent mailer, and moved Devise subjects to brand-aware localized keys.
- PASS: Replaced the empty mailer layouts with a conservative shared HTML/text email shell and reusable partials under [`app/views/shared/mailer`](/home/loldlm/rails_projects/tradingsniperpanel.com/app/views/shared/mailer).
- PASS: Refactored all current Devise and billing templates to the shared message system, added missing Devise text templates, and aligned billing subjects around the compact subject brand.
- PASS: Added [`docs/email_deliverability_checklist.md`](/home/loldlm/rails_projects/tradingsniperpanel.com/docs/email_deliverability_checklist.md) and updated the SMTP smoke-test sender formatting.
- PASS: Expanded mail coverage with branded sender, multipart rendering, localized subject, and layout assertions in request and mailer specs.

## Audit Gate
- **Code Pattern and Efficiency**: PASS
  Shared branding logic lives in `ApplicationMailer` and the branding initializer instead of being duplicated across templates. Devise customization follows the supported `config.mailer` and `config.parent_mailer` path. Billing templates were simplified by moving common structure into reusable mailer partials.
- **Feature Behavior and Goal Alignment**: PASS
  All current user-facing mailers now render through the branded HTML/text shell, reply to the support mailbox, and use localized subjects that no longer expose the raw mailbox local-part as the visible sender identity. The design direction stayed conservative and trust-first.
- **Tests Context**: PASS
  Targeted request and mailer specs now cover the real reset-password delivery flow, custom Devise mailer rendering, billing mailer rendering, multipart presence, localized subjects, and branded `From:`/`Reply-To` headers. Remaining gap: no browser-preview workflow was added; verification stays spec-driven plus SMTP smoke tests.

## Commands Run
- PASS: Read `AGENTS.md`
- PASS: Read planner, rails-expert, and frontend-design skill instructions
- PASS: Inspected current mailers, layouts, branding initializer, locale files, SMTP task, and mailer specs
- PASS: Confirmed sourced `.envrc` resolves `APP_NAME`, `APP_SHORT_NAME`, and `SUPPORT_EMAIL` differently from initializer defaults
- PASS: Retrieved current Rails Action Mailer and Devise mailer customization docs via Context7
- PASS: `bundle exec rails runner 'mail = BillingNotificationsMailer.with(...).subscription_started; ...'`
- PASS: `bundle exec rspec spec/requests/devise_reset_password_mailer_spec.rb`
- PASS: `bundle exec rspec spec/mailers/devise_mailer_spec.rb`
- PASS: `bundle exec rspec spec/mailers/billing_notifications_mailer_spec.rb`
- PASS: `git diff --check`
