require "rails_helper"
require "digest"
require "securerandom"

RSpec.describe Licenses::ManualSubscriptionSync, type: :service do
  it "syncs licenses for a manual subscription" do
    user = create(:user)
    plan = create(:billing_plan, tier: "pro", interval: "month", interval_count: 1)
    allowed_ea = create(:expert_advisor)
    disallowed_ea = create(:expert_advisor, allowed_subscription_tiers: [ "basic" ])
    create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: allowed_ea)

    subscription = create(
      :manual_subscription,
      user: user,
      billing_plan: plan,
      starts_at: 1.day.ago,
      ends_at: 29.days.from_now
    )

    described_class.new(manual_subscription_id: subscription.id).call

    allowed_license = License.find_by(user: user, expert_advisor: allowed_ea)
    expect(allowed_license).to be_present
    expect(allowed_license).to be_active
    expect(allowed_license.plan_interval).to eq(plan.interval_key)
    expect(allowed_license.expires_at.to_i).to eq(subscription.ends_at.to_i)

    disallowed_license = License.find_by(user: user, expert_advisor: disallowed_ea)
    expect(disallowed_license).to be_nil
  end

  it "does not overwrite overlapping one-time licenses" do
    user = create(:user)
    plan = create(:billing_plan, tier: "pro", interval: "month", interval_count: 1)
    allowed_ea = create(:expert_advisor)
    create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: allowed_ea)
    synced_at = 3.days.ago.change(usec: 0)
    lifetime_license = create(
      :license,
      :one_time,
      user: user,
      expert_advisor: allowed_ea,
      source: "stripe_charge",
      encrypted_key: "ONE_TIME_KEY",
      last_synced_at: synced_at
    )
    original_updated_at = lifetime_license.updated_at

    subscription = create(
      :manual_subscription,
      user: user,
      billing_plan: plan,
      starts_at: 1.day.ago,
      ends_at: 29.days.from_now
    )

    described_class.new(manual_subscription_id: subscription.id).call

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

  it "replaces revoked legacy one-time role access with manual subscription access" do
    user = create(:user)
    plan = create(:billing_plan, tier: "pro", interval: "month", interval_count: 1)
    allowed_ea = create(:expert_advisor)
    create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: allowed_ea)
    legacy_license = create(
      :license,
      user: user,
      expert_advisor: allowed_ea,
      status: "revoked",
      access_source: "one_time",
      source: Licenses::RevokeRoleAccess::ROLE_LICENSE_SOURCE,
      trial_ends_at: nil,
      expires_at: 1.day.ago
    )
    subscription = create(
      :manual_subscription,
      user: user,
      billing_plan: plan,
      starts_at: 1.day.ago,
      ends_at: 29.days.from_now
    )

    described_class.new(manual_subscription_id: subscription.id).call

    legacy_license.reload
    expect(legacy_license).to be_active
    expect(legacy_license.access_source).to eq("subscription")
    expect(legacy_license.source).to eq("manual_subscription")
    expect(legacy_license.expires_at.to_i).to eq(subscription.ends_at.to_i)
  end

  it "uses the furthest end of contiguous manual grants" do
    user = create(:user)
    plan = create(:billing_plan, tier: "pro", interval: "month", interval_count: 1)
    allowed_ea = create(:expert_advisor)
    create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: allowed_ea)
    first = create(
      :manual_subscription,
      user: user,
      billing_plan: plan,
      starts_at: 1.day.ago,
      ends_at: 2.days.from_now,
      granted_days: 3
    )
    extension = create(
      :manual_subscription,
      user: user,
      billing_plan: plan,
      starts_at: first.ends_at,
      ends_at: first.ends_at + 10.days,
      granted_days: 10
    )

    described_class.new(manual_subscription_id: extension.id).call

    license = License.find_by!(user: user, expert_advisor: allowed_ea)
    expect(license).to be_active
    expect(license.expires_at.to_i).to eq(extension.ends_at.to_i)
  end

  it "expires subscription licenses after the manual grant is revoked" do
    user = create(:user)
    plan = create(:billing_plan, tier: "pro", interval: "month", interval_count: 1)
    allowed_ea = create(:expert_advisor)
    create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: allowed_ea)
    subscription = create(:manual_subscription, user: user, billing_plan: plan)

    described_class.new(manual_subscription_id: subscription.id).call
    license = License.find_by!(user: user, expert_advisor: allowed_ea)
    expect(license).to be_active

    subscription.update!(status: "cancelled")
    described_class.new(manual_subscription_id: subscription.id).call

    expect(license.reload).to be_expired
  end

  it "supersedes a delayed manual job without overwriting Stripe access" do
    user = create(:user)
    plan = create(:billing_plan, tier: "pro", interval: "month", interval_count: 1)
    allowed_ea = create(:expert_advisor)
    create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: allowed_ea)
    manual = create(:manual_subscription, user: user, billing_plan: plan)
    stripe_license = create(
      :license,
      user: user,
      expert_advisor: allowed_ea,
      status: "active",
      trial_ends_at: nil,
      expires_at: 1.month.from_now,
      source: "stripe_subscription"
    )
    original_key_digest = Digest::SHA256.hexdigest(stripe_license.encrypted_key)
    pay_subscription = create_pay_subscription(user: user, plan: plan)

    described_class.new(manual_subscription_id: manual.id).call

    expect(manual.reload).to be_superseded
    expect(manual.superseded_by_pay_subscription).to eq(pay_subscription)
    expect(stripe_license.reload.source).to eq("stripe_subscription")
    expect(Digest::SHA256.hexdigest(stripe_license.encrypted_key)).to eq(original_key_digest)
  end

  def create_pay_subscription(user:, plan:)
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
