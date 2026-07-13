require "rails_helper"
require "securerandom"

RSpec.describe ManualSubscriptions::Grant do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:pandora_ea) { create(:expert_advisor, ea_id: "pandora_box") }
  let(:plan) do
    create(:billing_plan, tier: "pandora_pro", key: "pandora_pro_monthly", interval: "month", interval_count: 1).tap do |billing_plan|
      create(:billing_plan_entitlement, billing_plan: billing_plan, expert_advisor: pandora_ea)
    end
  end

  before { clear_enqueued_jobs }
  after { clear_enqueued_jobs }

  it "creates a complimentary grant from only user, Pandora plan, and days" do
    travel_to Time.current.change(usec: 0) do
      grant = described_class.new(
        user: user,
        billing_plan: plan,
        granted_days: 45,
        recorded_by_admin: admin
      ).call

      expect(grant.starts_at).to eq(Time.current)
      expect(grant.ends_at).to eq(45.days.from_now)
      expect(grant.granted_days).to eq(45)
      expect(grant).to be_payment_complimentary
      expect(grant.amount_cents).to eq(0)
      expect(grant.paid_at).to be_nil
      expect(grant.settled_amount_cents).to eq(0)
    end
  end

  it "extends repeated grants from the current manual end" do
    first = described_class.new(
      user: user,
      billing_plan: plan,
      granted_days: 30,
      recorded_by_admin: admin
    ).call

    second = described_class.new(
      user: user,
      billing_plan: plan,
      granted_days: 15,
      recorded_by_admin: admin
    ).call

    expect(second.starts_at).to eq(first.ends_at)
    expect(second.ends_at).to eq(first.ends_at + 15.days)
  end

  it "supports pending and paid details without changing the primary grant fields" do
    pending = described_class.new(
      user: user,
      billing_plan: plan,
      granted_days: 30,
      recorded_by_admin: admin,
      amount_cents: 7900,
      payment_status: "pending",
      reference: "invoice-1"
    ).call
    paid = described_class.new(
      user: create(:user),
      billing_plan: plan,
      granted_days: 30,
      recorded_by_admin: admin,
      amount_cents: 7900,
      payment_status: "paid"
    ).call

    expect(pending).to be_payment_pending
    expect(pending.settled_amount_cents).to eq(0)
    expect(pending.paid_at).to be_nil
    expect(paid).to be_payment_paid
    expect(paid.settled_amount_cents).to eq(7900)
    expect(paid.paid_at).to be_present
  end

  it "rejects non-Pandora plans and out-of-range days" do
    other_plan = create(:billing_plan)

    expect do
      described_class.new(
        user: user,
        billing_plan: other_plan,
        granted_days: 30,
        recorded_by_admin: admin
      ).call
    end.to raise_error(ArgumentError, "Pandora subscription plan is required")

    expect do
      described_class.new(
        user: user,
        billing_plan: plan,
        granted_days: 0,
        recorded_by_admin: admin
      )
    end.to raise_error(ArgumentError, /granted_days/)
  end

  it "rejects creation while an active Stripe subscription exists" do
    create_pay_subscription(user: user)

    expect do
      described_class.new(
        user: user,
        billing_plan: plan,
        granted_days: 30,
        recorded_by_admin: admin
      ).call
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "locks the user while calculating the extension boundary" do
    expect(user).to receive(:with_lock).and_call_original

    described_class.new(
      user: user,
      billing_plan: plan,
      granted_days: 30,
      recorded_by_admin: admin
    ).call
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
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
  end
end
