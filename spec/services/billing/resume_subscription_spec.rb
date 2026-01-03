require "rails_helper"
require "securerandom"

RSpec.describe Billing::ResumeSubscription do
  let(:user) { create(:user) }
  let(:customer) do
    user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
  end

  it "returns no_subscription when missing" do
    result = described_class.new(subscription: nil, user: user).call

    expect(result.status).to eq(:no_subscription)
  end

  it "returns not_resumable when not on grace period" do
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

    result = described_class.new(subscription: subscription, user: user).call

    expect(result.status).to eq(:not_resumable)
  end

  it "resumes a canceled subscription within the grace period" do
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: "price_basic_monthly",
      status: "active",
      ends_at: 1.month.from_now,
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:resume) do |record|
      record.update!(ends_at: nil, status: "active")
      true
    end
    allow_any_instance_of(Pay::Stripe::Subscription).to receive(:sync!).and_return(true)

    result = described_class.new(subscription: subscription, user: user).call

    expect(result.status).to eq(:resumed)
    expect(subscription.reload.ends_at).to be_nil
  end
end
