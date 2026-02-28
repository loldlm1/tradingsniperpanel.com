require "rails_helper"
require "securerandom"

RSpec.describe Licenses::OnlineSeatLimits do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor) }

  it "returns 0 subscription cap without active subscriptions" do
    limits = described_class.new(user: user, expert_advisor: expert_advisor)

    expect(limits.subscription_cap).to eq(0)
  end

  it "derives subscription cap from ordered tier position" do
    basic_plan = create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, sort_order: 1, stripe_price_id: "price_basic_monthly")
    pro_plan = create(:billing_plan, tier: "pro", key: "pro_monthly", interval: "month", interval_count: 1, sort_order: 2, stripe_price_id: "price_pro_monthly")

    create_pay_subscription(user: user, plan: pro_plan)

    limits = described_class.new(user: user, expert_advisor: expert_advisor)

    # basic starts at 5 seats, pro adds +1
    expect(limits.active_subscription_tier).to eq("pro")
    expect(limits.subscription_cap).to eq(6)

    expect(BillingPlan.subscription_tiers.map(&:tier)).to include(basic_plan.tier, pro_plan.tier)
  end

  it "caps subscription seats at 13" do
    plans = (1..15).map do |idx|
      create(
        :billing_plan,
        tier: "tier#{idx}",
        key: "tier#{idx}_monthly",
        interval: "month",
        interval_count: 1,
        sort_order: idx,
        stripe_price_id: "price_tier#{idx}_monthly"
      )
    end

    create_pay_subscription(user: user, plan: plans.last)

    limits = described_class.new(user: user, expert_advisor: expert_advisor)

    expect(limits.subscription_cap).to eq(13)
  end

  it "grants one-time cap only when the user has active one-time access for the EA" do
    create(:license, :one_time, user: user, expert_advisor: expert_advisor)

    entitled = described_class.new(user: user, expert_advisor: expert_advisor)
    not_entitled = described_class.new(user: user, expert_advisor: create(:expert_advisor))

    expect(entitled.one_time_cap).to eq(8)
    expect(not_entitled.one_time_cap).to eq(0)
  end

  it "uses active manual subscriptions to determine tier cap" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, sort_order: 1)
    pro_plan = create(:billing_plan, tier: "pro", key: "pro_monthly", interval: "month", interval_count: 1, sort_order: 2)

    create(:manual_subscription, user: user, billing_plan: pro_plan, starts_at: 1.day.ago, ends_at: 2.days.from_now)

    limits = described_class.new(user: user, expert_advisor: expert_advisor)

    expect(limits.active_subscription_tier).to eq("pro")
    expect(limits.subscription_cap).to eq(6)
  end

  def create_pay_subscription(user:, plan:)
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
  end
end
