# Plan: Marketplace Show Redesign

## Goal
Rebuild `marketplace#show` to match `mosaic-html/dashboard_marketplace_show.html` (section comments preserved), with real marketplace data, and add an add-on cart that checks out multiple one-time items via Pay/Stripe.

## Definition of Done
- `app/views/marketplace/show.html.erb` mirrors the Mosaic layout and HTML comment sections; repeated blocks extracted to partials; author/ratings/legal blocks removed when not supported.
- A show presenter/service provides all UI data (summary/description, tags, rating metrics, related items, add-on list/eligibility, cart totals) with eager-loaded queries.
- Add-on selection works on the show page, updates totals client-side, and submits a single Stripe Checkout session containing the base product (when required) + selected add-ons.
- Checkout guardrails prevent duplicate purchases, allow base+add-ons in one session, and surface eligibility errors clearly; already-owned add-ons are hidden.
- One-time purchase sync handles multi-line-item checkouts and records marketplace purchases/licenses/enrollments for each plan.
- All UI copy is I18n-backed in EN/ES; links respect locale; no vendor asset edits.
- Tests cover the presenter/cart logic and the checkout flow (multi-line items + eligibility).

## Constraints
- Follow `docs/cruip_template_guide.md`; keep Mosaic classes, JS hooks, and HTML comment blocks intact.
- Keep controllers thin; business logic in `app/services`.
- Avoid inline strings in views; add EN/ES keys under `config/locales`.
- Avoid editing vendor template assets; add any JS via importmap modules.

## Steps
1. Map each mock-up section (title/meta/image/content/related/sidebar/add-ons/checkout/legal) to available data and define fallbacks.
2. Add a `Marketplace::ShowPresenter` (and cart helper/service if needed) that preloads associations, computes rating/metrics, related items, and add-on eligibility.
3. Add a marketplace checkout action that accepts multiple plan keys, builds Stripe Checkout `line_items`, and stores plan keys in metadata for sync (base required if not owned or viewing an add-on).
4. Update `Licenses::OneTimePurchaseSync` to resolve and process multiple billing plans from checkout metadata.
5. Rebuild `app/views/marketplace/show.html.erb` from the Mosaic template, with partials for rating, related items, and add-on rows; wire to presenter data.
6. Add a small JS module to update add-on totals and button state client-side.
7. Add/adjust specs for presenter/cart logic and checkout multi-item behavior.

## Open Questions
- None.

## Decisions
- Remove author block (not supported yet).
- Hide promo badge unless promo data exists.
- Hide ratings until reviews exist.
- Related items: select by shared tags and/or same product type.
- Add-ons list: any `Addon` whose `addonable` is included in the product’s EAs/courses/assets.
- Base + add-ons in same checkout is eligible; already-owned add-ons hidden.
- Checkout behavior: if base owned, buy selected add-ons; if viewing add-on, preselect base; if viewing base and not owned, buy base + add-ons.
- “Load more” links to marketplace with filters.
- Remove legal/terms block for now.
- Show add-on progress bar even when no add-ons exist (0/0).
- For add-on products with multiple possible bases, preselect the first base by `MarketplaceProduct.ordered`.
- On add-on product pages, show the add-ons list for the selected base product.

