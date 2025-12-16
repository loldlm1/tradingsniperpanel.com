require "rails_helper"

RSpec.describe UserExpertAdvisor, type: :model do
  describe ".active" do
    it "returns records that are not deleted and not expired" do
      active = create(:user_expert_advisor, expires_at: 1.day.from_now)
      create(:user_expert_advisor, :deleted)
      create(:user_expert_advisor, :expired)

      expect(described_class.active).to contain_exactly(active)
    end
  end
end
