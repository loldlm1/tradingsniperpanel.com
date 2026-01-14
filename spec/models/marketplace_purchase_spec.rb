require "rails_helper"

RSpec.describe MarketplacePurchase, type: :model do
  it "requires a one-time billing plan" do
    plan = create(:billing_plan, kind: "subscription")
    purchase = build(:marketplace_purchase, billing_plan: plan)

    expect(purchase).not_to be_valid
    expect(purchase.errors[:billing_plan]).to be_present
  end
end
