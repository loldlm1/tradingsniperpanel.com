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
end
