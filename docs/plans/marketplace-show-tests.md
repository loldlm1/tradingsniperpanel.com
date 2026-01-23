# Plan: Marketplace Show Test Expansion

## Goal
Expand automated coverage for the marketplace show/cart/checkout flow and run the full test suite to confirm green status.

## Definition of Done
- Request/service specs cover additional marketplace show scenarios (add-on visibility, base eligibility, related items selection, and checkout metadata/guards).
- Checkout-related specs exercise add-on preselection, base-required behavior, and owned add-on hiding.
- Full test suite run via `bundle exec rspec` is documented with PASS/FAIL.

## Constraints
- Keep tests lean and deterministic; stub Pay/Stripe and external calls.
- Use I18n keys in expectations (avoid hardcoded copy).
- Prefer request specs for flows, service specs for calculation/selection logic.
- No changes to vendor template assets.

## Steps
1. Review existing marketplace show and checkout specs to identify gaps.
2. Add/extend service specs for presenter/cart selection logic and related items.
3. Add/extend request specs for checkout eligibility and metadata handling.
4. Run `bundle exec rspec` and record results.

## Open Questions
- None.

## Decisions
- Use `bundle exec rspec` for the full suite.
- Expand coverage at request/service level only (no JS/system specs).
- Aim for broad coverage rather than specific edge-case prioritization.

## Commands
- `rg -n "Marketplace::ShowPresenter|CheckoutBuilder|marketplace#show|marketplace product|marketplace_show" spec` (PASS)
- `rg -n "acts_as_taggable|tag_list|has_many :tags|taggable" app/models` (PASS)
- `sed -n '1,120p' app/models/expert_advisor.rb` (PASS)
- `sed -n '1,200p' spec/factories/expert_advisors.rb` (PASS)
- `sed -n '1,200p' spec/factories/courses.rb` (PASS)
- `sed -n '1,200p' spec/factories/marketplace_assets.rb` (PASS)
- `rg -n "use_transactional_fixtures|DatabaseCleaner" spec/rails_helper.rb spec/spec_helper.rb` (PASS)
- `sed -n '1,260p' spec/requests/marketplace_spec.rb` (PASS)
- `bundle exec rspec` (FAIL)
- `bundle exec rails runner -e test 'include FactoryBot::Syntax::Methods; user=create(:user); base_plan=create(:billing_plan, :one_time); base_product=create(:marketplace_product, billing_plan: base_plan, title_en: "Base Bundle"); ea=create(:expert_advisor, name: "Base EA"); create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: ea); addon_plan=create(:billing_plan, :one_time); create(:addon, addonable: ea, billing_plan: addon_plan); addon_product=create(:marketplace_product, billing_plan: addon_plan, title_en: "Hidden Addon"); create(:marketplace_purchase, user: user, billing_plan: addon_plan); entry=Marketplace::Catalog.new(user: user).entry_for!(slug: base_product.slug); presenter=Marketplace::ShowPresenter.new(user: user, entry: entry, locale: :en).call; puts "addon_rows=#{presenter.addon_rows.size}"; puts presenter.addon_rows.map(&:title).inspect;'` (PASS)
- `bundle exec rails runner -e test 'include FactoryBot::Syntax::Methods; user=create(:user); base_plan=create(:billing_plan, :one_time); base_product=create(:marketplace_product, billing_plan: base_plan, title_en: "Base Bundle"); ea=create(:expert_advisor, name: "Base EA"); create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: ea); addon_plan=create(:billing_plan, :one_time); create(:addon, addonable: ea, billing_plan: addon_plan); addon_product=create(:marketplace_product, billing_plan: addon_plan, title_en: "Hidden Addon"); create(:marketplace_purchase, user: user, billing_plan: addon_plan); entry=Marketplace::Catalog.new(user: user).entry_for!(slug: base_product.slug); presenter=Marketplace::ShowPresenter.new(user: user, entry: entry, locale: :en).call; puts presenter.related_items.map(&:title).inspect;'` (FAIL)
- `rg -n "before\\(:suite\\)|before\\(:all\\)|seed" spec/rails_helper.rb spec/support spec/spec_helper.rb` (PASS)
- `sed -n '1,200p' spec/seeds/marketplace_seed_spec.rb` (PASS)
- `bundle exec rspec` (FAIL)
- `bundle exec rspec` (FAIL)
- `bundle exec rails db:test:prepare` (PASS)
- `bundle exec rspec` (PASS)
