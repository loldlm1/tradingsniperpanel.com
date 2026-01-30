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
10) Replace `es-02-data-map.png` with a Mermaid-based Spanish data map diagram (store `.mmd` source + render PNG).
11) Add additional Mermaid diagrams for purchase flows, EA bundles/add-ons, and entitlements; render PNG/SVG and embed in guides.
12) Align admin permissions so admins can CRUD all resources; only user role updates differ.
13) Fix ransackable allowlists for BillingPlan and ExpertAdvisorBundle to prevent 500s in admin.
14) Update specs for new permission rules and ransackable allowlists, then run full test suite.
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
- Use Mermaid (`.mmd`) as the source of truth for data map diagrams.
- Use Mermaid (`.mmd`) as the source of truth for additional guide diagrams.
- Admins can CRUD all ActiveAdmin resources; only master_admin can change user roles.

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
- `command -v mmdc` (FAIL)
- `node -v` (PASS)
- `npm -v` (PASS)
- `cat <<'EOF' > saas_admin_guide/images/es-02-data-map.mmd` (PASS)
- `npx -y @mermaid-js/mermaid-cli -i saas_admin_guide/images/es-02-data-map.mmd -o saas_admin_guide/images/es-02-data-map.svg` (FAIL)
- `npx -y @mermaid-js/mermaid-cli -i saas_admin_guide/images/es-02-data-map.mmd -o saas_admin_guide/images/es-02-data-map.svg` (PASS)
- `npx -y @mermaid-js/mermaid-cli -i saas_admin_guide/images/es-02-data-map.mmd -o saas_admin_guide/images/es-02-data-map.png` (PASS)
- `ls -lh saas_admin_guide/images/es-02-data-map.*` (PASS)
- `git status --short` (PASS)
- `cat <<'EOF' > saas_admin_guide/images/es-17-purchase-flow.mmd` (PASS)
- `cat <<'EOF' > saas_admin_guide/images/es-18-ea-bundles-addons.mmd` (PASS)
- `cat <<'EOF' > saas_admin_guide/images/es-19-entitlements-map.mmd` (PASS)
- `npx -y @mermaid-js/mermaid-cli -i saas_admin_guide/images/es-17-purchase-flow.mmd -o saas_admin_guide/images/es-17-purchase-flow.svg` (PASS)
- `npx -y @mermaid-js/mermaid-cli -i saas_admin_guide/images/es-17-purchase-flow.mmd -o saas_admin_guide/images/es-17-purchase-flow.png` (PASS)
- `npx -y @mermaid-js/mermaid-cli -i saas_admin_guide/images/es-18-ea-bundles-addons.mmd -o saas_admin_guide/images/es-18-ea-bundles-addons.svg` (PASS)
- `npx -y @mermaid-js/mermaid-cli -i saas_admin_guide/images/es-18-ea-bundles-addons.mmd -o saas_admin_guide/images/es-18-ea-bundles-addons.png` (PASS)
- `npx -y @mermaid-js/mermaid-cli -i saas_admin_guide/images/es-19-entitlements-map.mmd -o saas_admin_guide/images/es-19-entitlements-map.svg` (PASS)
- `npx -y @mermaid-js/mermaid-cli -i saas_admin_guide/images/es-19-entitlements-map.mmd -o saas_admin_guide/images/es-19-entitlements-map.png` (PASS)
- `rg -n "ea-addons|add-on" saas_admin_guide/guide.en.html` (PASS)
- `sed -n '120,150p' saas_admin_guide/guide.en.html` (PASS)
- `sed -n '180,230p' saas_admin_guide/guide.en.html` (PASS)
- `sed -n '160,190p' saas_admin_guide/guide.en.html` (PASS)
- `git status --short` (PASS)
- `rg -n "master_admin|admin" app config | head -n 200` (PASS)
- `rg -n "require_master_admin!|master_admin" app/admin` (PASS)
- `sed -n '1,120p' app/admin/users.rb` (PASS)
- `rg -n "class RoleGuard|RoleGuard" app -g"*.rb"` (PASS)
- `sed -n '1,200p' app/services/admin/users/role_guard.rb` (PASS)
- `sed -n '1,140p' app/admin/billing_plans.rb` (PASS)
- `sed -n '1,80p' app/admin/expert_advisors.rb` (PASS)
- `sed -n '1,160p' app/admin/revenue_split_payouts.rb` (PASS)
- `sed -n '1,80p' app/admin/expert_advisor_bundles.rb` (PASS)
- `sed -n '1,200p' app/models/revenue_split_payout.rb` (PASS)
- `sed -n '1,200p' app/services/admin/analytics/payout_recorder.rb` (PASS)
- `rg -n "master_admin\\?|master_admin" app/services app/admin app/models app/controllers` (PASS)
- `ls -la spec` (PASS)
- `rg -n "RoleGuard|master_admin|admin" spec` (PASS)
- `sed -n '1,200p' spec/services/admin/users/role_guard_spec.rb` (PASS)
- `sed -n '1,200p' spec/requests/admin_marketplace_linking_spec.rb` (PASS)
- `sed -n '1,220p' spec/requests/admin_marketplace_products_spec.rb` (PASS)
- `sed -n '1,120p' spec/requests/admin_expert_advisor_bundles_spec.rb` (PASS)
- `sed -n '1,120p' spec/requests/admin_revenue_split_payouts_spec.rb` (PASS)
- `sed -n '1,120p' spec/services/admin/analytics/payout_recorder_spec.rb` (PASS)
- `sed -n '1,120p' spec/models/revenue_split_payout_spec.rb` (PASS)
- `rg -n "blocks admins|blocks admin|forbid|role_forbidden|master_admin" spec/requests spec/services spec/models` (PASS)
- `sed -n '1,220p' app/services/admin/marketplace_product_upsert.rb` (PASS)
- `rg -n "COMPLETE PORTFOLIOS|Execution playbooks" -g"*"` (PASS)
- `sed -n '1,120p' app/views/templates/neon/pages/home.html.erb` (PASS)
- `rg -n "landing" config/locales` (PASS)
- `sed -n '402,520p' config/locales/en.yml` (PASS)
- `sed -n '1,120p' spec/requests/admin_access_spec.rb` (PASS)
- `sed -n '1,160p' spec/requests/landing_template_locale_branding_spec.rb` (PASS)
- `rg -n "require_master_admin!" app/admin` (FAIL)
- `bin/rspec` (FAIL)
- `ls -la bin` (PASS)
- `bundle exec rspec` (FAIL)
- `bundle exec rspec` (FAIL)
- `bundle exec rspec` (PASS)
- `sed -n '1,200p' app/models/user.rb` (PASS)
- `rg -n "create_table \\\"users\\\"" -n db/schema.rb` (PASS)
- `sed -n '658,720p' db/schema.rb` (PASS)
- `sed -n '1,120p' app/admin/courses.rb` (PASS)
- `sed -n '1,120p' app/admin/marketplace_assets.rb` (PASS)
- `sed -n '1,120p' app/admin/billing_plan_entitlements.rb` (PASS)
- `sed -n '1,120p' app/admin/course_plan_entitlements.rb` (PASS)
- `sed -n '1,120p' app/admin/asset_plan_entitlements.rb` (PASS)
- `rg -n "role|admin" saas_admin_guide/README.md saas_admin_guide/README.es.md saas_admin_guide/master_admin_guide.md` (PASS)
- `sed -n '260,320p' saas_admin_guide/README.md` (PASS)
- `sed -n '250,320p' saas_admin_guide/README.es.md` (PASS)
- `sed -n '1,80p' /home/loldlm/.agents/skills/rails-expert/SKILL.md` (PASS)
- `rg -n "class BillingPlan|ransackable" app/models` (PASS)
- `sed -n '1,200p' app/models/billing_plan.rb` (PASS)
- `sed -n '1,200p' app/models/expert_advisor_bundle.rb` (PASS)
- `ls -la spec/models` (PASS)
- `sed -n '1,120p' spec/models/billing_plan_spec.rb` (PASS)
- `sed -n '1,200p' spec/models/ransackable_allowlist_spec.rb` (PASS)
- `bundle exec rspec` (PASS)
