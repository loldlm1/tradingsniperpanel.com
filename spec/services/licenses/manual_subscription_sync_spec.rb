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
end
