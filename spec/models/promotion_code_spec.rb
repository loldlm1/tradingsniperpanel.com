require "rails_helper"

RSpec.describe PromotionCode, type: :model do
  it "normalizes codes to uppercase" do
    promotion = create(:promotion_code, code: "spring15")

    expect(promotion.reload.code).to eq("SPRING15")
  end

  it "prevents multiple active kept promotions" do
    create(:promotion_code, :active, code: "SPRING15")
    promotion = build(:promotion_code, :active, code: "SPRING20")

    expect(promotion).not_to be_valid
    expect(promotion.errors[:active]).to be_present
  end

  it "reports checkout availability only for active non-archived records with Stripe ids" do
    active_promotion = build(:promotion_code, :active)
    expired_promotion = build(:promotion_code, :active, :expired)
    archived_promotion = build(:promotion_code, :archived, stripe_promotion_code_id: "promo_archived")
    missing_remote = build(:promotion_code, :active, stripe_promotion_code_id: nil)

    expect(active_promotion.active_for_checkout?).to be(true)
    expect(expired_promotion.active_for_checkout?).to be(false)
    expect(archived_promotion.active_for_checkout?).to be(false)
    expect(missing_remote.active_for_checkout?).to be(false)
  end
end
