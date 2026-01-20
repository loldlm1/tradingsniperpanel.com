require "rails_helper"

RSpec.describe AssetPlanEntitlement, type: :model do
  it "enforces uniqueness per plan and asset" do
    entitlement = create(:asset_plan_entitlement)

    duplicate = described_class.new(
      billing_plan: entitlement.billing_plan,
      marketplace_asset: entitlement.marketplace_asset
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:billing_plan_id]).to be_present
  end

  it "requires a supported billing plan" do
    plan = build(:billing_plan)
    asset = create(:marketplace_asset)
    allow(plan).to receive(:subscription?).and_return(false)
    allow(plan).to receive(:one_time?).and_return(false)

    entitlement = described_class.new(billing_plan: plan, marketplace_asset: asset)

    expect(entitlement).not_to be_valid
    expect(entitlement.errors[:billing_plan]).to be_present
  end
end