## Commands
- `sed -n '1,200p' app/services/billing/apply_referral_discount.rb` (PASS)
- `sed -n '1,200p' app/models/billing_plan.rb` (PASS)
- `rg -n "checkout" spec/controllers spec/requests spec/services` (PASS)
- `sed -n '1,200p' spec/requests/marketplace_spec.rb` (PASS)
- `rg -n "payment_processor\\.checkout|Pay::Stripe" spec/requests spec/services` (PASS)
- `sed -n '1,160p' spec/requests/subscription_upgrade_spec.rb` (PASS)
- `rg -n "OneTimePurchaseSync" spec` (PASS)
- `sed -n '1,200p' spec/services/licenses/one_time_purchase_sync_spec.rb` (PASS)
- `sed -n '120,220p' app/controllers/application_controller.rb` (PASS)
- `rg -n "ensure_payment_processor" app/controllers` (PASS)
- `sed -n '220,280p' app/controllers/dashboards_controller.rb` (PASS)
- `sed -n '1,120p' config/routes.rb` (PASS)
- `sed -n '400,460p' app/views/layouts/dashboard.html.erb` (PASS)
- `rg -n "factory :marketplace_product" spec/factories` (PASS)
- `sed -n '1,200p' spec/factories/marketplace_products.rb` (PASS)
- `sed -n '1,200p' spec/factories/billing_plans.rb` (PASS)
- `sed -n '1,200p' spec/factories/addons.rb` (PASS)
- `rg -n "checkout_unavailable|base_missing|no_items_selected" app/services/marketplace/checkout_builder.rb` (PASS)
- `sed -n '110,220p' config/locales/dashboard.es.yml` (PASS)
- `cat > app/views/marketplace/show.html.erb` (PASS)
- `sed -n '1,240p' app/views/marketplace/show.html.erb` (PASS)
- `git status --short` (PASS)
- `sed -n '1,200p' docs/plans/marketplace-show-redesign.md` (PASS)
- `sed -n '1,260p' app/services/marketplace/show_presenter.rb` (PASS)
- `sed -n '260,520p' app/services/marketplace/show_presenter.rb` (PASS)
- `sed -n '1,260p' app/services/marketplace/checkout_builder.rb` (PASS)
- `sed -n '1,240p' app/controllers/marketplace_controller.rb` (PASS)
- `sed -n '1,200p' config/routes.rb` (PASS)
- `sed -n '1,260p' app/views/marketplace/show.html.erb` (PASS)
- `sed -n '1,200p' mosaic-html/dashboard_marketplace_show.html` (PASS)
- `rg -n "Related|Product content|Sidebar|Add-ons|Addons|Add-ons" mosaic-html/dashboard_marketplace_show.html` (PASS)
- `sed -n '1080,1420p' mosaic-html/dashboard_marketplace_show.html` (PASS)
- `rg -n "included|Already|You'll|get|Legal|Section" mosaic-html/dashboard_marketplace_show.html` (PASS)
- `sed -n '1130,1210p' mosaic-html/dashboard_marketplace_show.html` (PASS)
- `sed -n '1,240p' app/javascript/marketplace_show.js` (PASS)
- `sed -n '1,200p' app/views/marketplace/show/_addon_row.html.erb` (PASS)
- `sed -n '1,200p' app/views/marketplace/show/_related_item.html.erb` (PASS)
- `sed -n '1,260p' app/services/licenses/one_time_purchase_sync.rb` (PASS)
- `sed -n '1,200p' spec/services/marketplace/show_presenter_spec.rb` (PASS)
- `sed -n '1,200p' spec/factories/marketplace_products.rb` (PASS)
- `sed -n '1,200p' spec/services/licenses/one_time_purchase_sync_spec.rb` (PASS)
- `sed -n '1,260p' spec/requests/marketplace_spec.rb` (PASS)
- `sed -n '1,200p' spec/factories/billing_plans.rb` (PASS)
- `rg -n "marketplace_show" config/importmap.rb` (PASS)
- `sed -n '1,200p' app/javascript/application.js` (PASS)
- `rg -n "marketplace.show" config/locales/dashboard.en.yml` (FAIL)
- `rg -n "marketplace" config/locales/dashboard.en.yml` (PASS)
- `sed -n '100,220p' config/locales/dashboard.en.yml` (PASS)
- `sed -n '220,340p' config/locales/dashboard.en.yml` (PASS)
- `sed -n '110,260p' config/locales/dashboard.es.yml` (PASS)
- `rg -n "to_param" app/models/marketplace_product.rb` (PASS)
- `sed -n '1,120p' app/models/marketplace_product.rb` (PASS)
- `rg --files -g 'applications-image-09.jpg'` (PASS)
- `rg -n "mosaic/images" app/views` (PASS)
- `rg -n "class Addon" -n app/models` (PASS)
- `sed -n '1,120p' app/models/addon.rb` (PASS)
- `sed -n '1,260p' app/services/marketplace/catalog.rb` (PASS)
- `sed -n '1,260p' app/services/marketplace/index_presenter.rb` (PASS)
- `ls -la docs/plans` (PASS)
- `ls -la mosaic-html` (PASS)
- `bundle exec rspec spec/services/marketplace/show_presenter_spec.rb spec/services/licenses/one_time_purchase_sync_spec.rb spec/requests/marketplace_spec.rb` (FAIL)
- `rg -n "pay_customer" app/models` (PASS)
- `sed -n '1,120p' app/models/user.rb` (PASS)
- `rg -n "scope :active" app/models/billing_plan.rb` (PASS)
- `sed -n '1,200p' app/models/billing_plan.rb` (PASS)
- `sed -n '1,200p' spec/factories/billing_plan_entitlements.rb` (PASS)
- `rg -n "Pay::Stripe::Customer" spec` (PASS)
- `rg -n "payment_processor.*checkout|checkout\\)" spec/requests` (PASS)
- `bundle exec rails runner -e test 'require "factory_bot_rails"; include FactoryBot::Syntax::Methods; user=create(:user); base_plan=create(:billing_plan, :one_time, key: "marketplace_base"); base_product=create(:marketplace_product, billing_plan: base_plan, title_en: "Base Bundle"); ea=create(:expert_advisor, name: "Bundle EA"); create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: ea); addon_plan=create(:billing_plan, :one_time, key: "marketplace_addon"); create(:addon, addonable: ea, billing_plan: addon_plan); create(:marketplace_product, billing_plan: addon_plan, title_en: "Addon Pack"); entry=Marketplace::Catalog.new(user: user, include_eligibility: true).entry_for!(slug: base_product.slug); result=Marketplace::CheckoutBuilder.new(user: user, entry: entry, base_plan_key: base_plan.key, addon_keys: [addon_plan.key], locale: :en).call; puts "allowed=#{result.allowed?}"; puts "error=#{result.error_key}"; p result.line_items;'` (PASS)
- `bundle exec rails runner -e test 'require "factory_bot_rails"; include FactoryBot::Syntax::Methods; user=create(:user); user.pay_customers.create!(processor: "stripe", processor_id: "cus_test", default: true); puts user.payment_processor.class.name;'` (FAIL)
- `sed -n '1,200p' spec/factories/users.rb` (PASS)
- `bundle exec rails runner -e test 'require "securerandom"; email="temp#{SecureRandom.hex(4)}@example.com"; user=User.create!(email: email, password: "password123", password_confirmation: "password123", name: "Test", preferred_locale: "en", terms_accepted_at: Time.current); user.pay_customers.create!(processor: "stripe", processor_id: "cus_test", default: true); puts user.payment_processor.class.name;'` (PASS)
- `bundle exec rspec spec/services/marketplace/show_presenter_spec.rb spec/services/licenses/one_time_purchase_sync_spec.rb spec/requests/marketplace_spec.rb` (FAIL)
- `bundle exec rails db:test:prepare` (PASS)
- `sed -n '1,260p' app/services/addons/eligibility.rb` (PASS)
- `sed -n '1,200p' spec/factories/licenses.rb` (PASS)
- `bundle exec rspec spec/services/marketplace/show_presenter_spec.rb spec/services/licenses/one_time_purchase_sync_spec.rb spec/requests/marketplace_spec.rb` (FAIL)
- `bundle exec rspec spec/services/marketplace/show_presenter_spec.rb spec/services/licenses/one_time_purchase_sync_spec.rb spec/requests/marketplace_spec.rb` (PASS)
- `git status --short` (PASS)
