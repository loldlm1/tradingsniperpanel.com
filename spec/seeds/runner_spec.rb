require "rails_helper"

RSpec.describe "Seeds::Runner" do
  before do
    load Rails.root.join("db", "seeds", "profiles.rb") unless defined?(Seeds::Profiles)
    load Rails.root.join("db", "seeds", "shared.rb") unless defined?(Seeds::ExpertAdvisors) && defined?(Seeds::BillingPlans)
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
    it "keeps only prod_mirror plans, seeds fibonacci addons, and removes stale seed data" do
      ENV["SEED_PROFILE"] = Seeds::Profiles::PROD_MIRROR
      ENV.delete("STRIPE_PRIVATE_KEY")

      stale_plan = create(
        :billing_plan,
        tier: "hft",
        interval: "month",
        interval_count: 1,
        amount_cents: 4000,
        sort_order: 2,
        active: true
      )
      stale_ea = create(
        :expert_advisor,
        name: "Momentum Pulse Indicator",
        ea_id: "momentum_pulse_indicator",
        tier_rank: 3,
        allowed_subscription_tiers: %w[hft pro]
      )
      create(:billing_plan_entitlement, billing_plan: stale_plan, expert_advisor: stale_ea)

      stale_marketplace_plan = create(:billing_plan, :one_time, key: "marketplace_stale_seed", active: true)
      stale_marketplace_product = create(
        :marketplace_product,
        slug: "stale_seed_product",
        key: "marketplace_stale_seed_product",
        status: "active",
        billing_plan: stale_marketplace_plan
      )

      Seeds::Runner.seed_prod_mirror!(allow_local: true)

      active_subscription_keys = BillingPlan.subscription.active.order(:key).pluck(:key)
      expect(active_subscription_keys).to eq(%w[basic_annual basic_monthly fibonacci_elite_annual fibonacci_elite_monthly pandora_pro_annual pandora_pro_monthly])
      expect(BillingPlan.find_by(key: "basic_monthly")&.amount_cents).to eq(2000)
      expect(BillingPlan.find_by(key: "basic_annual")&.amount_cents).to eq(18_000)
      expect(BillingPlan.find_by(key: "pandora_pro_monthly")&.amount_cents).to eq(3000)
      expect(BillingPlan.find_by(key: "pandora_pro_annual")&.amount_cents).to eq(27_000)
      expect(BillingPlan.find_by(key: "fibonacci_elite_monthly")&.amount_cents).to eq(4000)
      expect(BillingPlan.find_by(key: "fibonacci_elite_annual")&.amount_cents).to eq(36_000)
      expect(stale_plan.reload.active).to eq(false)

      expect(ExpertAdvisor.active.pluck(:ea_id)).to match_array(%w[fibonacci_elite pandora_box sniper_advanced_panel])
      expect(stale_ea.reload.deleted_at).to be_present
      sniper_ea = ExpertAdvisor.find_by!(ea_id: "sniper_advanced_panel")
      pandora_ea = ExpertAdvisor.find_by!(ea_id: "pandora_box")
      fibonacci_ea = ExpertAdvisor.find_by!(ea_id: "fibonacci_elite")
      expect(sniper_ea.doc_guide_en).to eq(File.read(Rails.root.join("docs_eas", "sniper_advanced_panel", "sniper_advanced_panel_guide_en.md")))
      expect(sniper_ea.doc_guide_es).to eq(File.read(Rails.root.join("docs_eas", "sniper_advanced_panel", "sniper_advanced_panel_guide_es.md")))
      expect(pandora_ea.doc_guide_en).to eq(File.read(Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_guide_en.md")))
      expect(pandora_ea.doc_guide_es).to eq(File.read(Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_guide_es.md")))
      expect(fibonacci_ea.doc_guide_en).to eq(File.read(Rails.root.join("docs_eas", "fibonacci_ea", "addons", "product_copy", "en", "base-ea.md")))
      expect(fibonacci_ea.doc_guide_es).to eq(File.read(Rails.root.join("docs_eas", "fibonacci_ea", "addons", "product_copy", "es", "base-ea.md")))
      expect(pandora_ea.doc_guide_en).not_to include(Seeds::ExpertAdvisors::INTRO_VIDEO_TOKEN)
      expect(pandora_ea.doc_guide_en).not_to include(Seeds::ExpertAdvisors::OUTRO_YOUTUBE_TOKEN)
      expect(fibonacci_ea.doc_guide_en).not_to include(Seeds::ExpertAdvisors::INTRO_VIDEO_TOKEN)
      expect(fibonacci_ea.doc_guide_en).not_to include(Seeds::ExpertAdvisors::OUTRO_YOUTUBE_TOKEN)

      pandora_product = MarketplaceProduct.find_by(slug: "ea_pandora_box")
      expect(pandora_product).to be_present
      expect(pandora_product).to be_active
      expect(pandora_product.billing_plan.amount_cents).to eq(29_900)
      expect(pandora_product.description_es).not_to include("![")

      fibonacci_addons = Addon.where(addonable: fibonacci_ea).includes(:billing_plan).index_by(&:key)
      expect(fibonacci_addons.keys).to match_array(
        %w[
          addon_session_time_filter
          addon_grid_strategy_config
          addon_candle_structure
          addon_compound_trend_ride
          addon_compound_pullback_continue
          addon_compound_reversal_early
          addon_compound_breakout_ready
          addon_compound_volatility_trap
        ]
      )
      expect(fibonacci_addons.fetch("addon_session_time_filter").billing_plan.amount_cents).to eq(29_900)
      expect(fibonacci_addons.fetch("addon_grid_strategy_config").billing_plan.amount_cents).to eq(29_900)
      expect(fibonacci_addons.fetch("addon_candle_structure").billing_plan.amount_cents).to eq(29_900)
      expect(fibonacci_addons.fetch("addon_compound_trend_ride").billing_plan.amount_cents).to eq(29_900)
      expect(fibonacci_addons.fetch("addon_compound_pullback_continue").billing_plan.amount_cents).to eq(19_900)
      expect(fibonacci_addons.fetch("addon_compound_reversal_early").billing_plan.amount_cents).to eq(19_900)
      expect(fibonacci_addons.fetch("addon_compound_breakout_ready").billing_plan.amount_cents).to eq(29_900)
      expect(fibonacci_addons.fetch("addon_compound_volatility_trap").billing_plan.amount_cents).to eq(19_900)

      addon_product_one = MarketplaceProduct.find_by(slug: "addon_fibonacci_session_time_filter")
      addon_product_two = MarketplaceProduct.find_by(slug: "addon_fibonacci_compound_reversal_early")
      expect(addon_product_one).to be_present
      expect(addon_product_one).to be_active
      expect(addon_product_two).to be_present
      expect(addon_product_two).to be_active

      expect(stale_marketplace_product.reload).to be_draft
      expect(stale_marketplace_plan.reload.active).to eq(false)

      entitlements = BillingPlanEntitlement.includes(:billing_plan, :expert_advisor).map do |entitlement|
        [entitlement.billing_plan.key, entitlement.expert_advisor.ea_id]
      end
      expect(entitlements).to include(
        ["basic_monthly", "sniper_advanced_panel"],
        ["basic_annual", "sniper_advanced_panel"],
        ["pandora_pro_monthly", "sniper_advanced_panel"],
        ["pandora_pro_annual", "sniper_advanced_panel"],
        ["fibonacci_elite_monthly", "fibonacci_elite"],
        ["fibonacci_elite_annual", "fibonacci_elite"],
        ["pandora_pro_monthly", "pandora_box"],
        ["pandora_pro_annual", "pandora_box"],
        ["marketplace_ea_pandora_box", "pandora_box"]
      )
    end
  end

  describe "Stripe requirements outside test" do
    it "requires STRIPE_PRIVATE_KEY for billing and marketplace seeds" do
      ENV.delete("STRIPE_PRIVATE_KEY")
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

      expect do
        Seeds::BillingPlans.seed_plans!(allow_local: true, profile: Seeds::Profiles::PROD_MIRROR)
      end.to raise_error(ArgumentError, /STRIPE_PRIVATE_KEY/)

      expect do
        Seeds::MarketplaceProducts.seed_products!(profile: Seeds::Profiles::PROD_MIRROR)
      end.to raise_error(ArgumentError, /STRIPE_PRIVATE_KEY/)
    end
  end
end
