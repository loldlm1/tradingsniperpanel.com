require "rails_helper"
require "securerandom"

RSpec.describe Marketplace::CheckoutBuilder do
  let(:user) { create(:user) }

  def build_base_with_addon(addonable:)
    base_plan = create(:billing_plan, :one_time, amount_cents: 2500)
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Base Bundle")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: addonable)

    addon_plan = create(:billing_plan, :one_time, amount_cents: 900)
    create(:addon, addonable: addonable, billing_plan: addon_plan)
    addon_product = create(:marketplace_product, billing_plan: addon_plan, title_en: "Addon Pack")

    [base_plan, base_product, addon_plan, addon_product]
  end

  def create_active_subscription(user:, tier: "basic")
    plan = create(:billing_plan, tier: tier)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    plan
  end

  it "includes base and selected add-ons when the base is not owned" do
    expert_advisor = create(:expert_advisor)
    base_plan, base_product, addon_plan, _addon_product = build_base_with_addon(addonable: expert_advisor)

    entry = Marketplace::Catalog.new(user: user, include_eligibility: true).entry_for!(slug: base_product.slug)
    result = described_class.new(
      user: user,
      entry: entry,
      base_plan_key: base_plan.key,
      addon_keys: [addon_plan.key],
      locale: :en
    ).call

    expect(result.allowed?).to be(true)
    expect(result.line_items).to contain_exactly(
      { price: base_plan.stripe_price_id, quantity: 1 },
      { price: addon_plan.stripe_price_id, quantity: 1 }
    )
    expect(result.metadata["billing_plan_keys"].to_s.split(",")).to match_array([base_plan.key, addon_plan.key])
  end

  it "returns addon_requires_base when base is owned but access is missing" do
    expert_advisor = create(:expert_advisor, name: "Base EA")
    base_plan, base_product, addon_plan, _addon_product = build_base_with_addon(addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: base_plan)

    entry = Marketplace::Catalog.new(user: user, include_eligibility: true).entry_for!(slug: base_product.slug)
    result = described_class.new(
      user: user,
      entry: entry,
      base_plan_key: base_plan.key,
      addon_keys: [addon_plan.key],
      locale: :en
    ).call

    expect(result.allowed?).to be(false)
    expect(result.error_key).to eq("dashboard.marketplace.errors.addon_requires_base")
    expect(result.error_options).to eq(base: expert_advisor.name)
  end

  it "returns no_items_selected when base is owned and no add-ons are selected" do
    expert_advisor = create(:expert_advisor)
    base_plan, base_product, _addon_plan, _addon_product = build_base_with_addon(addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: base_plan)

    entry = Marketplace::Catalog.new(user: user, include_eligibility: true).entry_for!(slug: base_product.slug)
    result = described_class.new(
      user: user,
      entry: entry,
      base_plan_key: base_plan.key,
      addon_keys: [],
      locale: :en
    ).call

    expect(result.allowed?).to be(false)
    expect(result.error_key).to eq("dashboard.marketplace.errors.no_items_selected")
  end

  it "returns base_missing when the base plan key does not match the entry" do
    expert_advisor = create(:expert_advisor)
    _base_plan, base_product, addon_plan, _addon_product = build_base_with_addon(addonable: expert_advisor)

    entry = Marketplace::Catalog.new(user: user, include_eligibility: true).entry_for!(slug: base_product.slug)
    result = described_class.new(
      user: user,
      entry: entry,
      base_plan_key: "invalid_key",
      addon_keys: [addon_plan.key],
      locale: :en
    ).call

    expect(result.allowed?).to be(false)
    expect(result.error_key).to eq("dashboard.marketplace.errors.base_missing")
  end

  it "filters owned add-ons from the checkout selection" do
    expert_advisor = create(:expert_advisor)
    base_plan, base_product, addon_plan, _addon_product = build_base_with_addon(addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: addon_plan)

    entry = Marketplace::Catalog.new(user: user, include_eligibility: true).entry_for!(slug: base_product.slug)
    result = described_class.new(
      user: user,
      entry: entry,
      base_plan_key: base_plan.key,
      addon_keys: [addon_plan.key],
      locale: :en
    ).call

    expect(result.allowed?).to be(true)
    expect(result.line_items).to contain_exactly(
      { price: base_plan.stripe_price_id, quantity: 1 }
    )
  end

  it "allows direct addon checkout with paid base subscription when no base marketplace product exists" do
    expert_advisor = create(:expert_advisor, allowed_subscription_tiers: %w[basic], name: "Fibonacci Elite EA")
    addon_plan = create(:billing_plan, :one_time, amount_cents: 19_900, key: "addon_fibonacci_compound_reversal_early")
    addon = create(:addon, key: "addon_compound_reversal_early", addonable: expert_advisor, billing_plan: addon_plan)
    addon_product = create(:marketplace_product, billing_plan: addon_plan, title_en: "Compound Mode - Reversal Early")
    create_active_subscription(user: user, tier: "basic")

    entry = Marketplace::Catalog.new(user: user, include_eligibility: true).entry_for!(slug: addon_product.slug)
    result = described_class.new(
      user: user,
      entry: entry,
      base_plan_key: nil,
      addon_keys: [addon_plan.key],
      locale: :en
    ).call

    expect(result.allowed?).to be(true)
    expect(result.line_items).to eq([{ price: addon_plan.stripe_price_id, quantity: 1 }])
    expect(result.metadata["billing_plan_keys"]).to eq(addon.billing_plan.key)
  end

  it "returns addon_requires_base for direct addon checkout without paid base access when no base product exists" do
    expert_advisor = create(:expert_advisor, name: "Fibonacci Elite EA")
    addon_plan = create(:billing_plan, :one_time, amount_cents: 19_900)
    addon_product = create(:marketplace_product, billing_plan: addon_plan, title_en: "Compound Mode - Reversal Early")
    create(:addon, key: "addon_compound_reversal_early", addonable: expert_advisor, billing_plan: addon_plan)

    entry = Marketplace::Catalog.new(user: user, include_eligibility: true).entry_for!(slug: addon_product.slug)
    result = described_class.new(
      user: user,
      entry: entry,
      base_plan_key: nil,
      addon_keys: [addon_plan.key],
      locale: :en
    ).call

    expect(result.allowed?).to be(false)
    expect(result.error_key).to eq("dashboard.marketplace.errors.addon_requires_base")
    expect(result.error_options).to eq(base: expert_advisor.name)
  end
end
