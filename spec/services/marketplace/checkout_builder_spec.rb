require "rails_helper"

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
end
