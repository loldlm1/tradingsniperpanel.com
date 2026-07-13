require "rails_helper"

RSpec.describe BillingPlan, type: :model do
  it "accepts a valid subscription key format" do
    plan = build(:billing_plan, tier: "basic", interval: "month", interval_count: 1, key: "basic_monthly")

    expect(plan).to be_valid
  end

  it "rejects a mismatched subscription key" do
    plan = build(:billing_plan, tier: "basic", interval: "month", interval_count: 1, key: "basic_annual")

    expect(plan).not_to be_valid
  end

  it "allows one-time plans without interval data" do
    plan = build(:billing_plan, :one_time)

    expect(plan).to be_valid
  end

  it "resolves both canonical and historical Stripe price IDs" do
    plan = create(:billing_plan, stripe_price_id: "price_current")
    create(
      :billing_plan_price,
      billing_plan: plan,
      stripe_price_id: "price_retired",
      active: false,
      retired_at: Time.current
    )

    expect(described_class.for_price_id("price_current")).to eq(plan)
    expect(described_class.for_price_id("price_retired")).to eq(plan)
  end

  it "exposes only exact active Pandora monthly and annual plans as purchasable" do
    monthly = create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )
    annual = create(
      :billing_plan,
      :annual,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::ANNUAL_KEY,
      amount_cents: Billing::PandoraPricing::ANNUAL_CENTS
    )
    create(:billing_plan, tier: "basic", key: "basic_monthly")

    expect(described_class.purchasable).to contain_exactly(monthly, annual)
  end

  it "fails closed for a stale amount, inactive row, or missing current Stripe price" do
    stale = create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      amount_cents: 9_999
    )
    inactive = create(
      :billing_plan,
      :annual,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::ANNUAL_KEY,
      amount_cents: Billing::PandoraPricing::ANNUAL_CENTS,
      active: false
    )

    expect(described_class.purchasable).not_to include(stale, inactive)
    stale.update!(amount_cents: Billing::PandoraPricing::MONTHLY_CENTS, stripe_price_id: nil)
    expect(described_class.purchasable).not_to include(stale)
  end
end
