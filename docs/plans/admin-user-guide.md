# Plan: Admin User Guide (EN/ES)

## Goal
Create a clear, client-facing admin guide (English + Spanish) that explains how to CRUD all supported admin models and how they relate (EAs, courses, marketplace products, add-ons, bundles, plans/entitlements, manual billing, users, revenue splits), and identify any missing admin functionality needed to complete those flows.

## Definition of Done
- A published guide exists in EN + ES with consistent structure and cross-links between related admin objects.
- Guides live at the repo root in `/saas_admin_guide`, with screenshots stored under `/saas_admin_guide/images`.
- Standalone HTML versions of the guides exist with embedded images and minimal CSS.
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
7) Capture ES screenshots from the admin using agent-browser and replace placeholders.
8) Embed screenshot images after each section in both Markdown guides.
9) Add standalone HTML versions of the guides with minimal CSS and image embeds.
10) Replace `es-02-data-map.png` with a Spanish-only data map diagram.
11) Accuracy pass against admin forms/fields and finalize.

## Open Questions
None.

## Decisions
- Guides are Markdown-first under `/saas_admin_guide`, with standalone HTML versions for preview.
- Screenshots are ES-only.
- Client guide omits `master_admin`; separate developer guide covers those features.
- ES screenshots captured from local ActiveAdmin; used a temporary master_admin account to access create forms.
- Added ransackable allowlists to entitlement models to fix ActiveAdmin filters.
- Embedded screenshot images inline after each section in the Markdown guides.
- Added standalone HTML versions of the guides with minimal CSS and Spanish labels.
- Replaced `es-02-data-map.png` with a Spanish-only data map diagram exported from SVG.

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
- `sed -n '1,120p' /home/loldlm/.agents/skills/technical-writer/SKILL.md` (PASS)
- `base64 --decode > saas_admin_guide/images/*.png` (PASS)
- `cat <<'EOF' > saas_admin_guide/images/README.md` (PASS)
- `sed -n '1,200p' saas_admin_guide/README.md` (PASS)
- `sed -n '200,400p' saas_admin_guide/README.md` (PASS)
- `sed -n '1,200p' saas_admin_guide/README.es.md` (PASS)
- `sed -n '200,400p' saas_admin_guide/README.es.md` (PASS)
- `git status --short` (PASS)
- `git status` (PASS)
- `ls app/admin | sort` (PASS)
- `bin/rails runner "user = User.find_or_initialize_by(email: 'admin+screenshots@example.com'); ..."` (FAIL)
- `bin/rails runner "user = User.find_or_initialize_by(email: 'admin+screenshots@example.com'); ... terms_accepted_at ..."` (PASS)
- `agent-browser set viewport 1440 900` (PASS)
- `agent-browser open http://localhost:3000/admin?locale=es` (PASS)
- `agent-browser snapshot -i` (PASS)
- `agent-browser fill @e2 "admin+screenshots@example.com"` (PASS)
- `agent-browser fill @e4 "Password123!"` (PASS)
- `agent-browser click @e5` (PASS)
- `agent-browser wait --load networkidle` (PASS)
- `agent-browser get url` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-01-admin-dashboard.png` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-02-data-map.png` (PASS)
- `agent-browser open http://localhost:3000/admin/expert_advisors/new?locale=es` (PASS)
- `bin/rails runner "user = User.find_by(email: 'admin+screenshots@example.com'); user.update!(role: :master_admin, ...)"` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-03-expert-advisor-form.png` (PASS)
- `agent-browser open http://localhost:3000/admin/expert_advisor_bundles/new?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-04-ea-bundles.png` (PASS)
- `agent-browser open http://localhost:3000/admin/marketplace_products/new?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-05-ea-addon-product.png` (PASS)
- `agent-browser open http://localhost:3000/admin/courses/new?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-06-course-form.png` (PASS)
- `agent-browser open http://localhost:3000/admin/course_modules/new?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-07-course-modules.png` (PASS)
- `agent-browser open http://localhost:3000/admin/course_lessons/new?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-08-course-lessons.png` (PASS)
- `agent-browser open http://localhost:3000/admin/marketplace_products/new?locale=es` (PASS)
- `agent-browser scroll down 900` (PASS)
- `agent-browser screenshot saas_admin_guide/images/es-09-course-addon.png` (PASS)
- `agent-browser open http://localhost:3000/admin/marketplace_assets/new?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-10-marketplace-asset.png` (PASS)
- `agent-browser open http://localhost:3000/admin/marketplace_products/new?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-11-marketplace-product.png` (PASS)
- `agent-browser open http://localhost:3000/admin/billing_plans/new?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-12-billing-plans.png` (PASS)
- `agent-browser open http://localhost:3000/admin/billing_plan_entitlements?locale=es` (FAIL)
- `agent-browser snapshot -c` (PASS)
- `apply_patch (app/models/billing_plan_entitlement.rb)` (PASS)
- `apply_patch (app/models/course_plan_entitlement.rb)` (PASS)
- `apply_patch (app/models/asset_plan_entitlement.rb)` (PASS)
- `apply_patch (saas_admin_guide/images/README.md)` (PASS)
- `agent-browser open http://localhost:3000/admin/billing_plan_entitlements?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-13-plan-entitlements.png` (PASS)
- `agent-browser open http://localhost:3000/admin/manual_transactions/new?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-14-manual-billing.png` (PASS)
- `agent-browser open http://localhost:3000/admin/users?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-15-users.png` (PASS)
- `agent-browser open http://localhost:3000/admin/revenue_split_rules?locale=es` (PASS)
- `agent-browser screenshot --full saas_admin_guide/images/es-16-revenue-splits.png` (PASS)
- `ls -lh saas_admin_guide/images` (PASS)
- `agent-browser close` (PASS)
- `sed -n '1,200p' /home/loldlm/.agents/skills/technical-writer/SKILL.md` (PASS)
- `ls -la saas_admin_guide` (PASS)
- `sed -n '1,200p' docs/plans/admin-user-guide.md` (PASS)
- `sed -n '1,200p' saas_admin_guide/README.es.md` (PASS)
- `sed -n '1,200p' saas_admin_guide/guide.es.html` (PASS)
- `sed -n '1,80p' saas_admin_guide/README.md` (PASS)
- `ls -la saas_admin_guide/images` (PASS)
- `sed -n '1,120p' saas_admin_guide/guide.en.html` (PASS)
- `git status --short` (PASS)
