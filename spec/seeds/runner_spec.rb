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
    it "keeps only sniper basic plans and removes stale seed data" do
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
        name: "PANDORA BOX EA",
        ea_id: "pandora_box",
        tier_rank: 2,
        allowed_subscription_tiers: %w[hft]
      )
      create(:billing_plan_entitlement, billing_plan: stale_plan, expert_advisor: stale_ea)

      Seeds::Runner.seed_prod_mirror!(allow_local: true)

      active_subscription_keys = BillingPlan.subscription.active.order(:key).pluck(:key)
      expect(active_subscription_keys).to eq(%w[basic_annual basic_monthly])
      expect(BillingPlan.find_by(key: "basic_monthly")&.amount_cents).to eq(2000)
      expect(BillingPlan.find_by(key: "basic_annual")&.amount_cents).to eq(18_000)
      expect(stale_plan.reload.active).to eq(false)

      expect(ExpertAdvisor.active.pluck(:ea_id)).to contain_exactly("sniper_advanced_panel")
      expect(stale_ea.reload.deleted_at).to be_present

      entitlements = BillingPlanEntitlement.includes(:billing_plan, :expert_advisor).map do |entitlement|
        [entitlement.billing_plan.key, entitlement.expert_advisor.ea_id]
      end
      expect(entitlements).to match_array(
        [
          ["basic_annual", "sniper_advanced_panel"],
          ["basic_monthly", "sniper_advanced_panel"]
        ]
      )
    end
  end
end
