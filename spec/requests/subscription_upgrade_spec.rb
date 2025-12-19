require "rails_helper"
require "securerandom"

RSpec.describe "Subscription upgrades", type: :request do
  let(:user) { create(:user) }
  let(:customer) do
    user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
  end

  around do |example|
    original_env = ENV.to_hash
    ENV["STRIPE_PRICE_BASIC_MONTHLY"] = "price_basic_monthly"
    ENV["STRIPE_PRICE_HFT_MONTHLY"] = "price_hft_monthly"
    example.run
  ensure
    ENV.replace(original_env)
  end

  it "swaps an existing subscription instead of creating a new one" do
    existing = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_BASIC_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    expect_any_instance_of(Pay::Stripe::Subscription).to receive(:swap).with("price_hft_monthly", hash_including(prorate: true)).and_return(true)

    sign_in user, scope: :user

    post dashboard_checkout_path, params: { price_key: "hft_monthly" }

    expect(response).to redirect_to(dashboard_pricing_path)
  end

  it "prefers the most recent active subscription for display" do
    older = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_BASIC_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.from_now,
      created_at: 2.days.ago,
      type: "Pay::Stripe::Subscription"
    )

    newer = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: ENV["STRIPE_PRICE_HFT_MONTHLY"],
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      created_at: Time.current,
      type: "Pay::Stripe::Subscription"
    )

    sign_in user, scope: :user

    get dashboard_path

    expect(response).to be_successful
    expect(response.body).to include("Plan key: hft_monthly")
  end
end
