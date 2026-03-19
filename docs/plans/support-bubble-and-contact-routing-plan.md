# Plan: Support Bubble And Contact Routing

**Generated**: 2026-03-19
**Estimated Complexity**: Medium
**Status**: Implemented, Audit PASS

## Goal
- Add a robust support bubble solution to the Rails app.
- Fix the authenticated dashboard "Contact us" flow so customer submissions trigger an internal email to `PARTNER_PAYOUT_REQUEST_RECIPIENTS`.

## Definition Of Done
- A support entry point is available in the app and matches the chosen provider/integration model.
- The dashboard support form submits through Rails, validates input, and delivers an internal notification email to the configured recipients.
- Delivery failures are observable and do not silently fail.
- The flow is covered by relevant request/mailer/job specs.
- Environment/config requirements are documented in `README.md` and `.envrc.example`.

## Constraints
- Follow Rails app patterns already used in the repo: thin controllers, mailers, jobs, I18n, and Sidekiq-backed Active Job.
- Keep support recipient configuration centralized around `PARTNER_PAYOUT_REQUEST_RECIPIENTS` unless a separate env var is intentionally approved.
- Do not wire a provider that bypasses the existing authenticated dashboard without an explicit product decision.
- Preserve EN/ES support for customer-facing copy.
- Keep the implementation lightweight: email-only for first-party support handling, no local support ticket system in v1.

## Confirmed Decisions
- General support emails should go to `PARTNER_PAYOUT_REQUEST_RECIPIENTS`.
- The support bubble should appear on public landing pages, auth pages, and the authenticated dashboard.
- The desired UX is true in-site two-way chat, not a launcher that opens a new tab/app.
- Email-only handling is acceptable for the first release.
- File attachments should be included in the first release.
- Phone notifications are desired for 1-2 admins, but WhatsApp is not required for v1.
- Free/open-source-first is preferred over paid SaaS.
- Chat should run on the existing Ubuntu 22.04 production server.
- The initial bubble rollout should be production-only.
- The support form should allow only image/screenshot attachments.
- The implementation plan should include both manual README steps and idempotent setup-script automation.
- Docker is accepted as the Chatwoot runtime on the production VPS.
- The simpler/safer support-form delivery path should be preferred.
- The main production hostname currently does not have subdomains available.
- The chosen v1 path is the fallback provider route rather than self-hosted Chatwoot.
- The recommended v1 fallback provider is `tawk.to`.
- A dedicated Rails `/chat` page is not needed for v1; the site-wide bubble is sufficient.

## Current State
- The authenticated support page exists at `app/views/dashboards/support.html.erb`.
- The current "Contact us" UI is not a real Rails form:
  - email is readonly from `current_user.email`
  - message is a plain textarea with no submitted params
  - CTA is a `mailto:` link to `support_email`
- There is already a working internal mailer pattern for partner payout notifications:
  - `app/mailers/partner_payout_requests_mailer.rb`
  - `app/jobs/partners/send_payout_request_notification_job.rb`
  - `spec/mailers/partner_payout_requests_mailer_spec.rb`
  - `spec/jobs/partners/send_payout_request_notification_job_spec.rb`
- Branding config already exposes support channel settings:
  - `SUPPORT_EMAIL`
  - `SUPPORT_PHONE`
  - `SUPPORT_CHAT_URL`
  - `SUPPORT_DISCORD_URL`
  - `SUPPORT_TELEGRAM_URL`
- Existing deploy automation under `script/` is already idempotent and suitable for extension:
  - `script/setup_common.sh` renders env files, writes systemd units only when changed, and rewrites Nginx from env state.
  - `script/setup_production.sh` and `script/setup_staging.sh` already self-update from the repo and provision services predictably.

## Overview
- Phase the work into two tracks:
  1. Repair the first-party support form so it reliably emails internal recipients.
  2. Add a support bubble integration behind a provider decision, with special attention to WhatsApp/admin-phone routing.
- Treat provider choice as a decision gate because WhatsApp support changes the feasible options, operational cost, and setup steps.

## Research Notes
- Current official provider docs indicate that real in-site chat widgets are typically added via vendor JavaScript embed, not a Rails gem wrapper.
- Current official docs from Chatwoot, Crisp, and tawk.to indicate WhatsApp support is tied to official WhatsApp Business / Meta onboarding flows, not personal WhatsApp numbers.
- Current official Chatwoot docs indicate self-hosted production is typically deployed via Docker and that agent mobile push notifications can work through the official Chatwoot mobile app relay path for self-hosted instances.
- Current official Chatwoot deployment examples center on a dedicated origin set via `FRONTEND_URL` and Nginx examples using a dedicated host such as `chat.yourdomain.com`.
- Because the user wants embedded two-way chat, mobile notifications for a very small admin team, a free-first path, and no dedicated hostname is available, the practical v1 decision is:
  - chosen for v1: `tawk.to` widget integration
  - future upgrade path when a dedicated hostname exists: self-hosted Chatwoot
  - explicitly avoid for v1: personal-WhatsApp-based embedded chat promises

