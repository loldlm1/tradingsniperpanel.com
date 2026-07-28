require "rails_helper"
require "digest"
require "securerandom"

RSpec.describe Licenses::BackfillChuSubscriptionLicenses do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.utc(2026, 7, 28, 12, 0, 0) }
  after { travel_back }

  it "creates Chu licenses for paid Pandora Stripe and manual access" do
    catalog = create_catalog
    stripe_user = create(:user)
    manual_user = create(:user)
    create_pay_subscription(user: stripe_user, plan: catalog.fetch(:pandora_plan))
    create(:manual_subscription, user: manual_user, billing_plan: catalog.fetch(:pandora_plan))

    result = described_class.new(dry_run: false, batch_size: 1).call

    expect(result).to have_attributes(scanned: 2, eligible: 2, created: 2, failed: 0)
    expect(License.where(expert_advisor: catalog.fetch(:chu_ea), user: [ stripe_user, manual_user ]).count).to eq(2)
    expect(License.where(expert_advisor: catalog.fetch(:chu_ea)).pluck(:plan_interval)).to all(eq("monthly"))
  end

  it "keeps a future Stripe cancellation eligible through its paid period" do
    catalog = create_catalog
    user = create(:user)
    create_pay_subscription(
      user: user,
      plan: catalog.fetch(:pandora_plan),
      period_end: 1.month.from_now,
      ends_at: 1.month.from_now
    )

    result = described_class.new(dry_run: false).call

    expect(result).to have_attributes(eligible: 1, created: 1, failed: 0)
  end

  it "supports dry-run, rerun idempotency, and Pandora key preservation" do
    catalog = create_catalog
    user = create(:user)
    subscription = create_pay_subscription(user: user, plan: catalog.fetch(:pandora_plan))
    pandora_license = create(
      :license,
      user: user,
      expert_advisor: catalog.fetch(:pandora_ea),
      status: "active",
      access_source: "subscription",
      source: "stripe_subscription",
      trial_ends_at: nil,
      expires_at: subscription.current_period_end
    )
    fingerprint = pandora_license.slice("id", "encrypted_key", "token_version", "token_rotated_at", "expires_at")

    dry_run = described_class.new(dry_run: true).call
    expect(dry_run).to have_attributes(created: 1, failed: 0)
    expect(License.find_by(user: user, expert_advisor: catalog.fetch(:chu_ea))).to be_nil

    described_class.new(dry_run: false).call
    chu_license = License.find_by!(user: user, expert_advisor: catalog.fetch(:chu_ea))
    created_at = chu_license.updated_at

    rerun = described_class.new(dry_run: false).call

    expect(rerun).to have_attributes(unchanged: 1, created: 0, repaired: 0, failed: 0)
    expect(chu_license.reload.updated_at.to_f).to eq(created_at.to_f)
    expect(pandora_license.reload.slice(*fingerprint.keys)).to eq(fingerprint)
  end

  it "repairs a stale Chu license without changing its token version metadata" do
    catalog = create_catalog
    user = create(:user)
    subscription = create_pay_subscription(user: user, plan: catalog.fetch(:pandora_plan))
    stale = create(
      :license,
      user: user,
      expert_advisor: catalog.fetch(:chu_ea),
      status: "expired",
      access_source: "subscription",
      source: "stripe_subscription",
      trial_ends_at: nil,
      expires_at: 1.day.ago,
      token_version: 2,
      token_rotated_at: 2.days.ago
    )
    previous_version = stale.token_version
    previous_rotation = stale.token_rotated_at

    result = described_class.new(dry_run: false).call

    expect(result.repaired).to eq(1)
    expect(stale.reload).to have_attributes(
      status: "active",
      plan_interval: "monthly",
      expires_at: subscription.current_period_end,
      token_version: previous_version,
      token_rotated_at: previous_rotation
    )
  end

  it "skips active one-time Chu access and inactive Pandora accounts" do
    catalog = create_catalog
    active_user = create(:user)
    chu_only_user = create(:user)
    expired_user = create(:user)
    cancelled_user = create(:user)
    create_pay_subscription(user: active_user, plan: catalog.fetch(:pandora_plan))
    create(:license, :one_time, user: active_user, expert_advisor: catalog.fetch(:chu_ea))
    create_pay_subscription(user: chu_only_user, plan: catalog.fetch(:chu_plan))
    create_pay_subscription(user: expired_user, plan: catalog.fetch(:pandora_plan), period_end: 1.day.ago)
    create_pay_subscription(user: cancelled_user, plan: catalog.fetch(:pandora_plan), period_end: 1.day.ago, ends_at: 1.day.ago)

    result = described_class.new(dry_run: false).call

    expect(result.skipped_one_time).to eq(1)
    expect(result.created).to eq(0)
    expect(License.find_by(user: chu_only_user, expert_advisor: catalog.fetch(:chu_ea))).to be_nil
    expect(License.where(user: [ expired_user, cancelled_user ], expert_advisor: catalog.fetch(:chu_ea))).to be_empty
  end

  it "continues after a per-user failure and succeeds on retry" do
    catalog = create_catalog
    user = create(:user)
    create_pay_subscription(user: user, plan: catalog.fetch(:pandora_plan))
    real_encoder = Licenses::LicenseKeyEncoder.new
    calls = 0
    allow(real_encoder).to receive(:generate) do |**attributes|
      calls += 1
      raise "temporary encoder failure" if calls == 1

      Licenses::LicenseKeyEncoder.new.generate(**attributes)
    end

    failed = described_class.new(dry_run: false, encoder: real_encoder).call

    expect(failed.failed).to eq(1)
    expect(failed.failed_user_ids).to eq([ user.id ])
    expect(License.find_by(user: user, expert_advisor: catalog.fetch(:chu_ea))).to be_nil

    retried = described_class.new(dry_run: false).call

    expect(retried.created).to eq(1)
    expect(retried.failed).to eq(0)
  end

  private

  def create_catalog
    chu_ea = create(:expert_advisor, ea_id: "chu_sniper_trailing", allowed_subscription_tiers: [], trial_enabled: false)
    pandora_ea = create(:expert_advisor, ea_id: "pandora_box", allowed_subscription_tiers: [], trial_enabled: false)
    chu_plan = create(
      :billing_plan,
      tier: Billing::ChuSniperPricing::TIER,
      key: Billing::ChuSniperPricing::MONTHLY_KEY,
      name: "Chu Monthly",
      amount_cents: Billing::ChuSniperPricing::MONTHLY_CENTS,
      stripe_price_id: "price_chu_backfill",
      stripe_product_id: "prod_chu_backfill"
    )
    pandora_plan = create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      name: "Pandora Monthly",
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
      stripe_price_id: "price_pandora_backfill",
      stripe_product_id: "prod_pandora_backfill"
    )
    create(:billing_plan_entitlement, billing_plan: chu_plan, expert_advisor: chu_ea)
    create(:billing_plan_entitlement, billing_plan: pandora_plan, expert_advisor: pandora_ea)
    create(:billing_plan_entitlement, billing_plan: pandora_plan, expert_advisor: chu_ea)

    { chu_ea: chu_ea, pandora_ea: pandora_ea, chu_plan: chu_plan, pandora_plan: pandora_plan }
  end

  def create_pay_subscription(user:, plan:, period_end: 1.month.from_now, ends_at: nil)
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
      current_period_end: period_end,
      ends_at: ends_at
    )
  end
end
