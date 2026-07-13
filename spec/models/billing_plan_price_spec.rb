require "rails_helper"

RSpec.describe BillingPlanPrice, type: :model do
  it "stores an immutable price snapshot for a recurring plan" do
    price = build(:billing_plan_price, current: true)

    expect(price).to be_valid
    expect(price.amount_cents).to eq(price.billing_plan.amount_cents)
    expect(price.interval).to eq(price.billing_plan.interval)
  end

  it "requires interval and count together" do
    price = build(:billing_plan_price, interval: "month", interval_count: nil)

    expect(price).not_to be_valid
  end

  it "rejects a retired current price" do
    price = build(:billing_plan_price, current: true, retired_at: Time.current)

    expect(price).not_to be_valid
  end

  it "resolves current and retired Stripe price IDs" do
    plan = create(:billing_plan)
    current = create(:billing_plan_price, billing_plan: plan, current: true)
    retired = create(:billing_plan_price, billing_plan: plan, active: false, retired_at: Time.current)

    expect(described_class.for_price_id(current.stripe_price_id)).to eq(current)
    expect(described_class.for_price_id(retired.stripe_price_id)).to eq(retired)
  end
end
