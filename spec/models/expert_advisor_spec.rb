require "rails_helper"

RSpec.describe ExpertAdvisor, type: :model do
  describe ".active" do
    it "returns non-deleted advisors" do
      active = create(:expert_advisor)
      create(:expert_advisor, deleted_at: Time.current)

      expect(described_class.active).to contain_exactly(active)
    end
  end

  describe ".ordered_by_rank" do
    it "orders by tier_rank then name" do
      lower = create(:expert_advisor, name: "Alpha", tier_rank: 1)
      middle = create(:expert_advisor, name: "Beta", tier_rank: 2)
      same_rank = create(:expert_advisor, name: "Aardvark", tier_rank: 1)

      expect(described_class.ordered_by_rank).to eq([ same_rank, lower, middle ])
    end
  end

  describe "#allowed_for_tier?" do
    it "allows all tiers when allowed_subscription_tiers is blank" do
      advisor = build(:expert_advisor, allowed_subscription_tiers: [])

      expect(advisor.allowed_for_tier?("any")).to be(true)
    end

    it "matches tiers when configured" do
      advisor = build(:expert_advisor, allowed_subscription_tiers: %w[basic pro])

      expect(advisor.allowed_for_tier?("basic")).to be(true)
      expect(advisor.allowed_for_tier?("enterprise")).to be(false)
    end
  end

  describe ".subscription_entitlements_for" do
    it "returns the complete canonical Pandora matrix in catalog order" do
      chu = create(:expert_advisor, ea_id: "chu_sniper_trailing")
      pandora = create(:expert_advisor, ea_id: "pandora_box")
      plan = create(
        :billing_plan,
        tier: Billing::PandoraPricing::TIER,
        key: Billing::PandoraPricing::MONTHLY_KEY,
        name: "Pandora Monthly",
        amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
        stripe_price_id: "price_pandora_model",
        stripe_product_id: "prod_pandora_model"
      )
      create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: pandora)
      create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: chu)

      expect(described_class.subscription_entitlements_for(plan)).to eq([ pandora, chu ])
    end

    it "fails closed when a canonical entitlement is missing" do
      chu = create(:expert_advisor, ea_id: "chu_sniper_trailing")
      create(:expert_advisor, ea_id: "pandora_box")
      plan = create(
        :billing_plan,
        tier: Billing::PandoraPricing::TIER,
        key: Billing::PandoraPricing::MONTHLY_KEY,
        name: "Pandora Monthly",
        amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
        stripe_price_id: "price_pandora_incomplete",
        stripe_product_id: "prod_pandora_incomplete"
      )
      create(:billing_plan_entitlement, billing_plan: plan, expert_advisor: chu)

      expect(described_class.subscription_entitlements_for(plan)).to be_empty
    end
  end

  describe "#daily_results_supported?" do
    it "disables daily results only for Chu Sniper Trailing" do
      chu = build(:expert_advisor, ea_id: "chu_sniper_trailing")
      pandora = build(:expert_advisor, ea_id: "pandora_box")

      expect(chu.daily_results_supported?).to be(false)
      expect(pandora.daily_results_supported?).to be(true)
    end
  end

  describe "#doc_guide_for" do
    it "returns locale guide when present" do
      advisor = build(:expert_advisor, doc_guide_en: "English", doc_guide_es: "Espanol")

      expect(advisor.doc_guide_for(:es)).to eq("Espanol")
    end

    it "falls back to English when locale guide is missing" do
      advisor = build(:expert_advisor, doc_guide_en: "English", doc_guide_es: "")

      expect(advisor.doc_guide_for(:es)).to eq("English")
    end
  end
end
