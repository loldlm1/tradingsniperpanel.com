require "rails_helper"

RSpec.describe Licenses::AccessibleExpertAdvisors do
  let(:user) { create(:user) }
  let!(:ea) { create(:expert_advisor, ea_id: "ea-1", trial_enabled: true) }
  let!(:license) { create(:license, user:, expert_advisor: ea, status: "active", encrypted_key: "KEY123", expires_at: 1.week.from_now) }

  it "returns accessible entries with license info" do
    entries = described_class.new(user:).call
    entry = entries.find { |e| e.expert_advisor == ea }

    expect(entry).to be_present
    expect(entry.accessible).to be true
    expect(entry.license_key).to eq("KEY123")
    expect(entry.status).to eq(:active)
  end

  it "marks missing licenses as locked" do
    other_ea = create(:expert_advisor, ea_id: "ea-2")
    entries = described_class.new(user:).call
    entry = entries.find { |e| e.expert_advisor == other_ea }

    expect(entry.status).to eq(:locked)
    expect(entry.accessible).to be false
  end
end
