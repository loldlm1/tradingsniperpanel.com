require "rails_helper"

RSpec.describe Billing::SubscriptionCatalogReconciler do
  before do
    load Rails.root.join("db", "seeds", "profiles.rb") unless defined?(Seeds::Profiles)
    load Rails.root.join("db", "seeds", "shared.rb") unless defined?(Seeds::BillingPlans)
    ENV.delete("STRIPE_PRIVATE_KEY")
  end

  it "converges on four plans, two products, two EAs, and six entitlements" do
    service = described_class.new(
      profile: Seeds::Profiles::PROD_MIRROR,
      allow_local: true,
      migrator: successful_migrator
    )

    result = service.call
    counts = catalog_counts
    service.call

    expect(result.plans.map(&:key)).to match_array(Billing::SubscriptionCatalog.plan_keys)
    expect(result.expert_advisors.map(&:ea_id)).to match_array(%w[chu_sniper_trailing pandora_box])
    expect(result.plans.map(&:stripe_product_id).uniq.size).to eq(2)
    expect(BillingPlanEntitlement.count).to eq(6)
    expect(catalog_counts).to eq(counts)
    expect(service.verify!).to be(true)
  end

  def successful_migrator
    result = Billing::LegacySubscriptionMigrator::Result.new(scheduled: 0, verified: 0, current: 0, canceling: 0)
    instance_double(Billing::LegacySubscriptionMigrator, call: result, verify!: true)
  end

  def catalog_counts
    {
      plans: BillingPlan.count,
      prices: BillingPlanPrice.count,
      expert_advisors: ExpertAdvisor.unscoped.count,
      entitlements: BillingPlanEntitlement.count
    }
  end
end