## Provider Recommendation
- **Chosen for v1**: `tawk.to` embedded widget.
- **Why**:
  - no dedicated hostname is required for the Rails app to embed the widget
  - free entry point with low operational overhead
  - mobile apps are available for 1-2 admins to receive chat notifications
  - fastest path to a real in-site support bubble under the current DNS constraints
- **Future upgrade path**: self-hosted Chatwoot if/when a dedicated hostname becomes available.
- **Do not rely on**: personal WhatsApp numbers for embedded site chat. That expectation conflicts with the current official provider/Meta integration model.

## Recommended Rollout Shape
- **Phase A**: Fix the Rails support form first:
  - authenticated dashboard form
  - Active Storage attachments
  - internal support email to `PARTNER_PAYOUT_REQUEST_RECIPIENTS`
  - uploaded image links in the internal email rather than large binary attachments
- **Phase B**: Embed the `tawk.to` widget across the approved production pages and validate admin mobile notifications.
- **Phase C**: Improve authenticated-user identification inside chat once the base widget is stable.
- **Phase D**: Document the current provider setup in `README.md` and keep a future Chatwoot migration note rather than building server automation for v1.

## Sprint 1: Contact Form Baseline
**Goal**: Replace the current placeholder UI with a real support request flow using existing Rails patterns.
**Demo/Validation**:
- Signed-in user submits a support message from `/dashboard/support`.
- Internal recipients receive a formatted email in production.
- Request/mailer/job specs pass in test.

### Task 1.1: Model The Submission Path
- **Location**: `config/routes.rb`, `app/controllers/dashboards_controller.rb` or a dedicated controller, `app/services` or form object if needed.
- **Description**: Add a POST endpoint for support requests and define the minimum payload.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Server receives user identity and message body.
  - Blank/invalid submissions are rejected with user-visible feedback.
  - No mail is sent directly from the view.
- **Validation**:
  - Request spec for success and validation failure.

### Task 1.2: Add Internal Notification Mailer
- **Location**: `app/mailers`, `app/views`, optional `app/jobs`.
- **Description**: Create a dedicated support-request mailer that sends to `PARTNER_PAYOUT_REQUEST_RECIPIENTS`, with structured customer context.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Email includes customer name/email/id, locale, and message.
  - Email includes uploaded image links or attachments using a bounded, documented strategy.
  - Missing recipient config fails loudly in a controlled way.
  - Delivery is enqueued via job if we want consistency with existing async patterns.
- **Validation**:
  - Mailer spec.
  - Job spec if async delivery is introduced.

### Task 1.3: Replace Placeholder UI With Real Form
- **Location**: `app/views/dashboards/support.html.erb`, `config/locales/*.yml`.
- **Description**: Convert the support section into a real Rails form with flash/error states and translated copy.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Email is still prefilled from the signed-in user.
  - Message field persists validation errors.
  - Only image/screenshot file types are accepted with a small size limit.
  - Success/failure states are translated and visible.
- **Validation**:
  - Request spec or system spec for the support page flow.

## Sprint 2: Support Bubble Provider Decision
**Goal**: Select the bubble/channel architecture based on business and ops constraints.
**Demo/Validation**:
- Provider choice is documented with setup requirements, fallback behavior, and admin workflow.

### Task 2.1: Compare Provider Classes
- **Location**: plan/decision notes, `README.md`.
- **Description**: Compare at least these options:
  - `tawk.to` live chat widget
  - Crisp live chat widget
  - self-hosted Chatwoot as future migration path
- **Dependencies**: User clarification on WhatsApp/admin workflow.
- **Acceptance Criteria**:
  - Decision criteria cover cost, setup time, phone routing, GDPR/privacy, localization, agent mobile access, hostname constraints, and embed complexity.
  - `tawk.to` is locked as v1 with future Chatwoot noted as optional migration.
- **Validation**:
  - Decision recorded in this plan before implementation starts.

### Task 2.2: Define Integration Surface
- **Location**: likely `config/initializers/branding.rb`, helpers, layout partials, README.
- **Description**: Decide whether the bubble is globally injected, dashboard-only, marketing-only, or environment-gated.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Placement is explicit.
  - Bubble can be disabled cleanly when config is missing.
  - Tracking/privacy implications are documented.
- **Validation**:
  - Manual verification checklist for page placement and disable behavior.

