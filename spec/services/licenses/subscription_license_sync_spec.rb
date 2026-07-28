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

  it "replaces revoked legacy one-time role access with Stripe subscription access" do
    subscription = create_subscription(
      processor_plan: basic_plan.stripe_price_id,
      current_period_end: 1.month.from_now
    )
    legacy_license = create(
      :license,
      user: user,
      expert_advisor: basic_ea,
      status: "revoked",
      access_source: "one_time",
      source: Licenses::RevokeRoleAccess::ROLE_LICENSE_SOURCE,
      trial_ends_at: nil,
      expires_at: 1.day.ago
    )

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    legacy_license.reload
    expect(legacy_license).to be_active
    expect(legacy_license.access_source).to eq("subscription")
    expect(legacy_license.source).to eq("stripe_subscription")
    expect(legacy_license.expires_at.to_i).to eq(subscription.current_period_end.to_i)
  end

  it "does not overwrite overlapping one-time licenses when the EA is allowed by the subscription tier" do
    subscription = create_subscription(
      processor_plan: basic_plan.stripe_price_id,
      current_period_end: 1.month.from_now
    )
    synced_at = 2.days.ago.change(usec: 0)
    lifetime_license = create(
      :license,
      :one_time,
      user: user,
      expert_advisor: basic_ea,
      source: "stripe_charge",
      encrypted_key: "ONE_TIME_KEY",
      last_synced_at: synced_at
    )
    original_updated_at = lifetime_license.updated_at

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    lifetime_license.reload
    aggregate_failures do
      expect(lifetime_license).to be_active
      expect(lifetime_license.access_source).to eq("one_time")
      expect(lifetime_license.plan_interval).to be_nil
      expect(lifetime_license.expires_at).to be_nil
      expect(lifetime_license.source).to eq("stripe_charge")
      expect(lifetime_license.encrypted_key).to eq("ONE_TIME_KEY")
      expect(lifetime_license.last_synced_at.to_i).to eq(synced_at.to_i)
      expect(lifetime_license.updated_at.to_i).to eq(original_updated_at.to_i)
    end
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

  it "reissues a synced license at its current token version" do
    subscription = create_subscription(
      processor_plan: basic_plan.stripe_price_id,
      current_period_end: 1.month.from_now
    )
    license = create(
      :license,
      user: user,
      expert_advisor: basic_ea,
      status: "active",
      token_version: 2,
      trial_ends_at: nil,
      expires_at: 1.week.from_now
    )
    expect(encoder).to receive(:generate).with(hash_including(token_version: 2)).and_return("VERSIONED")

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    expect(license.reload.token_version).to eq(2)
    expect(license.encrypted_key).to eq("VERSIONED")
  end

  it "reissues the key for a renewed period without incrementing the admin rotation version" do
    renewal_end = 1.month.from_now
    subscription = create_subscription(
      processor_plan: basic_plan.stripe_price_id,
      current_period_end: renewal_end
    )
    rotated_at = 2.days.ago.change(usec: 0)
    license = create(
      :license,
      user: user,
      expert_advisor: basic_ea,
      status: "active",
      token_version: 2,
      token_rotated_at: rotated_at,
      trial_ends_at: nil,
      expires_at: 1.week.from_now
    )
    previous_key = license.encrypted_key
    other_license = create(
      :license,
      user: create(:user),
      expert_advisor: basic_ea,
      status: "active",
      token_version: 2,
      token_rotated_at: 3.days.ago,
      trial_ends_at: nil,
      expires_at: 2.weeks.from_now
    )
    other_license_state = other_license.slice("encrypted_key", "expires_at", "token_version", "token_rotated_at")
    real_encoder = Licenses::LicenseKeyEncoder.new

    expect do
      described_class.new(subscription_id: subscription.id, encoder: real_encoder).call
    end.not_to change(AdminAuditEvent, :count)

    license.reload
    verifier = Licenses::LicenseVerifier.new(encoder: real_encoder)
    previous_result = verifier.call(
      source: ENV.fetch("EA_LICENSE_SOURCE_ID"),
      email: user.email,
      ea_id: basic_ea.ea_id,
      license_key: previous_key
    )
    current_result = verifier.call(
      source: ENV.fetch("EA_LICENSE_SOURCE_ID"),
      email: user.email,
      ea_id: basic_ea.ea_id,
      license_key: license.encrypted_key
    )

    expect(license.token_version).to eq(2)
    expect(license.token_rotated_at.to_i).to eq(rotated_at.to_i)
    expect(license.expires_at.to_i).to eq(renewal_end.to_i)
    expect(license.encrypted_key).not_to eq(previous_key)
    expect(previous_result.error).to eq(:invalid_key)
    expect(current_result.ok?).to be(true)
    expect(other_license.reload.slice(*other_license_state.keys)).to eq(other_license_state)
  end

  it "permanently supersedes active manual grants when Stripe becomes active" do
    manual = create(
      :manual_subscription,
      user: user,
      billing_plan: basic_plan,
      starts_at: 1.day.ago,
      ends_at: 1.month.from_now
    )
    subscription = create_subscription(
      processor_plan: basic_plan.stripe_price_id,
      current_period_end: 1.month.from_now
    )

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    expect(manual.reload).to be_superseded
    expect(manual.superseded_by_pay_subscription).to eq(subscription)
    expect(manual.superseded_at).to be_present
  end

  it "does not let an inactive Stripe callback overwrite current manual access" do
    manual = create(
      :manual_subscription,
      user: user,
      billing_plan: basic_plan,
      starts_at: 1.day.ago,
      ends_at: 1.month.from_now
    )
    Licenses::ManualSubscriptionSync.new(manual_subscription_id: manual.id, encoder: encoder).call
    manual_license = License.find_by!(user: user, expert_advisor: basic_ea)
    subscription = create_subscription(
      processor_plan: basic_plan.stripe_price_id,
      current_period_end: 1.day.ago,
      ends_at: 1.day.ago
    )

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    expect(manual.reload).to be_active
    expect(manual_license.reload.source).to eq("manual_subscription")
    expect(manual_license).to be_active
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

  it "issues only the Chu entitlement for the canonical Chu plan" do
    chu_ea = create(:expert_advisor, ea_id: "chu_sniper_trailing", allowed_subscription_tiers: [])
    pandora_ea = create(:expert_advisor, ea_id: "pandora_box", allowed_subscription_tiers: [])
    chu_plan = create(
      :billing_plan,
      tier: Billing::ChuSniperPricing::TIER,
      key: Billing::ChuSniperPricing::MONTHLY_KEY,
      name: "Chu Sniper Monthly",
      amount_cents: Billing::ChuSniperPricing::MONTHLY_CENTS,
      stripe_price_id: "price_chu_monthly",
      stripe_product_id: "prod_chu"
    )
    create(:billing_plan_entitlement, billing_plan: chu_plan, expert_advisor: chu_ea)

    period_end = 1.month.from_now
    subscription = create_subscription(
      processor_plan: chu_plan.stripe_price_id,
      current_period_end: period_end
    )

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    chu_license = License.find_by!(user: user, expert_advisor: chu_ea)
    expect(chu_license).to be_active
    expect(chu_license).to have_attributes(
      access_source: "subscription",
      plan_interval: "monthly",
      source: "stripe_subscription"
    )
    expect(chu_license.expires_at.to_i).to eq(period_end.to_i)
    expect(License.find_by(user: user, expert_advisor: pandora_ea)).to be_nil
  end

  it "issues both EA entitlements for the canonical Pandora plan" do
    chu_ea = create(:expert_advisor, ea_id: "chu_sniper_trailing", allowed_subscription_tiers: [])
    pandora_ea = create(:expert_advisor, ea_id: "pandora_box", allowed_subscription_tiers: [])
    pandora_plan = create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      name: "Pandora Monthly",
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
      stripe_price_id: "price_pandora_monthly",
      stripe_product_id: "prod_pandora"
    )
    create(:billing_plan_entitlement, billing_plan: pandora_plan, expert_advisor: chu_ea)
    create(:billing_plan_entitlement, billing_plan: pandora_plan, expert_advisor: pandora_ea)

    period_end = 1.month.from_now
    subscription = create_subscription(
      processor_plan: pandora_plan.stripe_price_id,
      current_period_end: period_end
    )

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    licenses = License.where(user: user, expert_advisor: [ chu_ea, pandora_ea ])
    expect(licenses.pluck(:expert_advisor_id)).to contain_exactly(chu_ea.id, pandora_ea.id)
    expect(licenses).to all(
      have_attributes(
        status: "active",
        access_source: "subscription",
        plan_interval: "monthly",
        source: "stripe_subscription"
      )
    )
    expect(licenses.map { |license| license.expires_at.to_i }).to all(eq(period_end.to_i))
  end

  it "fails closed when a canonical plan has stale price metadata" do
    chu_ea = create(:expert_advisor, ea_id: "chu_sniper_trailing", allowed_subscription_tiers: [])
    stale_plan = create(
      :billing_plan,
      tier: Billing::ChuSniperPricing::TIER,
      key: Billing::ChuSniperPricing::MONTHLY_KEY,
      name: "Stale Chu Monthly",
      amount_cents: Billing::ChuSniperPricing::MONTHLY_CENTS + 1,
      stripe_price_id: "price_chu_stale",
      stripe_product_id: "prod_chu"
    )
    create(:billing_plan_entitlement, billing_plan: stale_plan, expert_advisor: chu_ea)
    subscription = create_subscription(
      processor_plan: stale_plan.stripe_price_id,
      current_period_end: 1.month.from_now
    )

    described_class.new(subscription_id: subscription.id, encoder: encoder).call

    expect(License.find_by(user: user, expert_advisor: chu_ea)).to be_nil
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
