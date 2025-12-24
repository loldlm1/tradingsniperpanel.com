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

      expect(described_class.ordered_by_rank).to eq([same_rank, lower, middle])
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

  describe "#active_documents" do
    it "returns documents hash when present" do
      advisor = build(:expert_advisor, documents: { guide: "http://example.com" })

      expect(advisor.active_documents).to eq({ "guide" => "http://example.com" })
    end
  end
end
