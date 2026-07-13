require "rails_helper"

RSpec.describe Marketplace::AssetAccess do
  let(:user) { create(:user) }
  let(:asset) { create(:marketplace_asset) }
  let(:billing_plan) { create(:billing_plan, :one_time) }

  it "allows access when the asset is included in a purchased plan" do
    create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: billing_plan)

    result = described_class.new(user: user, asset: asset).call

    expect(result).to be_allowed
  end

  it "denies access when no purchase exists" do
    create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: billing_plan)

    result = described_class.new(user: user, asset: asset).call

    expect(result.allowed?).to be(false)
    expect(result.reason).to eq(:not_purchased)
  end

  it "grants access when entitlements are added after purchase" do
    create(:marketplace_purchase, user: user, billing_plan: billing_plan)

    result = described_class.new(user: user, asset: asset).call
    expect(result.allowed?).to be(false)

    create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: billing_plan)

    refreshed = described_class.new(user: user, asset: asset).call
    expect(refreshed).to be_allowed
  end

  it "requires purchases for every product role" do
    %i[admin master_admin full_trader].each do |role|
      role_user = create(:user, role: role)
      result = described_class.new(user: role_user, asset: asset).call

      expect(result.allowed?).to be(false)
      expect(result.reason).to eq(:not_purchased)
    end
  end
end
