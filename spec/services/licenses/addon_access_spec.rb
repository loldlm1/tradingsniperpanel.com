require "rails_helper"

RSpec.describe Licenses::AddonAccess do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, ea_id: "ea-addons") }
  let(:addon) { create(:addon, key: "news_filter", addonable: expert_advisor) }

  it "allows when no addon keys are provided" do
    result = described_class.new(user: user, expert_advisor: expert_advisor, addon_keys: nil).call

    expect(result).to be_allowed
    expect(result.missing).to eq([])
  end

  it "allows when the addon is purchased" do
    create(:marketplace_purchase, user: user, billing_plan: addon.billing_plan)

    result = described_class.new(user: user, expert_advisor: expert_advisor, addon_keys: addon.key).call

    expect(result).to be_allowed
  end

  it "returns missing addons when not purchased" do
    result = described_class.new(user: user, expert_advisor: expert_advisor, addon_keys: addon.key).call

    expect(result.allowed?).to be(false)
    expect(result.required).to eq([addon.key])
    expect(result.missing).to eq([addon.key])
  end

  it "treats unknown addon keys as missing" do
    create(:marketplace_purchase, user: user, billing_plan: addon.billing_plan)

    result = described_class.new(user: user, expert_advisor: expert_advisor, addon_keys: "#{addon.key},unknown_addon").call

    expect(result.allowed?).to be(false)
    expect(result.missing).to eq(["unknown_addon"])
  end

  it "allows privileged users without addon purchases" do
    privileged_user = create(:user, :full_trader)

    result = described_class.new(user: privileged_user, expert_advisor: expert_advisor, addon_keys: addon.key).call

    expect(result).to be_allowed
    expect(result.missing).to eq([])
  end
end
