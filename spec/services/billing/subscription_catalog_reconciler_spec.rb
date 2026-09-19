require "rails_helper"

RSpec.describe Billing::SubscriptionCatalogReconciler do
  before do
    load Rails.root.join("db", "seeds", "profiles.rb") unless defined?(Seeds::Profiles)
    load Rails.root.join("db", "seeds", "shared.rb") unless defined?(Seeds::BillingPlans)
    ENV.delete("STRIPE_PRIVATE_KEY")
  end

  it "converges on four plans, two products, three EAs, and ten entitlements" do
    service = described_class.new(
      profile: Seeds::Profiles::PROD_MIRROR,
      allow_local: true,
      migrator: successful_migrator
    )

    result = service.call
    counts = catalog_counts
    service.call

    expect(result.plans.map(&:key)).to match_array(Billing::SubscriptionCatalog.plan_keys)
    expect(result.expert_advisors.map(&:ea_id)).to match_array(%w[chu_sniper_trailing pandora_box sniper_advanced_panel])
    expect(result.plans.map(&:stripe_product_id).uniq.size).to eq(2)
    expect(BillingPlanEntitlement.count).to eq(10)
    expect(catalog_counts).to eq(counts)
    expect(service.verify!).to be(true)
  end

  it "restores the original Panel record and bundle without reactivating old licenses" do
    panel = create(:expert_advisor, ea_id: "sniper_advanced_panel", deleted_at: 1.day.ago)
    old_license = create(:license, expert_advisor: panel, status: "expired", expires_at: 1.day.ago)

    service = described_class.new(profile: Seeds::Profiles::PROD_MIRROR, allow_local: true, migrator: successful_migrator)
    service.call
    blob_id = panel.reload.ea_files.blob.id
    service.call

    expect(panel.reload.deleted_at).to be_nil
    expect(panel).not_to be_trial_enabled
    expect(panel.ea_files.blob.id).to eq(blob_id)
    expect(panel.ea_files.blob.checksum).to eq(
      Seeds::ExpertAdvisors.bundle_checksum(Seeds::ExpertAdvisors.bundle_path_for(panel.ea_id))
    )
    expect(old_license.reload).to be_expired
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
