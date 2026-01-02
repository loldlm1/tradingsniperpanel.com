require "rails_helper"
require "securerandom"

RSpec.describe Billing::CancelSubscription do
  let(:user) { create(:user) }
  let(:customer) do
    user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
  end

  let(:schedule_result) { Billing::CancelScheduledPlanChange::Result.new(status: :no_schedule) }
  let(:schedule_double) { instance_double(Billing::CancelScheduledPlanChange, call: schedule_result) }

  before do
    allow(Billing::CancelScheduledPlanChange).to receive(:new).and_return(schedule_double)
  end

  it "returns no_subscription when missing" do
    result = described_class.new(subscription: nil, user: user).call

    expect(result.status).to eq(:no_subscription)
  end

  it "short-circuits when already canceled" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "canceled",
      ends_at: 1.month.from_now,
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    expect_any_instance_of(Pay::Stripe::Subscription).not_to receive(:cancel)

    result = described_class.new(subscription: subscription, user: user).call

    expect(result.status).to eq(:already_canceled)
  end

  it "cancels at period end for active subscriptions" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:cancel) do |record|
      record.update!(ends_at: 1.month.from_now)
      true
    end
    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:sync!).and_return(true)

    result = described_class.new(subscription: subscription, user: user).call

    expect(result.status).to eq(:canceled)
    expect(result.ends_at).to be_present
  end
end
