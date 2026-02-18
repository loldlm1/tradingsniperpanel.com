require "rails_helper"

RSpec.describe Licenses::GrantedAddons do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, ea_id: "ea-granted-addons") }

  it "returns an empty array when user is missing" do
    granted = described_class.new(user: nil, expert_advisor: expert_advisor).call

    expect(granted).to eq([])
  end

  it "returns purchased addon keys only" do
    addon_one = create(:addon, key: "addon_session_time_filter", addonable: expert_advisor)
    addon_two = create(:addon, key: "addon_grid_strategy_config", addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: addon_two.billing_plan)

    granted = described_class.new(user: user, expert_advisor: expert_advisor).call

    expect(granted).to eq(["addon_grid_strategy_config"])
  end

  it "normalizes keys to lowercase and trims spaces" do
    addon = create(:addon, key: "addon_session_time_filter", addonable: expert_advisor)
    addon.update_column(:key, "  Addon_Session_Time_Filter  ")
    create(:marketplace_purchase, user: user, billing_plan: addon.billing_plan)

    granted = described_class.new(user: user, expert_advisor: expert_advisor).call

    expect(granted).to eq(["addon_session_time_filter"])
  end

  it "returns all addon keys for privileged users" do
    privileged_user = create(:user, :full_trader)
    create(:addon, key: "addon_session_time_filter", addonable: expert_advisor)
    create(:addon, key: "addon_grid_strategy_config", addonable: expert_advisor)

    granted = described_class.new(user: privileged_user, expert_advisor: expert_advisor).call

    expect(granted).to eq(%w[addon_grid_strategy_config addon_session_time_filter])
  end
end
