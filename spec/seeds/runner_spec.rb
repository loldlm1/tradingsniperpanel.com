require "rails_helper"

RSpec.describe "Seeds::Runner" do
  before do
    load Rails.root.join("db", "seeds", "profiles.rb") unless defined?(Seeds::Profiles)
    load Rails.root.join("db", "seeds", "shared.rb") unless defined?(Seeds::BillingPlans)
    load Rails.root.join("db", "seeds", "runner.rb") unless defined?(Seeds::Runner)
  end

  around do |example|
    original_env = ENV.to_hash
    example.run
  ensure
    ENV.replace(original_env)
  end

  describe ".seed_for_environment!" do
    it "routes to full_qa outside production by default" do
      ENV.delete("SEED_PROFILE")
      allow(Seeds::Runner).to receive(:seed_full_qa!).and_return({})
      allow(Seeds::Runner).to receive(:seed_prod_mirror!).and_return([])

      Seeds::Runner.seed_for_environment!(environment: :staging, allow_local: false)

      expect(Seeds::Runner).to have_received(:seed_full_qa!).with(allow_local: false)
      expect(Seeds::Runner).not_to have_received(:seed_prod_mirror!)
    end

    it "uses prod_mirror when explicitly overridden" do
      ENV["SEED_PROFILE"] = Seeds::Profiles::PROD_MIRROR
      allow(Seeds::Runner).to receive(:seed_full_qa!).and_return({})
      allow(Seeds::Runner).to receive(:seed_prod_mirror!).and_return([])

      Seeds::Runner.seed_for_environment!(environment: :staging, allow_local: true)

      expect(Seeds::Runner).to have_received(:seed_prod_mirror!).with(allow_local: true)
      expect(Seeds::Runner).not_to have_received(:seed_full_qa!)
    end
  end

  describe ".seed_prod_mirror!" do
    it "converges twice on only Pandora monthly and annual while preserving old price history" do
      ENV["SEED_PROFILE"] = Seeds::Profiles::PROD_MIRROR
      ENV.delete("STRIPE_PRIVATE_KEY")
      old_monthly = create(
        :billing_plan,
        key: Billing::PandoraPricing::MONTHLY_KEY,
        name: "Pandora Pro Monthly",
        tier: Billing::PandoraPricing::TIER,
        interval: "month",
        interval_count: 1,
        amount_cents: 9_999,
        stripe_product_id: "prod_old_pandora",
        stripe_price_id: "price_old_pandora_monthly"
      )
      old_history = create(
        :billing_plan_price,
        billing_plan: old_monthly,
        stripe_price_id: old_monthly.stripe_price_id,
        amount_cents: old_monthly.amount_cents,
        current: true
      )
      stale_plan = create(:billing_plan, tier: "legacy", key: "legacy_monthly", name: "Legacy Monthly")
      stale_ea = create(:expert_advisor, ea_id: "legacy_ea", allowed_subscription_tiers: [ "legacy" ])
      create(:billing_plan_entitlement, billing_plan: stale_plan, expert_advisor: stale_ea)
      marketplace_plan = create(:billing_plan, :one_time, key: "legacy_product", name: "Legacy Product")
      marketplace_product = create(:marketplace_product, billing_plan: marketplace_plan, status: "active")

      records = Seeds::Runner.seed_prod_mirror!(allow_local: true)
      first_counts = catalog_counts
      Seeds::Runner.seed_prod_mirror!(allow_local: true)

      expect(records.map(&:ea_id)).to eq([ "pandora_box" ])
      expect(BillingPlan.active.order(:key).pluck(:key)).to eq(Billing::PandoraPricing::PLAN_KEYS.sort)
      expect(BillingPlan.find_by!(key: Billing::PandoraPricing::MONTHLY_KEY).amount_cents).to eq(7_900)
      expect(BillingPlan.find_by!(key: Billing::PandoraPricing::ANNUAL_KEY).amount_cents).to eq(61_620)
      expect(BillingPlan.active.distinct.pluck(:stripe_product_id)).to eq([ Seeds::BillingPlans::LOCAL_PRODUCT_ID ])
      expect(BillingPlanPrice.current.order(:amount_cents).pluck(:amount_cents)).to eq([ 7_900, 61_620 ])
      expect(old_history.reload).not_to be_current
      expect(old_history).not_to be_active
      expect(old_history.retired_at).to be_present
      expect(BillingPlan.for_price_id(old_history.stripe_price_id)).to eq(old_monthly)
      expect(ExpertAdvisor.active.pluck(:ea_id)).to eq([ "pandora_box" ])
      expect(stale_ea.reload.deleted_at).to be_present
      expect(stale_plan.reload).not_to be_active
      expect(marketplace_plan.reload).not_to be_active
      expect(marketplace_product.reload).to be_draft
      expect(BillingPlanEntitlement.pluck(:billing_plan_id, :expert_advisor_id).sort).to eq(
        BillingPlan.active.order(:id).pluck(:id).map { |plan_id| [ plan_id, records.first.id ] }.sort
      )
      expect(catalog_counts).to eq(first_counts)
    end
  end

  describe "Stripe requirements outside test" do
    it "requires Stripe only for the active Pandora billing catalog" do
      ENV.delete("STRIPE_PRIVATE_KEY")
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

      expect do
        Seeds::BillingPlans.seed_plans!(allow_local: true, profile: Seeds::Profiles::PROD_MIRROR)
      end.to raise_error(ArgumentError, /STRIPE_PRIVATE_KEY/)
      expect { Seeds::MarketplaceProducts.seed_products!(profile: Seeds::Profiles::PROD_MIRROR) }.not_to raise_error
      expect { Seeds::Addons.seed_addons!(profile: Seeds::Profiles::PROD_MIRROR) }.not_to raise_error
    end
  end

  def catalog_counts
    {
      plans: BillingPlan.count,
      prices: BillingPlanPrice.count,
      expert_advisors: ExpertAdvisor.unscoped.count,
      entitlements: BillingPlanEntitlement.count,
      marketplace_products: MarketplaceProduct.count,
      addons: Addon.count
    }
  end
end
