require "rails_helper"

RSpec.describe Catalog::RetireLegacyAccess do
  it "retires stale commerce and access while preserving historical rows" do
    monthly, annual, pandora = create_pandora_catalog
    stale_ea = create(:expert_advisor, ea_id: "legacy_ea", allowed_subscription_tiers: [ "legacy" ])
    stale_plan = create(:billing_plan, tier: "legacy", key: "legacy_monthly", name: "Legacy Monthly")
    stale_history = create(
      :billing_plan_price,
      billing_plan: stale_plan,
      stripe_price_id: stale_plan.stripe_price_id,
      current: true
    )
    create(:billing_plan_entitlement, billing_plan: stale_plan, expert_advisor: stale_ea)
    one_time_plan = create(:billing_plan, :one_time, key: "legacy_product", name: "Legacy Product")
    marketplace = create(:marketplace_product, billing_plan: one_time_plan, status: "active")
    addon = create(:addon, billing_plan: one_time_plan, addonable: stale_ea)
    manual = create(:manual_subscription, billing_plan: stale_plan)

    one_time_license = create(:license, user: create(:user), expert_advisor: pandora, access_source: "one_time", status: "active")
    role_license = create(
      :license,
      user: create(:user),
      expert_advisor: pandora,
      access_source: "subscription",
      source: Licenses::RevokeRoleAccess::ROLE_LICENSE_SOURCE,
      status: "trial",
      trial_ends_at: 1.week.from_now
    )
    legacy_license = create(:license, user: create(:user), expert_advisor: stale_ea, access_source: "subscription", status: "active")
    pandora_license = create(:license, user: create(:user), expert_advisor: pandora, access_source: "subscription", status: "active")
    now = Time.zone.parse("2026-07-13 12:00:00")

    result = described_class.new(desired_plans: [ monthly, annual ], pandora_ea: pandora, remote: false, now: now).call

    expect(result.retired_plans).to eq(2)
    expect(result.retired_prices).to eq(1)
    expect(result.retired_marketplace_products).to eq(1)
    expect(result.retired_addons).to eq(1)
    expect(result.retired_expert_advisors).to eq(1)
    expect(result.removed_entitlements).to eq(1)
    expect(result.cancelled_manual_grants).to eq(1)
    expect(result.revoked_licenses).to eq(2)
    expect(result.expired_licenses).to eq(1)

    expect(stale_plan.reload).not_to be_active
    expect(one_time_plan.reload).not_to be_active
    expect(stale_history.reload).not_to be_active
    expect(stale_history).not_to be_current
    expect(stale_history.retired_at).to eq(now)
    expect(marketplace.reload).to be_draft
    expect(addon.reload).to be_persisted
    expect(stale_ea.reload.deleted_at).to eq(now)
    expect(manual.reload).to be_cancelled
    expect(one_time_license.reload).to be_revoked
    expect(role_license.reload).to be_revoked
    expect(legacy_license.reload).to be_expired
    expect(pandora_license.reload).to be_active
    expect(BillingPlanEntitlement.pluck(:billing_plan_id, :expert_advisor_id).sort).to eq(
      [ [ monthly.id, pandora.id ], [ annual.id, pandora.id ] ].sort
    )

    second = described_class.new(desired_plans: [ monthly, annual ], pandora_ea: pandora, remote: false, now: now + 1.hour).call
    expect(second.retired_plans).to eq(0)
    expect(second.retired_prices).to eq(0)
    expect(second.revoked_licenses).to eq(0)
    expect(second.expired_licenses).to eq(0)
  end

  it "deactivates retired Stripe prices and products only after the desired product is excluded" do
    monthly, annual, pandora = create_pandora_catalog
    old_desired_price = create(
      :billing_plan_price,
      billing_plan: monthly,
      stripe_price_id: "price_old_pandora_monthly",
      amount_cents: 9_999,
      active: true,
      current: false,
      retired_at: 1.day.ago
    )
    stale_plan = create(
      :billing_plan,
      tier: "legacy",
      key: "legacy_monthly",
      name: "Legacy Monthly",
      stripe_product_id: "prod_legacy",
      stripe_price_id: "price_legacy"
    )
    stale_price = create(
      :billing_plan_price,
      billing_plan: stale_plan,
      stripe_price_id: stale_plan.stripe_price_id,
      current: true
    )
    original_key = ENV["STRIPE_PRIVATE_KEY"]
    ENV["STRIPE_PRIVATE_KEY"] = "stripe_test_key"
    allow(Stripe::Price).to receive(:retrieve) { |id| Struct.new(:id, :active).new(id, true) }
    allow(Stripe::Product).to receive(:retrieve) { |id| Struct.new(:id, :active).new(id, true) }
    expect(Stripe::Price).to receive(:update).with(old_desired_price.stripe_price_id, active: false)
    expect(Stripe::Price).to receive(:update).with(stale_price.stripe_price_id, active: false)
    expect(Stripe::Product).to receive(:update).with(stale_plan.stripe_product_id, active: false)
    expect(Stripe::Product).not_to receive(:update).with("prod_pandora", anything)

    result = described_class.new(desired_plans: [ monthly, annual ], pandora_ea: pandora, remote: true).call

    expect(result.retired_remote_prices).to eq(2)
    expect(result.retired_remote_products).to eq(1)
  ensure
    ENV["STRIPE_PRIVATE_KEY"] = original_key
  end

  def create_pandora_catalog
    pandora = create(
      :expert_advisor,
      ea_id: "pandora_box",
      name: "PANDORA BOX EA",
      allowed_subscription_tiers: [ Billing::PandoraPricing::TIER ]
    )
    monthly = create_pandora_plan(
      key: Billing::PandoraPricing::MONTHLY_KEY,
      name: "Pandora Box EA Monthly",
      interval: "month",
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
      price_id: "price_pandora_monthly"
    )
    annual = create_pandora_plan(
      key: Billing::PandoraPricing::ANNUAL_KEY,
      name: "Pandora Box EA Annual",
      interval: "year",
      amount_cents: Billing::PandoraPricing::ANNUAL_CENTS,
      price_id: "price_pandora_annual"
    )
    [ monthly, annual ].each do |plan|
      create(:billing_plan_price, billing_plan: plan, stripe_price_id: plan.stripe_price_id, current: true)
      create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: pandora)
    end
    [ monthly, annual, pandora ]
  end

  def create_pandora_plan(key:, name:, interval:, amount_cents:, price_id:)
    create(
      :billing_plan,
      key: key,
      name: name,
      tier: Billing::PandoraPricing::TIER,
      interval: interval,
      interval_count: 1,
      amount_cents: amount_cents,
      currency: Billing::PandoraPricing::CURRENCY,
      stripe_product_id: "prod_pandora",
      stripe_price_id: price_id
    )
  end
end
