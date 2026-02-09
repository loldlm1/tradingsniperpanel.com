# Plan: Remove Trials + Privileged Full Access + Stripe Copy Alignment

## Goal
Remove signup trial behavior and introduce privileged role-based full access (`admin`, `master_admin`, `full_trader`) across subscriptions, marketplace purchases, EA licenses, and courses, while blocking checkout for privileged users and aligning website legal copy with Stripe expectations for both recurring and one-time products.

## Definition of Done
- Trial creation on signup is removed from code paths and seeds.
- `full_trader` role exists and follows admin role assignment restrictions (master admin only for privileged elevations).
- Privileged roles get full access to EA, courses, marketplace assets, and add-ons without requiring paid entitlements.
- Privileged users cannot start checkout flows (subscription or marketplace) but can still view billing/invoice history pages.
- Role downgrade immediately revokes role-granted access.
- ToS/home/checkout wording is consistent for both subscriptions and one-time purchases in EN/ES locales.
- Specs updated/added for critical behavior and passing.

## Constraints
- Keep controllers thin; place access logic in service objects/policies.
- Preserve existing paid entitlement logic for non-privileged users.
- Make role-granted access idempotent and safe on repeated role changes.
- Keep locale copy in `I18n` files; avoid inline strings.

## Steps
1. Add/adjust role enum and role guard behavior for `full_trader` with master-admin-only privilege elevation.
2. Remove signup trial provisioning hooks and seed trial defaults/licenses.
3. Add centralized privileged access policy and wire it into EA/course/marketplace/add-on gates.
4. Ensure privileged users have working EA license verification via role-granted licenses and immediate revocation on downgrade.
5. Block checkout endpoints and update UI messaging/buttons for privileged accounts.
6. Update ToS/home/checkout locale copy to mention both subscriptions and one-time digital products.
7. Add/update model/service/request specs for roles, access gates, checkout blocking, and trial removal.
8. Run targeted and full specs; fix regressions.

## Open Questions
- None currently; user confirmed all key product decisions.

## Execution Log (PASS/FAIL)
- PASS: Read `AGENTS.md` and `rails-expert` skill instructions.
- PASS: Confirmed branch state with `git status --short --branch`.
- PASS: Created this active plan before implementation.
- PASS: Implemented role enum + privileged access policy/service wiring across access gates/controllers/locales/specs.
- PASS: Removed trial provisioning job/service and updated user callback + seeds.
- PASS: Added privileged checkout blocking in dashboard and marketplace flows with UI messaging.
- PASS: Updated EN/ES ToS, homepage, and checkout wording for subscriptions + one-time products.
- PASS: `bundle exec rspec spec/services/access/privileged_role_policy_spec.rb spec/services/licenses/privileged_access_spec.rb spec/requests/api/licenses_verify_spec.rb`
- PASS: `bundle exec rspec spec/services/addons/eligibility_spec.rb spec/services/marketplace/asset_access_spec.rb spec/services/licenses/addon_access_spec.rb spec/services/courses/accessible_courses_spec.rb spec/services/licenses/accessible_expert_advisors_spec.rb spec/requests/admin_access_spec.rb spec/seeds/marketplace_seed_spec.rb spec/models/user_spec.rb`
- FAIL: `bundle exec rspec` (1 failure in `spec/services/admin/analytics/revenue_metrics_spec.rb` due time-sensitive `manual_subscription` factory defaults)
- PASS: Stabilized `spec/services/admin/analytics/revenue_metrics_spec.rb` by setting explicit `starts_at` for fixed-date fixture.
- FAIL: `bundle exec rspec spec/requests/subscription_upgrade_spec.rb spec/requests/marketplace_spec.rb` (redirect locale expectation mismatch in new privileged checkout test)
- PASS: Fixed locale-aware redirect expectations in `spec/requests/subscription_upgrade_spec.rb`.
- PASS: Added request specs for privileged checkout blocking in `spec/requests/subscription_upgrade_spec.rb` and `spec/requests/marketplace_spec.rb`.
- PASS: `bundle exec rspec spec/requests/subscription_upgrade_spec.rb spec/requests/marketplace_spec.rb`
- PASS: `bundle exec rspec` (final: `423 examples, 0 failures`)
