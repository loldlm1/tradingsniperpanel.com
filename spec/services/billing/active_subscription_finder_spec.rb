require "rails_helper"

RSpec.describe Billing::ActiveSubscriptionFinder, type: :service do
  it "returns manual subscription when no stripe subscription exists" do
    user = create(:user)
    manual = create(:manual_subscription, user: user, ends_at: 1.month.from_now)

    result = described_class.new(user: user).call

    expect(result.subscription).to eq(manual)
    expect(result.manual?).to be(true)
  end

  it "prefers stripe subscription over manual" do
    user = create(:user)
    create(:manual_subscription, user: user, ends_at: 1.month.from_now)

    customer = Pay::Customer.create!(owner: user, processor: "stripe", processor_id: "cus_2", default: true)
    subscription = Pay::Subscription.create!(
      customer: customer,
      name: "default",
      processor_id: "sub_2",
      processor_plan: create(:billing_plan, tier: "pro", interval: "month", interval_count: 1).stripe_price_id,
      status: "active",
      current_period_end: 1.month.from_now
    )

    result = described_class.new(user: user).call

    expect(result.subscription).to eq(subscription)
    expect(result.stripe?).to be(true)
  end
end
