require "rails_helper"

RSpec.describe Licenses::ManualSubscriptionSync, type: :service do
  it "syncs licenses for a manual subscription" do
    user = create(:user)
    plan = create(:billing_plan, tier: "pro", interval: "month", interval_count: 1)
    allowed_ea = create(:expert_advisor)
    disallowed_ea = create(:expert_advisor, allowed_subscription_tiers: ["basic"])
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
end
