require "rails_helper"
require "securerandom"

RSpec.describe Licenses::SubscriptionLicenseSync do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:encoder) { instance_double(Licenses::LicenseKeyEncoder) }
  let!(:basic_ea) { create(:expert_advisor, ea_id: "basic-ea", allowed_subscription_tiers: %w[basic pro]) }
  let!(:all_ea) { create(:expert_advisor, ea_id: "all-ea", allowed_subscription_tiers: []) }
  let!(:pro_only_ea) { create(:expert_advisor, ea_id: "pro-ea", allowed_subscription_tiers: %w[pro]) }
  let!(:basic_plan) { create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, stripe_price_id: "price_basic_monthly") }
  let!(:pro_plan) { create(:billing_plan, tier: "pro", key: "pro_monthly", interval: "month", interval_count: 1, stripe_price_id: "price_pro_monthly") }
  let!(:basic_entitlement) { create(:billing_plan_entitlement, billing_plan: basic_plan, expert_advisor: basic_ea) }
  let!(:pro_entitlement) { create(:billing_plan_entitlement, billing_plan: pro_plan, expert_advisor: pro_only_ea) }
  let!(:basic_pro_entitlement) { create(:billing_plan_entitlement, billing_plan: pro_plan, expert_advisor: basic_ea) }
  let!(:disallowed_license) do
    create(
      :license,
      user:,
      expert_advisor: pro_only_ea,
      status: "active",
      trial_ends_at: nil,
      expires_at: nil,
      encrypted_key: "LEGACY",
      source: "legacy"
    )
  end

  before do
    clear_enqueued_jobs
    allow(encoder).to receive(:generate).and_return("ENCODED")
  end

  after do
    clear_enqueued_jobs
  end

  it "activates licenses for allowed EAs and expires those not in the plan" do
    travel_to Time.current do
      subscription = create_subscription(
        processor_plan: basic_plan.stripe_price_id,
        current_period_end: 2.weeks.from_now
      )

      described_class.new(subscription_id: subscription.id, encoder: encoder).call

      basic_license = License.find_by(user:, expert_advisor: basic_ea)
      expect(basic_license).to be_active
      expect(basic_license.access_source).to eq("subscription")
      expect(basic_license.plan_interval).to eq("monthly")
      expect(basic_license.encrypted_key).to eq("ENCODED")
      expect(basic_license.expires_at.to_i).to eq(subscription.current_period_end.to_i)
      expect(basic_license.last_synced_at.to_i).to eq(Time.current.to_i)
      expect(basic_license.source).to eq("stripe_subscription")

      universal_license = License.find_by(user:, expert_advisor: all_ea)
      expect(universal_license).to be_active
      expect(universal_license.plan_interval).to eq("monthly")

      disallowed_license.reload
      expect(disallowed_license).to be_expired
      expect(disallowed_license.last_synced_at).to be_present
    end
  end

  it "keeps one-time licenses active when syncing subscriptions" do
    subscription = create_subscription(
      processor_plan: basic_plan.stripe_price_id,
      current_period_end: 1.month.from_now
    )
    lifetime_license = disallowed_license
    lifetime_license.update!(access_source: "one_time", source: "stripe_charge")

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    lifetime_license.reload
    expect(lifetime_license).to be_active
    expect(lifetime_license.expires_at).to be_nil
    expect(lifetime_license.plan_interval).to be_nil
  end

  it "marks licenses as expired when the subscription period is over" do
    past_end = 1.day.ago
    subscription = create_subscription(
      processor_plan: basic_plan.stripe_price_id,
      current_period_end: past_end,
      ends_at: past_end
    )
    license = create(
      :license,
      user:,
      expert_advisor: basic_ea,
      status: "active",
      trial_ends_at: nil,
      expires_at: nil,
      encrypted_key: "LEGACY",
      source: "legacy"
    )

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    license.reload
    expect(license).to be_expired
    expect(license.expires_at.to_i).to eq(past_end.to_i)
  end

  it "activates pro-only EAs when on a pro plan" do
    subscription = create_subscription(
      processor_plan: pro_plan.stripe_price_id,
      current_period_end: 1.month.from_now
    )

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    pro_license = License.find_by(user:, expert_advisor: pro_only_ea)
    expect(pro_license).to be_active
    expect(pro_license.plan_interval).to eq("monthly")
  end

  def create_subscription(processor_plan:, current_period_end:, ends_at: nil)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )

    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: processor_plan,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: current_period_end,
      ends_at: ends_at
    )
  end

end