### Task 2.3: Confirm Chat Service Hosting Model
- **Location**: deployment notes, README, ops checklist.
- **Description**: Confirm that v1 uses an embedded third-party widget and does not require a server-side chat deployment on the production VPS.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - No additional chat host, Docker stack, or Nginx host block is required for v1.
  - Rollback path to widget disablement is documented.
  - Future Chatwoot migration note is captured for when DNS constraints change.
- **Validation**:
  - Hosting checklist exists before implementation starts.

## Sprint 3: Bubble Implementation
**Goal**: Add the chosen support bubble safely and minimally.
**Demo/Validation**:
- Bubble appears in approved environments/pages.
- Click path opens the chosen support destination and does not break layout or performance.

### Task 3.1: Add Config And Initializer Support
- **Location**: `.envrc.example`, `config/initializers/branding.rb`, helper methods, README.
- **Description**: Add only the env vars required by the selected provider/channel.
- **Dependencies**: Sprint 2 decision.
- **Acceptance Criteria**:
  - Missing config is handled explicitly.
  - Secrets/tokens are not hardcoded.
- **Validation**:
  - Boot app with and without config.

### Task 3.2: Deploy Chat Service
- **Location**: provider dashboard/setup notes, `README.md`.
- **Description**: Provision the selected provider account/workspace and create at least one property plus 1-2 agent accounts.
- **Dependencies**: Sprint 2 decision.
- **Acceptance Criteria**:
  - Provider widget/property is configured and embeddable in production.
  - Agent mobile notifications are tested on at least one phone.
  - Embed token / website identifier is available for Rails.
- **Validation**:
  - Manual login and test conversation in the chat admin/mobile app.

### Task 3.3: Automate Chatwoot Server Setup
- **Location**: `README.md`, optional env/config notes in the Rails app.
- **Description**: For v1, avoid adding server-side chat automation because the chosen provider does not run on the VPS. Document only the minimal app-side configuration and keep Chatwoot automation as an explicit future enhancement.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - No unnecessary production-server automation is added for the hosted widget path.
  - README clearly distinguishes current v1 provider setup from future self-hosted Chatwoot automation.
- **Validation**:
  - Documentation review confirms no fake/unused automation is introduced.

### Task 3.4: Render Bubble Entry Point
- **Location**: layout/partial/assets chosen during implementation.
- **Description**: Add the actual bubble embed or floating launcher.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Desktop and mobile behavior are acceptable.
  - No inline vendor code is duplicated across views if a partial/helper can centralize it.
  - Public layout, auth screens, and dashboard all load the bubble in approved environments.
- **Validation**:
  - Manual browser QA on key pages.

### Task 3.5: Prefill Known User Identity
- **Location**: helper/partial/controller endpoints as needed by the selected provider.
- **Description**: Prefill known user identity for authenticated users and allow anonymous/public visitors to start with pre-chat capture.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Signed-in users do not need to manually re-enter name/email when the provider supports secure identification.
  - Public visitors can still start a chat and provide email/name through the widget.
- **Validation**:
  - Manual QA on logged-out and logged-in sessions.

## Sprint 4: Audit And Release Readiness
**Goal**: Verify behavior, reliability, and rollout safety.
**Demo/Validation**:
- Audit Gate recorded as PASS before feature completion.

### Task 4.1: Test Coverage Review
- **Location**: `spec/requests`, `spec/mailers`, `spec/jobs`, optional system spec.
- **Description**: Confirm coverage for support form submission, delivery behavior, and config edge cases.
- **Dependencies**: Prior sprints.
- **Acceptance Criteria**:
  - Tests cover happy path, validation errors, and missing-recipient misconfiguration.
- **Validation**:
  - Targeted spec run list captured in this plan.

### Task 4.2: Operational Readiness
- **Location**: `README.md`, plan notes.
- **Description**: Document env setup, recipient behavior, staging caveats, and provider onboarding steps.
- **Dependencies**: Prior sprints.
- **Acceptance Criteria**:
  - Team can configure the feature without reading implementation code.
  - README includes the current `tawk.to` production widget setup and Android/iOS notification steps.
  - README documents the app env vars required for the current support bubble path.
- **Validation**:
  - README updates reviewed against actual env vars.

## Testing Strategy
- Request spec for support form submit success/failure.
- Mailer spec for internal support notification rendering.
- Job spec if support mail is sent asynchronously.
- Manual QA for attachment upload in the dashboard support form.
- Manual QA in authenticated dashboard and chosen bubble surfaces.
- Manual QA for agent mobile notification delivery.
- Manual QA for production-only widget gating.

