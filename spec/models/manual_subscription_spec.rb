require "rails_helper"

RSpec.describe ManualSubscription, type: :model do
  it "is valid with a subscription billing plan" do
    subscription = build(:manual_subscription)
    expect(subscription).to be_valid
  end

  it "rejects one-time billing plans" do
    subscription = build(:manual_subscription, billing_plan: create(:billing_plan, :one_time))
    expect(subscription).not_to be_valid
  end

  it "requires ends_at after starts_at" do
    subscription = build(:manual_subscription, starts_at: Time.current, ends_at: 1.day.ago)
    expect(subscription).not_to be_valid
  end

  it "blocks overlaps with active Stripe subscriptions for the same plan" do
    plan = create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1)
    user = create(:user)
    customer = user.pay_customers.create!(processor: "stripe", processor_id: "cus_manual_conflict", default: true)
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_manual_conflict",
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      type: "Pay::Stripe::Subscription"
    )

    subscription = build(:manual_subscription, user: user, billing_plan: plan)

    expect(subscription).not_to be_valid
    expect(subscription.errors[:base]).to include(I18n.t("errors.messages.billing_conflict"))
  end

  it "scopes active subscriptions for a given time" do
    active = create(:manual_subscription, starts_at: 2.days.ago, ends_at: 2.days.from_now)
    inactive = create(:manual_subscription, starts_at: 10.days.ago, ends_at: 5.days.ago)

    expect(described_class.active_at(Time.current)).to include(active)
    expect(described_class.active_at(Time.current)).not_to include(inactive)
  end

  it "allowlists ransack associations and attributes" do
    expect(described_class.ransackable_associations).to match_array(%w[billing_plan recorded_by_admin user])
    expect(described_class.ransackable_attributes).to match_array(
      %w[billing_plan_id created_at ends_at id paid_at recorded_by_admin_id status user_id]
    )
  end
end
