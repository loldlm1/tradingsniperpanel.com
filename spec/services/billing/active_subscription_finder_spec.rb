require "rails_helper"
require "securerandom"

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

  it "ignores superseded and future manual grants" do
    user = create(:user)
    current = create(:manual_subscription, user: user, starts_at: 1.day.ago, ends_at: 1.month.from_now)
    future = create(
      :manual_subscription,
      user: user,
      starts_at: current.ends_at,
      ends_at: current.ends_at + 1.month
    )
    pay_subscription = create_pay_subscription(user: user)
    current.supersede_with!(pay_subscription: pay_subscription)
    pay_subscription.update!(status: "canceled", current_period_end: 1.day.ago, ends_at: 1.day.ago)

    result = described_class.new(user: user).call

    expect(result.subscription).to be_nil
    expect(result.manual?).to be(false)
    expect(future.reload).to be_active
  end

  it "finds an active Stripe subscription across all customer records" do
    user = create(:user)
    user.pay_customers.create!(processor: "stripe", processor_id: "cus_empty", default: true)
    subscription = create_pay_subscription(user: user, default: false)

    result = described_class.new(user: user).call

    expect(result.subscription).to eq(subscription)
    expect(result.stripe?).to be(true)
  end

  def create_pay_subscription(user:, default: true)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: default
    )
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_pandora_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
  end
end
