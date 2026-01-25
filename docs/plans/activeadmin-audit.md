# Goal
Audit the ActiveAdmin dashboard end-to-end, confirm admin CRUD coverage for all models that power user dashboard data, validate Stripe-linked creation flows and manual billing access, fix the "#class" form rendering issue, and expand admin test coverage with a full suite run.

# Definition of Done
- ActiveAdmin resources are inventoried and mapped to required domain models; any gaps for user dashboard data creation are documented with a proposed fix path.
- CRUD flows for core models (expert advisors, courses, marketplace assets/products, plans/entitlements, manual billing) are verified; Stripe product/price ID handling is correct in create/update flows (auto-create/update or pasted IDs, with failures blocking record persistence).
- Manual subscriptions and one-time purchase access paths are validated against expected user entitlements with no overlapping plan/product access; edge cases are documented or fixed.
- The "#class" rendering issue in admin forms is identified and resolved with a regression test.
- Admin-related specs are added/updated (request specs preferred, model specs where needed); full test suite is run and results captured, with rspec-timeout configured in `spec/spec_helper.rb`.

# Constraints
- Follow AGENTS workflow (plan-first, update plan with PASS/FAIL command log during execution).
- Keep controllers thin; push business logic to services/POROs where needed.
- No inline copy; use I18n (EN/ES) for admin labels/messages.
- Stripe/Pay calls must be idempotent; log errors with context.

# Steps
1) Discovery: inventory ActiveAdmin resources (`app/admin/*`) and map to domain model reference; identify required CRUD coverage and any missing admin resources.
2) User dashboard data audit: map user dashboard creation flows to the underlying models/associations using `docs/database_model_reference.md` and `config/routes.rb`; confirm which admin CRUD resources are required to keep the dashboard populated.
3) Billing/Stripe audit: trace models requiring Stripe IDs (BillingPlan/MarketplaceProduct or others) and verify admin creation flows populate Stripe product/price IDs correctly (auto-create/update or pasted IDs with existence checks). Accept test-mode IDs in dev/staging; enforce live in production.
4) Manual billing/access audit: verify manual subscription and one-time purchase flows grant entitlements without overlapping Pay subscriptions or marketplace purchases; implement the agreed conflict-avoidance rule (block manual when active Pay exists for same billing_plan, and block Pay checkout when manual exists for same billing_plan). "Active" manual subscription = status active and ends_at >= now.
5) Admin form QA: locate the "#class" rendering issue on relationship fields across all admin forms, isolate the root cause, and define a minimal fix.
6) Tests: add admin-focused request specs (plus model specs where needed) to cover CRUD, Stripe ID validation paths, and manual billing access; include regression spec for the form rendering bug. Adjust suite timeout with a general config change.
7) Verification: run full test suite and summarize results.

- Log (PASS/FAIL only):
  - PASS: initial discovery commands (ls; rg --files app/admin; sed on AGENTS/skills/docs/admin resources)
  - PASS: route + model audit (sed config/routes.rb; sed models/services for Marketplace/Billing/Manual*; rg for entitlements and admin form tags)
  - FAIL: bundle install (rspec-timeout gem unavailable in this environment)
  - FAIL: bundle exec ruby -e 'require "formtastic"; ...' (NameError without Rails environment)
  - FAIL: bundle exec rspec spec/requests/admin_forms_rendering_spec.rb (custom inputs not rendering; "#<Class:...>" present)
  - PASS: bundle exec rspec spec/requests/admin_forms_rendering_spec.rb
  - PASS: bundle exec rspec

# Open Questions
- Which user dashboard creation flows should we anchor on (e.g., pricing/checkout, marketplace, course enrollment, EA licensing, partner program), and are any of those driven by models not listed in `docs/database_model_reference.md`?

# Assumptions
- Apply a global `Timeout` around-hook with `RSPEC_TIMEOUT` defaulting to 60 seconds in `spec/spec_helper.rb` unless a stricter CI limit is required.

# Decisions
- Use Formtastic inputs plus lightweight model helpers for admin-only virtual fields to avoid Arbre capture issues in ActiveAdmin forms.
