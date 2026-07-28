require "rails_helper"

RSpec.describe Billing::PandoraCatalogReconciler do
  before do
    load Rails.root.join("db", "seeds", "profiles.rb") unless defined?(Seeds::Profiles)
    load Rails.root.join("db", "seeds", "shared.rb") unless defined?(Seeds::BillingPlans)
    ENV.delete("STRIPE_PRIVATE_KEY")
  end

  it "creates the complete Pandora catalog before retiring stale records" do
    stale = create_stale_catalog
    migrator = successful_migrator
    service = described_class.new(
      profile: Seeds::Profiles::PROD_MIRROR,
      allow_local: true,
      migrator: migrator
    )

    result = service.call

    expect(result.plans.map(&:key).sort).to eq(Billing::SubscriptionCatalog.plan_keys.sort)
    expect(BillingPlan.active.order(:key).pluck(:key)).to eq(Billing::SubscriptionCatalog.plan_keys.sort)
    expect(BillingPlan.purchasable.sum(:amount_cents)).to eq(
      Billing::ChuSniperPricing::MONTHLY_CENTS + Billing::ChuSniperPricing::ANNUAL_CENTS +
        Billing::PandoraPricing::MONTHLY_CENTS + Billing::PandoraPricing::ANNUAL_CENTS
    )
    expect(BillingPlan.purchasable.distinct.pluck(:stripe_product_id)).to contain_exactly(
      Seeds::BillingPlans::LOCAL_PRODUCT_IDS.fetch("chu_sniper_trailing"),
      Seeds::BillingPlans::LOCAL_PRODUCT_ID
    )
    expect(ExpertAdvisor.active.pluck(:ea_id)).to contain_exactly("chu_sniper_trailing", "pandora_box")
    expect(stale.fetch(:plan).reload).not_to be_active
    expect(stale.fetch(:expert_advisor).reload.deleted_at).to be_present
    expect(stale.fetch(:marketplace_product).reload).to be_draft
    expect(migrator).to have_received(:call).ordered
    expect(migrator).to have_received(:verify!).ordered
  end

  it "does not retire stale records when subscription scheduling fails" do
    stale = create_stale_catalog
    migrator = instance_double(Billing::LegacySubscriptionMigrator)
    allow(migrator).to receive(:call).and_raise(
      Billing::StripeSubscriptionSchedule::ConflictingScheduleError,
      "conflicting schedule"
    )
    service = described_class.new(
      profile: Seeds::Profiles::PROD_MIRROR,
      allow_local: true,
      migrator: migrator
    )

    expect { service.call }.to raise_error(Billing::StripeSubscriptionSchedule::ConflictingScheduleError)
    expect(stale.fetch(:plan).reload).to be_active
    expect(stale.fetch(:expert_advisor).reload.deleted_at).to be_nil
    expect(stale.fetch(:marketplace_product).reload).to be_active
  end

  it "does not retire stale records when desired plan creation fails" do
    stale = create_stale_catalog
    allow(Seeds::BillingPlans).to receive(:seed_plans!).and_raise(StandardError, "Stripe price creation failed")

    expect do
      described_class.new(profile: Seeds::Profiles::PROD_MIRROR, allow_local: true).call
    end.to raise_error(StandardError, "Stripe price creation failed")

    expect(stale.fetch(:plan).reload).to be_active
    expect(stale.fetch(:expert_advisor).reload.deleted_at).to be_nil
    expect(stale.fetch(:marketplace_product).reload).to be_active
  end

  it "allows legacy entitlements on canonical plans until retirement" do
    legacy_ea = create(:expert_advisor, ea_id: "legacy_ea", allowed_subscription_tiers: [ "legacy" ])
    canonical_plan = BillingPlan.find_by(key: Billing::PandoraPricing::MONTHLY_KEY) || create(
      :billing_plan,
      key: Billing::PandoraPricing::MONTHLY_KEY,
      name: "Legacy Pandora Monthly",
      tier: Billing::PandoraPricing::TIER
    )
    create(:billing_plan_entitlement, billing_plan: canonical_plan, expert_advisor: legacy_ea)

    result = described_class.new(
      profile: Seeds::Profiles::PROD_MIRROR,
      allow_local: true,
      migrator: successful_migrator
    ).call

    expect(result.retirement.removed_entitlements).to eq(1)
    expect(BillingPlanEntitlement.order(:billing_plan_id, :expert_advisor_id).pluck(:billing_plan_id, :expert_advisor_id)).to eq(
      result.plans.flat_map do |plan|
        Billing::SubscriptionCatalog.product_for_plan_key(plan.key).ea_ids.map do |ea_id|
          [ plan.id, result.expert_advisors.find { |ea| ea.ea_id == ea_id }.id ]
        end
      end.sort
    )
  end

  it "is idempotent across repeated local reconciliation" do
    service = described_class.new(
      profile: Seeds::Profiles::PROD_MIRROR,
      allow_local: true,
      migrator: successful_migrator
    )

    service.call
    counts = catalog_counts
    service.call

    expect(catalog_counts).to eq(counts)
    expect(service.verify!).to be(true)
  end

  it "keeps local test reconciliation offline when a Stripe key is present" do
    ENV["STRIPE_PRIVATE_KEY"] = "sk_test_not_used"
    expect(Billing::PlanCreator).not_to receive(:new)

    result = described_class.new(
      profile: Seeds::Profiles::PROD_MIRROR,
      allow_local: true
    ).call

    expect(result.plans.map(&:stripe_product_id).uniq).to contain_exactly(
      Seeds::BillingPlans::LOCAL_PRODUCT_ID,
      Seeds::BillingPlans::LOCAL_PRODUCT_IDS.fetch("chu_sniper_trailing")
    )
  end

  def successful_migrator
    result = Billing::LegacySubscriptionMigrator::Result.new(scheduled: 0, verified: 0, current: 0, canceling: 0)
    instance_double(Billing::LegacySubscriptionMigrator, call: result, verify!: true)
  end

  def create_stale_catalog
    expert_advisor = create(:expert_advisor, ea_id: "legacy_ea", allowed_subscription_tiers: [ "legacy" ])
    plan = create(:billing_plan, tier: "legacy", key: "legacy_monthly", name: "Legacy Monthly")
    create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: expert_advisor)
    marketplace_plan = create(:billing_plan, :one_time, key: "legacy_product", name: "Legacy Product")
    marketplace_product = create(:marketplace_product, billing_plan: marketplace_plan, status: "active")
    { expert_advisor:, plan:, marketplace_product: }
  end

  def catalog_counts
    {
      plans: BillingPlan.count,
      prices: BillingPlanPrice.count,
      expert_advisors: ExpertAdvisor.unscoped.count,
      entitlements: BillingPlanEntitlement.count,
      marketplace_products: MarketplaceProduct.count
    }
  end
end
