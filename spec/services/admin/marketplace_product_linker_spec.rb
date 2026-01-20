require "rails_helper"

RSpec.describe Admin::MarketplaceProductLinker do
  it "syncs one-time marketplace entitlements without touching subscriptions" do
    expert_advisor = create(:expert_advisor)
    subscription_plan = create(:billing_plan)
    create(:billing_plan_entitlement, billing_plan: subscription_plan, expert_advisor: expert_advisor)

    plan_a = create(:billing_plan, :one_time)
    plan_b = create(:billing_plan, :one_time)
    product_a = create(:marketplace_product, billing_plan: plan_a)
    product_b = create(:marketplace_product, billing_plan: plan_b)
    create(:billing_plan_entitlement, billing_plan: plan_a, expert_advisor: expert_advisor)
    create(:billing_plan_entitlement, billing_plan: plan_b, expert_advisor: expert_advisor)

    described_class.new(
      subject: expert_advisor,
      marketplace_product_ids: [product_a.id]
    ).call

    plan_ids = BillingPlanEntitlement.where(expert_advisor: expert_advisor).pluck(:billing_plan_id)
    expect(plan_ids).to include(subscription_plan.id, plan_a.id)
    expect(plan_ids).not_to include(plan_b.id)
  end
end
