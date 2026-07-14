require "rails_helper"
require "securerandom"

RSpec.describe ManualSubscriptions::Grant do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:pandora_ea) { ExpertAdvisor.find_by(ea_id: "pandora_box") || create(:expert_advisor, ea_id: "pandora_box") }
  let(:plan) do
    billing_plan = BillingPlan.find_by(key: Billing::PandoraPricing::MONTHLY_KEY) || create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      interval: "month",
      interval_count: 1,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )
    BillingPlanEntitlement.find_or_create_by!(billing_plan: billing_plan, expert_advisor: pandora_ea)
    billing_plan
  end

  before { clear_enqueued_jobs }
  after { clear_enqueued_jobs }

  it "creates a complimentary grant from only user, Pandora plan, and days" do
    travel_to Time.current.change(usec: 0) do
      grant = described_class.new(
        user: user,
        billing_plan: plan,
        granted_days: 45,
        recorded_by_admin: admin,
        request_id: SecureRandom.uuid
      ).call

      expect(grant.starts_at).to eq(Time.current)
      expect(grant.ends_at).to eq(45.days.from_now)
      expect(grant.granted_days).to eq(45)
      expect(grant).to be_payment_complimentary
      expect(grant.amount_cents).to eq(0)
      expect(grant.paid_at).to be_nil
      expect(grant.settled_amount_cents).to eq(0)

      license = License.find_by!(user: user, expert_advisor: pandora_ea)
      expect(license).to be_active
      expect(license.source).to eq("manual_subscription")
      expect(license.expires_at).to eq(grant.ends_at)
    end
  end

  it "extends repeated grants from the current manual end" do
    first = described_class.new(
      user: user,
      billing_plan: plan,
      granted_days: 30,
      recorded_by_admin: admin,
      request_id: SecureRandom.uuid
    ).call

    second = described_class.new(
      user: user,
      billing_plan: plan,
      granted_days: 15,
      recorded_by_admin: admin,
      request_id: SecureRandom.uuid
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
      request_id: SecureRandom.uuid,
      amount_cents: 7900,
      payment_status: "pending",
      reference: "invoice-1"
    ).call
    paid = described_class.new(
      user: create(:user),
      billing_plan: plan,
      granted_days: 30,
      recorded_by_admin: admin,
      request_id: SecureRandom.uuid,
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
        recorded_by_admin: admin,
        request_id: SecureRandom.uuid
      ).call
    end.to raise_error(ArgumentError, "Pandora subscription plan is required")

    expect do
      described_class.new(
        user: user,
        billing_plan: plan,
        granted_days: 0,
        recorded_by_admin: admin,
        request_id: SecureRandom.uuid
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
        recorded_by_admin: admin,
        request_id: SecureRandom.uuid
      ).call
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "locks the user while calculating the extension boundary" do
    expect(user).to receive(:with_lock).and_call_original

    described_class.new(
      user: user,
      billing_plan: plan,
      granted_days: 30,
      recorded_by_admin: admin,
      request_id: SecureRandom.uuid
    ).call
  end

  it "records the grant atomically and treats a repeated request as idempotent" do
    request_id = SecureRandom.uuid
    attributes = {
      user: user,
      billing_plan: plan,
      granted_days: 30,
      recorded_by_admin: admin,
      request_id: request_id
    }

    first = described_class.new(**attributes).call
    second = described_class.new(**attributes).call

    expect(second).to eq(first)
    expect(user.manual_subscriptions.where(id: first.id).count).to eq(1)
    event = AdminAuditEvent.find_by!(request_id: request_id)
    expect(event.metadata).to include("manual_subscription_id" => first.id, "granted_days" => 30)
    expect(event.metadata).not_to have_key("notes")
  end

  it "rejects reuse of a request identifier for different grant terms" do
    request_id = SecureRandom.uuid
    described_class.new(
      user: user,
      billing_plan: plan,
      granted_days: 30,
      recorded_by_admin: admin,
      request_id: request_id
    ).call

    expect do
      described_class.new(
        user: user,
        billing_plan: plan,
        granted_days: 60,
        recorded_by_admin: admin,
        request_id: request_id
      ).call
    end.to raise_error(described_class::IdempotencyConflict)

    expect(user.manual_subscriptions.count).to eq(1)
  end

  it "rolls back the grant when its audit event cannot be written" do
    allow(AdminAuditEvent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(AdminAuditEvent.new))

    expect do
      described_class.new(
        user: user,
        billing_plan: plan,
        granted_days: 30,
        recorded_by_admin: admin,
        request_id: SecureRandom.uuid
      ).call
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(user.manual_subscriptions).to be_empty
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