## Potential Risks And Gotchas
- `PARTNER_PAYOUT_REQUEST_RECIPIENTS` may be intended for finance-only notifications; reusing it for general support may mix inbox responsibilities.
- A WhatsApp requirement can force a provider choice away from simple Rails-only chat gems.
- Hosted chat widgets often require external JS, privacy review, and separate operator accounts.
- Staging currently uses `action_mailer.delivery_method = :test`, so end-to-end email behavior must be verified with an explicit production-like path.
- If the bubble is globally injected, it may appear on auth/legal pages where it is not wanted.
- Personal WhatsApp numbers are not a reliable basis for embedded website chat in the current official provider flows; v1 should not depend on that.
- Attachment handling in the email support form needs clear size/type limits and likely should prefer stored files plus mail links over large raw email attachments.
- Hosted widget providers introduce third-party JS and account-level operational dependencies.
- If the team later migrates to self-hosted Chatwoot, that should be treated as a separate infrastructure task once DNS constraints are solved.

## Open Questions
- None blocking for planning.
- Future-only: revisit self-hosted Chatwoot if a dedicated hostname becomes available.

## Implementation Notes
- Implemented a real support request flow on `POST /:locale/dashboard/support`.
- Added `SupportRequest` persistence plus image-only Active Storage screenshots.
- Added `SupportRequestsMailer` and `SupportRequests::SendNotificationJob` to send internal notifications to `PARTNER_PAYOUT_REQUEST_RECIPIENTS`.
- Embedded the production-only `tawk.to` widget through shared layout rendering, with optional secure visitor identification for signed-in users.
- Updated `README.md` and `.envrc.example` with the current `tawk.to` setup and mobile notification instructions.

## Commands Run
- PASS: `sed -n '1,240p' README.md`
- PASS: `sed -n '1,260p' AGENTS.md`
- PASS: `rg -n "Contact us|contact us|contact_us|support|bubble|chat|whatsapp|PARTNER_PAYOUT_REQUEST_RECIPIENTS|payout request|partner payout" app config lib spec db`
- PASS: `sed -n '1,240p' app/views/dashboards/support.html.erb`
- PASS: `sed -n '1,260p' config/routes.rb`
- PASS: `sed -n '1,240p' app/mailers/partner_payout_requests_mailer.rb`
- PASS: `sed -n '1,220p' app/jobs/partners/send_payout_request_notification_job.rb`
- PASS: `rg -n "ActiveStorage|has_one_attached|has_many_attached|direct_upload|active_storage" app config db spec`
- PASS: `sed -n '1,240p' app/views/layouts/application.html.erb`
- PASS: `sed -n '1,260p' app/views/layouts/dashboard.html.erb`
- PASS: `sed -n '1,220p' config/initializers/content_security_policy.rb`
- PASS: `sed -n '1,320p' script/setup_common.sh`
- PASS: `sed -n '1,260p' script/setup_production.sh`
- PASS: `sed -n '1,260p' script/setup_staging.sh`
- PASS: `sed -n '680,940p' script/setup_common.sh`
- PASS: `sed -n '510,680p' script/setup_common.sh`
- PASS: `Context7 resolve Chatwoot docs`
- PASS: `Context7 query Chatwoot docs`
- PASS: `Context7 query Chatwoot docs for dedicated-origin / FRONTEND_URL deployment constraints`
- PASS: `curl -L -s -o /dev/null -w '%{http_code}' https://help.tawk.to/article/...` for the README support-chat reference links
- PASS: `bin/rails db:migrate`
- PASS: `bundle exec rspec spec/requests/dashboard_support_spec.rb spec/jobs/support_requests/send_notification_job_spec.rb spec/mailers/support_requests_mailer_spec.rb spec/helpers/application_helper_spec.rb`
- PASS: `bundle exec rspec spec/requests/dashboard_spec.rb spec/requests/dashboard_support_spec.rb spec/jobs/support_requests/send_notification_job_spec.rb spec/mailers/support_requests_mailer_spec.rb spec/helpers/application_helper_spec.rb`

## Audit Gate
- PASS: Code pattern and efficiency
  - Controller remains thin; submission logic is in `SupportRequests::CreateAndNotify`.
  - Async delivery now follows the repo’s explicit job pattern via `SupportRequests::SendNotificationJob`.
  - Widget rendering is centralized in one shared partial and environment-gated in the helper.
- PASS: Feature behavior and goal alignment
  - Dashboard support form now submits through Rails, stores image screenshots, and routes internal email to `PARTNER_PAYOUT_REQUEST_RECIPIENTS`.
  - The `tawk.to` support bubble is wired for production-only layout injection across public/auth/dashboard pages.
  - README now explains provider setup and Android/iOS mobile notification onboarding for 1-2 admins.
- PASS: Tests context
  - Covered request success/failure, async job behavior, mail rendering, missing-recipient misconfiguration, and widget helper config.
  - Remaining manual QA is production-side provider onboarding and live widget/mobile notification verification.

## Rollback Plan
- Revert the support form route/controller/mailer changes.
- Disable the support bubble via env/config toggle.
- Keep the existing `mailto:` fallback available until the new flow is verified in production.
