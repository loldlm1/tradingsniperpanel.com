require "rails_helper"
require "securerandom"

RSpec.describe ManualSubscription, type: :model do
  it "is valid with a subscription billing plan" do
    subscription = build(:manual_subscription)
    expect(subscription).to be_valid
  end

  it "rejects one-time billing plans" do
    subscription = build(:manual_subscription, billing_plan: create(:billing_plan, :one_time))
    expect(subscription).not_to be_valid
  end

  it "requires positive granted days and non-negative money" do
    subscription = build(:manual_subscription, granted_days: 0, amount_cents: -1)

    expect(subscription).not_to be_valid
    expect(subscription.errors[:granted_days]).to be_present
    expect(subscription.errors[:amount_cents]).to be_present
  end

  it "allows active or future periods to be revoked but not ended or terminal records" do
    active = build(:manual_subscription, starts_at: 1.day.ago, ends_at: 1.day.from_now, status: "active")
    future = build(:manual_subscription, starts_at: 1.day.from_now, ends_at: 2.days.from_now, status: "active")
    expired = build(:manual_subscription, starts_at: 2.days.ago, ends_at: 1.day.ago, status: "expired")
    cancelled = build(:manual_subscription, ends_at: 1.day.from_now, status: "cancelled")
    superseded = build(:manual_subscription, ends_at: 1.day.from_now, status: "superseded")

    expect(active).to be_revocable
    expect(future).to be_revocable
    expect(expired).not_to be_revocable
    expect(cancelled).not_to be_revocable
    expect(superseded).not_to be_revocable
  end

  it "requires ends_at after starts_at" do
    subscription = build(:manual_subscription, starts_at: Time.current, ends_at: 1.day.ago)
    expect(subscription).not_to be_valid
  end

  it "blocks grants while any active Stripe subscription exists" do
    plan = create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1)
    other_plan = create(:billing_plan, tier: "pro", key: "pro_monthly", interval: "month", interval_count: 1)
    user = create(:user)
    customer = user.pay_customers.create!(processor: "stripe", processor_id: "cus_manual_conflict", default: true)
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_manual_conflict",
      processor_plan: other_plan.stripe_price_id,
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

  it "keeps complimentary and pending amounts out of settled totals" do
    complimentary = build(:manual_subscription, payment_status: "complimentary", amount_cents: 0, paid_at: nil)
    pending = build(:manual_subscription, payment_status: "pending", amount_cents: 7900, paid_at: nil)
    paid = build(:manual_subscription, payment_status: "paid", amount_cents: 7900, paid_at: Time.current)

    expect(complimentary).to be_valid
    expect(pending).to be_valid
    expect(paid).to be_valid
    expect(complimentary.settled_amount_cents).to eq(0)
    expect(pending.settled_amount_cents).to eq(0)
    expect(paid.settled_amount_cents).to eq(7900)
  end

  it "requires coherent payment details" do
    complimentary = build(:manual_subscription, payment_status: "complimentary", amount_cents: 100, paid_at: nil)
    pending = build(:manual_subscription, payment_status: "pending", amount_cents: 100, paid_at: Time.current)
    paid = build(:manual_subscription, payment_status: "paid", amount_cents: 0, paid_at: nil)

    expect(complimentary).not_to be_valid
    expect(pending).not_to be_valid
    expect(paid).not_to be_valid
  end

  it "excludes superseded grants from active access" do
    subscription = create(:manual_subscription, starts_at: 1.day.ago, ends_at: 1.month.from_now)
    pay_subscription = create_pay_subscription(user: subscription.user)

    subscription.supersede_with!(pay_subscription: pay_subscription)

    expect(subscription.reload).to be_superseded
    expect(subscription).not_to be_active_for_time
    expect(described_class.active_at(Time.current)).not_to include(subscription)
  end

  it "scopes active subscriptions for a given time" do
    active = create(:manual_subscription, starts_at: 2.days.ago, ends_at: 2.days.from_now)
    inactive = create(:manual_subscription, starts_at: 10.days.ago, ends_at: 5.days.ago)

    expect(described_class.active_at(Time.current)).to include(active)
    expect(described_class.active_at(Time.current)).not_to include(inactive)
  end

  it "selects the newest starting grant at a shared transition boundary" do
    user = create(:user)
    current_plan = create(:billing_plan, tier: "current", key: "current_monthly")
    future_plan = create(:billing_plan, tier: "future", key: "future_monthly")
    boundary = 1.day.from_now.change(usec: 0)
    current = create(
      :manual_subscription,
      user: user,
      billing_plan: current_plan,
      starts_at: 10.days.ago,
      ends_at: boundary
    )
    future = create(
      :manual_subscription,
      user: user,
      billing_plan: future_plan,
      starts_at: boundary,
      ends_at: boundary + 30.days
    )

    expect(described_class.where(user: user).effective_at(boundary - 1.second)).to eq(current)
    expect(described_class.where(user: user).effective_at(boundary)).to eq(future)
  end

  it "allowlists ransack associations and attributes" do
    expect(described_class.ransackable_associations).to match_array(
      %w[billing_plan recorded_by_admin superseded_by_pay_subscription user]
    )
    expect(described_class.ransackable_attributes).to match_array(
      %w[
        billing_plan_id
        created_at
        ends_at
        granted_days
        id
        paid_at
        payment_status
        recorded_by_admin_id
        status
        superseded_at
        superseded_by_pay_subscription_id
        user_id
      ]
    )
  end


  def create_pay_subscription(user:)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
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
