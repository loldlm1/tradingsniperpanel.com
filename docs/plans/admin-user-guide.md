# Plan: Admin User Guide (EN/ES)

## Goal
Create a clear, client-facing admin guide (English + Spanish) that explains how to CRUD all supported admin models and how they relate (EAs, courses, marketplace products, add-ons, bundles, plans/entitlements, manual billing, users, revenue splits), and identify any missing admin functionality needed to complete those flows.

## Definition of Done
- A published guide exists in EN + ES with consistent structure and cross-links between related admin objects.
- Guides live at the repo root in `/saas_admin_guide`, with screenshots stored under `/saas_admin_guide/images`.
- The guide covers every ActiveAdmin resource and the most common workflows (EA + bundles + add-ons, courses + modules + lessons, marketplace products + entitlements + addons, manual billing, users/roles, revenue splits/payouts).
- Admin-panel gaps required for the guide’s workflows are implemented or explicitly documented as “not available in admin yet” with a follow‑up task.
- A separate, small developer-only guide documents master_admin-only capabilities.

## Constraints
- Follow `docs/cruip_template_guide.md` if we render the guide inside the app.
- Keep controllers thin; new business logic goes in services if needed.
- Avoid editing vendor template assets under `app/assets/templates`.
- Audience: both client admins and internal admins; call out master_admin-only actions.
- Client-facing guide must not mention `master_admin`; master_admin content lives in the developer guide.
- Screenshots can be ES-only for now.

## Steps
1) Audience analysis + task mapping (technical-writer workflow): list admin personas and all CRUD workflows per resource.
2) Outline guide sections by ActiveAdmin resources and core workflows, including cross‑references between related models.
3) Gap analysis: add ActiveAdmin CRUD for BillingPlan + entitlements (+ Addon if needed) to support plan and entitlement management.
4) Draft EN guide content with screenshots; translate to ES (use same section IDs/anchors); exclude master_admin mentions.
5) Draft a small developer guide for master_admin-only features and limitations.
6) Implement static guide placement at `/saas_admin_guide` (EN/ES + images).
7) Accuracy pass against admin forms/fields and finalize.

## Open Questions
None.

## Decisions
- Guides are Markdown-only, stored under `/saas_admin_guide`.
- Screenshots are ES-only.
- Client guide omits `master_admin`; separate developer guide covers those features.

## Commands Run (PASS/FAIL only)
- `sed -n '1,200p' /home/loldlm/.agents/skills/technical-writer/SKILL.md` (PASS)
- `cat docs/plans/admin-user-guide.md` (PASS)
- `sed -n '1,260p' app/services/billing/plan_creator.rb` (PASS)
- `sed -n '1,260p' app/services/marketplace/product_manager.rb` (PASS)
- `rg -n "allowed_subscription_tiers" app -g"*.rb"` (PASS)
- `sed -n '1,200p' app/models/expert_advisor.rb` (PASS)
- `rg -n "active_admin" config/locales/en.yml config/locales/es.yml` (FAIL)
- `ls config/locales` (PASS)
- `sed -n '1,240p' config/locales/active_admin.en.yml` (PASS)
- `sed -n '1,240p' config/locales/active_admin.es.yml` (PASS)
- `mkdir -p saas_admin_guide/images` (PASS)
- `cat <<'EOF' > saas_admin_guide/README.md` (PASS)
- `cat <<'EOF' > saas_admin_guide/README.es.md` (PASS)
- `cat <<'EOF' > saas_admin_guide/master_admin_guide.md` (PASS)
- `cat <<'EOF' > app/services/admin/billing_plan_upsert.rb` (PASS)
- `cat <<'EOF' > app/admin/billing_plans.rb` (PASS)
- `cat <<'EOF' > app/admin/billing_plan_entitlements.rb` (PASS)
- `cat <<'EOF' > app/admin/course_plan_entitlements.rb` (PASS)
- `cat <<'EOF' > app/admin/asset_plan_entitlements.rb` (PASS)
- `rg -n "def self.ordered|scope :ordered" app/models/marketplace_asset.rb` (PASS)
- `rg -n "description" db/schema.rb | head` (PASS)
- `rg -n "display_name" config/initializers/active_admin.rb` (PASS)
- `sed -n '300,360p' config/initializers/active_admin.rb` (PASS)
- `git status --short` (PASS)
